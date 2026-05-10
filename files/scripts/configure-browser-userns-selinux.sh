#!/usr/bin/env bash
set -euo pipefail

semodule -X 300 -i /usr/share/nocblue/selinux/browser-userns/nocblue_browser_userns.cil

for path in \
    /opt/brave.com/brave-origin-beta/brave \
    /usr/lib/opt/brave.com/brave-origin-beta/brave \
    /opt/helium/helium \
    /usr/lib/opt/helium/helium; do
    [[ -e "${path}" ]] && restorecon -v "${path}" || true
done
