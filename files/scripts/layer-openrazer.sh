#!/usr/bin/env bash
set -euo pipefail

repo_file="/etc/yum.repos.d/hardware:razer.repo"

install -d -m 0755 /etc/yum.repos.d
cat >"${repo_file}" <<'EOF'
[hardware_razer]
name=Fedora $releasever - hardware:razer
type=rpm-md
baseurl=https://download.opensuse.org/repositories/hardware:/razer/Fedora_$releasever/
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/hardware:/razer/Fedora_$releasever/repodata/repomd.xml.key
enabled=1
EOF

if ! getent group plugdev >/dev/null 2>&1; then
    groupadd --system plugdev
fi

rpm-ostree install --idempotent \
    kernel-devel \
    kmodtool \
    akmods \
    mokutil \
    openssl \
    openrazer-meta
