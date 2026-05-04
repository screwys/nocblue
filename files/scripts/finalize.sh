#!/usr/bin/env bash
set -euo pipefail

sed -i -f - /usr/lib/os-release <<'EOF'
s|^NAME=.*|NAME="nocblue"|
s|^PRETTY_NAME=.*|PRETTY_NAME="nocblue Fedora 44 bootc"|
EOF
