#!/usr/bin/env bash
set -euo pipefail

dropin_dir="/usr/lib/systemd/user/xdg-desktop-portal.service.d"
install -d "${dropin_dir}"

cat >"${dropin_dir}/50-nocblue-hardened-icon-validation.conf" <<'EOF'
[Service]
Environment=FLATPAK_BWRAP=/usr/bin/nocblue-portal-bwrap
EOF
