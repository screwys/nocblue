#!/usr/bin/env bash
set -euo pipefail

policy_root=/usr/share/nocblue/selinux/file-managers
workdir="$(mktemp -d /tmp/nocblue-file-manager-selinux-XXXXXX)"

cleanup() {
    find "${workdir}" -depth -delete
}
trap cleanup EXIT

for module in nautilus thunar; do
    module_dir="${policy_root}/${module}"
    build_dir="${workdir}/${module}"

    install -d -m 0755 "${build_dir}"
    cp "${module_dir}/${module}.te" "${module_dir}/${module}.if" "${module_dir}/${module}.fc" "${build_dir}/"
    make -C "${build_dir}" -f /usr/share/selinux/devel/Makefile "${module}.pp"
    install -m 0644 "${build_dir}/${module}.pp" "${module_dir}/${module}.pp"
done
