#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Build-time invariant checks for the Fedora kernel + OpenRazer compatibility
# base and for every downstream nocblue image that rebuilds its initramfs.

set -euo pipefail

readonly STATE_FILE=/usr/lib/nocblue/fedora-openrazer-kernel-release
readonly FEDORA_RELEASE="$(rpm -E '%fedora')"
readonly ARCH="$(rpm -E '%_arch')"
readonly ROOT_HARDENED_CONF=/usr/lib/systemd/system.conf.d/40-hardened_malloc.conf
readonly ROOT_HARDENED_MASK=/etc/systemd/system.conf.d/40-hardened_malloc.conf
readonly DRACUT_MASK_MODULE=/usr/lib/dracut/modules.d/99nocblue-initrd-no-preload/module-setup.sh

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

# The real root must retain Secureblue's allocator hardening. The /etc mask is
# generated inside the initramfs by the dracut module and must never leak here.
[[ -f "${ROOT_HARDENED_CONF}" ]] || fatal "missing ${ROOT_HARDENED_CONF}"
grep -Fq 'LD_PRELOAD=libhardened_malloc.so libno_rlimit_as.so' \
    "${ROOT_HARDENED_CONF}" || fatal 'real-root hardened malloc configuration is unexpected'
[[ ! -e "${ROOT_HARDENED_MASK}" && ! -L "${ROOT_HARDENED_MASK}" ]] || \
    fatal "initramfs-only hardened malloc mask leaked into the real root"
[[ -x "${DRACUT_MASK_MODULE}" ]] || fatal "missing ${DRACUT_MASK_MODULE}"

initramfs="/usr/lib/modules/${kver}/initramfs.img"
[[ -s "${initramfs}" ]] || fatal "missing ${initramfs}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

listing="${tmpdir}/listing"
modules="${tmpdir}/modules"
lsinitrd "${initramfs}" > "${listing}"
lsinitrd -m "${initramfs}" > "${modules}"

grep -Eq '^[[:space:]]*nocblue-initrd-no-preload([[:space:]]|$)' "${modules}" || \
    fatal 'nocblue-initrd-no-preload dracut module is absent from initramfs'
grep -Fq 'systemd-cryptsetup' "${listing}" || \
    fatal 'systemd-cryptsetup is absent from initramfs'
grep -Fq 'tpm2-tss' "${listing}" || \
    fatal 'tpm2-tss is absent from initramfs'

# Unpack the image so symlink semantics can be checked directly. A same-named
# /etc drop-in pointing to /dev/null masks the vendor /usr drop-in in systemd.
unpack_dir="${tmpdir}/unpack"
mkdir -p "${unpack_dir}"
(
    cd "${unpack_dir}"
    lsinitrd --unpack "${initramfs}" >/dev/null
)

initrd_mask="${unpack_dir}/etc/systemd/system.conf.d/40-hardened_malloc.conf"
[[ -L "${initrd_mask}" ]] || \
    fatal 'initramfs does not mask 40-hardened_malloc.conf'
[[ "$(readlink "${initrd_mask}")" == /dev/null ]] || \
    fatal "initramfs hardened malloc mask points to $(readlink "${initrd_mask}"), expected /dev/null"

printf 'Validated Fedora kernel, signed OpenRazer modules, and preload-free initramfs: %s\n' "${kver}"
