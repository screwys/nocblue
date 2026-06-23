#!/usr/bin/env bash
set -euo pipefail

proot_commit="acd6ca53375ff830fdf6e77251ee005c9c68b0d0"
archive_url="${NOCBLUE_PROOT_ARCHIVE_URL:-https://github.com/numinit/proot/archive/${proot_commit}.tar.gz}"
archive_sha256="59e30229c852de246946c5ff32039f7a5d4e5ea917b1d4a80639694edf76dc91"
root="${NOCBLUE_ROOT:-}"

root_path() {
    printf '%s%s\n' "${root}" "$1"
}

workdir="$(mktemp -d)"
cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

archive="${workdir}/proot.tar.gz"
curl -fL --retry 3 -o "${archive}" "${archive_url}"
printf '%s  %s\n' "${archive_sha256}" "${archive}" | sha256sum -c -

tar -xzf "${archive}" -C "${workdir}"
src_root="$(find "${workdir}" -maxdepth 1 -type d -name "proot-${proot_commit}" -print -quit)"
test -n "${src_root}"

# The pinned fchmodat2 PR snapshot calls peek_word() from tracee.c without
# including the header that declares it. Keep the image build patch local and
# narrow until upstream refreshes or merges a buildable source.
grep -Fqx '#include "tracee/reg.h"' "${src_root}/src/tracee/tracee.c"
sed -i '/#include "tracee\/reg.h"/a #include "tracee/mem.h"' "${src_root}/src/tracee/tracee.c"

make -C "${src_root}/src" proot
test -x "${src_root}/src/proot"

install_dir="$(root_path /usr/libexec/nocblue/nix-portable)"
install -d -m 0755 "${install_dir}"
install -m 0755 "${src_root}/src/proot" "${install_dir}/proot"
printf '%s\n' "${proot_commit}" >"${workdir}/proot-source-commit"
printf '%s\n' "${archive_sha256}" >"${workdir}/proot-source-sha256"
install -m 0644 "${workdir}/proot-source-commit" "${install_dir}/proot-source-commit"
install -m 0644 "${workdir}/proot-source-sha256" "${install_dir}/proot-source-sha256"
