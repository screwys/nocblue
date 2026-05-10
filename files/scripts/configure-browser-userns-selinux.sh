#!/usr/bin/env bash
set -euo pipefail

semodule -X 300 -i /usr/share/nocblue/selinux/browser-userns/nocblue_browser_userns.cil

for path in \
    /opt/brave.com/brave-origin-beta \
    /usr/lib/opt/brave.com/brave-origin-beta \
    /opt/helium \
    /usr/lib/opt/helium; do
    [[ -e "${path}" ]] && restorecon -Rv "${path}" || true
done
