#!/usr/bin/env bash
set -euo pipefail

sed -i -f - /usr/lib/os-release <<'EOF'
s|^NAME=.*|NAME="nocblue"|
s|^ID=.*|ID=nocblue|
s|^PRETTY_NAME=.*|PRETTY_NAME="nocblue 44-hardened"|
s|^CPE_NAME=.*|CPE_NAME="cpe:/o:nocblue:nocblue:44"|
s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="nocblue-hardened"|
s|^HOME_URL=.*|HOME_URL="https://github.com/screwys/nocblue"|
s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/screwys/nocblue"|
s|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/screwys/nocblue/issues"|
s|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/screwys/nocblue/issues"|
s|^VARIANT=.*|VARIANT="Nocblue Hardened"|
s|^VARIANT_ID=.*|VARIANT_ID=nocblue-hardened|
s|^IMAGE_ID=.*|IMAGE_ID="nocblue-hardened"|
EOF

sed -i "s|printf 'Nocblue 44'|printf 'Nocblue 44-hardened'|" /etc/xdg/fastfetch/config.jsonc
