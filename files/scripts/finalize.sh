#!/usr/bin/env bash
set -euo pipefail

sed -i -f - /usr/lib/os-release <<'EOF'
s|^NAME=.*|NAME="nocblue"|
s|^PRETTY_NAME=.*|PRETTY_NAME="nocblue Fedora 44 bootc"|
EOF

find /etc/yum.repos.d -name '*.repo' -type f -print0 \
    | xargs -0 -r sed -i 's/^countme=1$/countme=0/'
