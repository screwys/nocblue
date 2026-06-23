#!/usr/bin/env bash
set -euo pipefail

dropin_dir="/usr/lib/systemd/user/xdg-desktop-portal.service.d"
install -d "${dropin_dir}"

cat >"${dropin_dir}/50-nocblue-icon-validation.conf" <<'EOF'
[Service]
Environment=XDP_VALIDATE_ICON=/usr/libexec/nocblue/xdg-desktop-portal-validate-icon
EOF
