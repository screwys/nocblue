#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Replace Secureblue's custom runtime kernel with the exact Fedora runtime
# kernel used to build Universal Blue's pre-signed OpenRazer modules.

set -euo pipefail
shopt -s nullglob

readonly KERNEL_RPM_ROOT="${KERNEL_RPM_ROOT:-/tmp/kernel-rpms}"
readonly AKMOD_RPM_ROOT="${AKMOD_RPM_ROOT:-/tmp/akmods-rpms}"
readonly FEDORA_RELEASE="$(rpm -E '%fedora')"
readonly ARCH="$(rpm -E '%_arch')"
readonly STATE_DIR=/usr/lib/nocblue
readonly STATE_FILE="${STATE_DIR}/fedora-openrazer-kernel-release"

fatal() {
    printf 'fedora-openrazer compatibility error: %s\n' "$*" >&2
    exit 1
}

find_one_rpm() {
    local root="$1"
    local wanted_name="$2"
    local rpm_path package_name
    local -a matches=()

    while IFS= read -r -d '' rpm_path; do
        package_name="$(rpm -qp --qf '%{NAME}' "${rpm_path}")"
        if [[ "${package_name}" == "${wanted_name}" ]]; then
            matches+=("${rpm_path}")
        fi
    done < <(find "${root}" -type f -name '*.rpm' -print0)

    if (( ${#matches[@]} != 1 )); then
        printf 'Expected one RPM named %s below %s; found %d:\n' \
            "${wanted_name}" "${root}" "${#matches[@]}" >&2
        printf '  %s\n' "${matches[@]:-<none>}" >&2
        return 1
    fi

    printf '%s\n' "${matches[0]}"
}

[[ "${ARCH}" == x86_64 ]] || fatal "expected x86_64, got ${ARCH}"
[[ -d "${KERNEL_RPM_ROOT}" ]] || fatal "missing ${KERNEL_RPM_ROOT}"
[[ -d "${AKMOD_RPM_ROOT}" ]] || fatal "missing ${AKMOD_RPM_ROOT}"

runtime_names=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
)

declare -a runtime_rpms=()
for package_name in "${runtime_names[@]}"; do
    runtime_rpms+=("$(find_one_rpm "${KERNEL_RPM_ROOT}" "${package_name}")")
done

openrazer_common_rpm="$(find_one_rpm "${AKMOD_RPM_ROOT}" openrazer-kmod-common)"
openrazer_kmod_rpm="$(find_one_rpm "${AKMOD_RPM_ROOT}" kmod-openrazer)"

artifact_kver="$(
    rpm -qp --qf '%{VERSION}-%{RELEASE}.%{ARCH}' \
        "$(find_one_rpm "${KERNEL_RPM_ROOT}" kernel-core)"
)"

expected_suffix=".fc${FEDORA_RELEASE}.${ARCH}"
[[ "${artifact_kver}" == *"${expected_suffix}" ]] || \
    fatal "artifact kernel does not match Fedora ${FEDORA_RELEASE} ${ARCH}: ${artifact_kver}"
[[ "${artifact_kver}" != *.secureblue.* ]] || \
    fatal "artifact unexpectedly contains a Secureblue kernel: ${artifact_kver}"

for rpm_path in "${runtime_rpms[@]}"; do
    rpm_kver="$(rpm -qp --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "${rpm_path}")"
    [[ "${rpm_kver}" == "${artifact_kver}" ]] || \
        fatal "kernel RPM mismatch: ${rpm_path} is ${rpm_kver}, expected ${artifact_kver}"
done

printf 'Installing Fedora kernel/OpenRazer pair for %s\n' "${artifact_kver}"
printf 'Kernel RPMs:\n'
printf '  %s\n' "${runtime_rpms[@]}"
printf 'OpenRazer RPMs:\n  %s\n  %s\n' \
    "${openrazer_common_rpm}" "${openrazer_kmod_rpm}"

# Repositories are disabled for this transaction so every ABI-sensitive RPM
# comes from the same mounted, signed OCI artifact. This intentionally does not
# install another MOK enrollment helper or generate a new signing key.
dnf install -y \
    --allowerasing \
    --disablerepo='*' \
    --setopt=install_weak_deps=False \
    "${runtime_rpms[@]}" \
    "${openrazer_common_rpm}" \
    "${openrazer_kmod_rpm}"

# Kernel packages are install-only packages and may coexist across versions.
# Remove every stale runtime instance so dracut cannot build an unintended
# second initramfs or leave the Secureblue custom kernel as a boot candidate.
declare -a stale_nevras=()
for package_name in "${runtime_names[@]}"; do
    while IFS='|' read -r nevra installed_kver; do
        [[ -n "${nevra}" ]] || continue
        if [[ "${installed_kver}" != "${artifact_kver}" ]]; then
            stale_nevras+=("${nevra}")
        fi
    done < <(
        rpm -q "${package_name}" \
            --qf '%{NEVRA}|%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null || true
    )
done

if (( ${#stale_nevras[@]} > 0 )); then
    printf 'Removing stale runtime kernels:\n'
    printf '  %s\n' "${stale_nevras[@]}"
    dnf remove -y \
        --setopt=clean_requirements_on_remove=False \
        "${stale_nevras[@]}"
fi

for package_name in "${runtime_names[@]}"; do
    mapfile -t installed_versions < <(
        rpm -q "${package_name}" \
            --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -u
    )
    (( ${#installed_versions[@]} == 1 )) || \
        fatal "${package_name} has ${#installed_versions[@]} installed versions"
    [[ "${installed_versions[0]}" == "${artifact_kver}" ]] || \
        fatal "${package_name} is ${installed_versions[0]}, expected ${artifact_kver}"
done

mapfile -t module_trees < <(
    find /usr/lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
)
(( ${#module_trees[@]} == 1 )) || \
    fatal "expected one /usr/lib/modules tree, found: ${module_trees[*]:-<none>}"
[[ "${module_trees[0]}" == "${artifact_kver}" ]] || \
    fatal "module tree is ${module_trees[0]}, expected ${artifact_kver}"

install -d -m 0755 "${STATE_DIR}"
printf '%s\n' "${artifact_kver}" > "${STATE_FILE}"

ldconfig
depmod -a "${artifact_kver}"

rpm -q "${runtime_names[@]}" openrazer-kmod-common kmod-openrazer
printf 'Fedora/OpenRazer compatibility pair installed: %s\n' "${artifact_kver}"
