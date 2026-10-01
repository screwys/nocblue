#!/usr/bin/env bash
set -euo pipefail

policy_root=/usr/share/nocblue/selinux
semodule -X 300 -i \
    "${policy_root}/file-managers/nautilus/nautilus.pp" \
    "${policy_root}/sandbox-userns/nocblue_sandbox_userns.cil"

for path in \
    /var/lib/noctalia-greeter \
    /usr/bin/nocblue-browser-no-preload \
    /usr/bin/nocblue-portal-bwrap \
    /usr/libexec/nocblue/file-manager-launcher \
    /usr/libexec/nocblue/file-managers/nautilus \
    /usr/lib/chatgpt \
    /opt/brave.com/brave-origin-beta \
    /usr/lib/opt/brave.com/brave-origin-beta \
    /opt/helium \
    /usr/lib/opt/helium \
    /usr/lib64/firefox \
    /usr/share/librewolf \
    /usr/lib/mullvad-browser; do
    [[ -e "${path}" ]] || continue
    restorecon -Rv "${path}"
done
