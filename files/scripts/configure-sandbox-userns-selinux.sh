#!/usr/bin/env bash
set -euo pipefail

policy_root=/usr/share/nocblue/selinux
semodule -X 300 -i \
    "${policy_root}/sandbox-userns/nocblue_sandbox_userns.cil" \
    "${policy_root}/claude-desktop/claude_desktop.cil"

for path in \
    /var/lib/noctalia-greeter \
    /usr/bin/nocblue-browser-no-preload \
    /usr/lib/chatgpt \
    /usr/lib/claude-desktop \
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
