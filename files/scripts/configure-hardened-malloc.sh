#!/usr/bin/env bash
set -euo pipefail

desktop_file="/usr/share/applications/trivalent.desktop"
wrapper="/usr/bin/nocblue-hardened-malloc-run"

if [[ -f "${desktop_file}" ]]; then
    sed -i "s|Exec=/usr/bin/trivalent|Exec=${wrapper} /usr/bin/trivalent|g" "${desktop_file}"
fi
