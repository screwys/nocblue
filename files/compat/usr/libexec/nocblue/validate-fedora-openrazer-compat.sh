#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Build-time invariant checks for the Fedora kernel + OpenRazer compatibility
# base and for every downstream nocblue image that rebuilds its initramfs.

set -euo pipefail

readonly STATE_FILE=/usr/lib/nocblue/fedora-openrazer-kernel-release
readonly FEDORA_RELEASE="$(rpm -E '%fedora')"
readonly ARCH="$(rpm -E '%_arch')"

fatal() {
    printf 'fedora-openrazer validation failed: %s\n' "$*" >&2
    exit 1
}

[[ -s "${STATE_FILE}" ]] || fatal "missing ${STATE_FILE}"
kver="$(<"${STATE_FILE}")"

expected_suffix=".fc${FEDORA_RELEASE}.${ARCH}"
[[ "${kver}" == *"${expected_suffix}" ]] || fatal "unexpected kernel release: ${kver}"
[[ "${kver}" != *.secureblue.* ]] || fatal "Secureblue custom kernel remained installed: ${kver}"

runtime_names=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
)

for package_name in "${runtime_names[@]}"; do
    mapfile -t versions < <(
        rpm -q "${package_name}" \
            --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -u
    )
    (( ${#versions[@]} == 1 )) || \
        fatal "${package_name} has ${#versions[@]} installed versions"
    [[ "${versions[0]}" == "${kver}" ]] || \
        fatal "${package_name} is ${versions[0]}, expected ${kver}"
done

mapfile -t module_trees < <(
    find /usr/lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
)
(( ${#module_trees[@]} == 1 )) || \
    fatal "expected one module tree, found: ${module_trees[*]:-<none>}"
[[ "${module_trees[0]}" == "${kver}" ]] || \
    fatal "module tree is ${module_trees[0]}, expected ${kver}"

rpm -q \
    openrazer-kmod-common \
    kmod-openrazer \
    openrazer-daemon \
    python3-openrazer >/dev/null

for module_name in razerkbd razermouse razerkraken razeraccessory; do
    module_path="$(modinfo -k "${kver}" -n "${module_name}")"
    [[ -s "${module_path}" ]] || fatal "missing ${module_name}: ${module_path}"

    vermagic="$(modinfo -k "${kver}" -F vermagic "${module_name}")"
    [[ "${vermagic}" == "${kver}"* ]] || \
        fatal "${module_name} vermagic '${vermagic}' does not start with '${kver}'"

    signer="$(modinfo -k "${kver}" -F signer "${module_name}" | head -n1)"
    [[ -n "${signer}" ]] || fatal "${module_name} has no module signer"
    printf '%-16s %s\n' "${module_name}" "signer=${signer}"
done

vmlinuz="/usr/lib/modules/${kver}/vmlinuz"
[[ -s "${vmlinuz}" ]] || fatal "missing ${vmlinuz}"
sbverify --list "${vmlinuz}" >/dev/null

initramfs="/usr/lib/modules/${kver}/initramfs.img"
[[ -s "${initramfs}" ]] || fatal "missing ${initramfs}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

listing="${tmpdir}/listing"
lsinitrd "${initramfs}" > "${listing}"

grep -Fq 'libhardened_malloc.so' "${listing}" || \
    fatal 'libhardened_malloc.so is absent from initramfs'
grep -Fq 'usr/lib64/libno_rlimit_as.so' "${listing}" || \
    fatal 'libno_rlimit_as.so is absent from initramfs'
grep -Fq 'etc/ld.so.cache' "${listing}" || \
    fatal '/etc/ld.so.cache is absent from initramfs'
grep -Fq 'usr/lib/systemd/system.conf.d/40-hardened_malloc.conf' "${listing}" || \
    fatal '40-hardened_malloc.conf is absent from initramfs'
grep -Fq 'systemd-cryptsetup' "${listing}" || \
    fatal 'systemd-cryptsetup is absent from initramfs'
grep -Fq 'tpm2-tss' "${listing}" || \
    fatal 'tpm2-tss is absent from initramfs'

embedded_no_rlimit="${tmpdir}/libno_rlimit_as.so"
lsinitrd -f /usr/lib64/libno_rlimit_as.so "${initramfs}" > "${embedded_no_rlimit}"
[[ -s "${embedded_no_rlimit}" ]] || fatal 'embedded libno_rlimit_as.so is empty'
cmp -s "${embedded_no_rlimit}" /usr/lib64/libno_rlimit_as.so || \
    fatal 'embedded libno_rlimit_as.so differs from the final root filesystem'

embedded_cache="${tmpdir}/ld.so.cache"
lsinitrd -f /etc/ld.so.cache "${initramfs}" > "${embedded_cache}"
[[ -s "${embedded_cache}" ]] || fatal 'embedded ld.so.cache is empty'
ldconfig -p -C "${embedded_cache}" | grep -Fq 'libno_rlimit_as.so' || \
    fatal 'embedded loader cache cannot resolve libno_rlimit_as.so'
ldconfig -p -C "${embedded_cache}" | grep -Fq 'libhardened_malloc.so' || \
    fatal 'embedded loader cache cannot resolve libhardened_malloc.so'

embedded_systemd_conf="${tmpdir}/40-hardened_malloc.conf"
lsinitrd -f /usr/lib/systemd/system.conf.d/40-hardened_malloc.conf \
    "${initramfs}" > "${embedded_systemd_conf}"
grep -Fq 'LD_PRELOAD=libhardened_malloc.so libno_rlimit_as.so' \
    "${embedded_systemd_conf}" || \
    fatal 'embedded systemd preload configuration is unexpected'

printf 'Validated Fedora kernel, signed OpenRazer modules, and initramfs: %s\n' "${kver}"
