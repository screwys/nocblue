#!/usr/bin/env bash
set -euo pipefail

policy_dir=/usr/share/nocblue/selinux/nix
workdir="$(mktemp -d /tmp/nocblue-nix-selinux-XXXXXX)"

cleanup() {
    find "${workdir}" -depth -delete
}
trap cleanup EXIT

cp "${policy_dir}/nocblue_nix.te" "${policy_dir}/nocblue_nix.fc" "${workdir}/"
make -C "${workdir}" -f /usr/share/selinux/devel/Makefile nocblue_nix.pp
install -m 0644 "${workdir}/nocblue_nix.pp" "${policy_dir}/nocblue_nix.pp"

policy_path="$(find /etc/selinux/targeted/policy -maxdepth 1 -name 'policy.*' -printf '%p\n' | sort -V | tail -n 1)"
python3 "${policy_dir}/generate-exec-policy.py" "${policy_path}" > "${workdir}/nocblue_nix_exec.cil"
install -m 0644 "${workdir}/nocblue_nix_exec.cil" "${policy_dir}/nocblue_nix_exec.cil"

semodule -X 300 -i \
    "${policy_dir}/nocblue_nix.pp" \
    "${policy_dir}/nocblue_nix_userns.cil" \
    "${policy_dir}/nocblue_nix_exec.cil"

restorecon -v /usr/libexec/nocblue/nix
for directory in /etc/nix /var/home/nix; do
    if [[ -d "${directory}" ]]; then
        restorecon -Rv "${directory}"
    fi
done
