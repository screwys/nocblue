#!/usr/bin/env bash
set -euo pipefail

fedora_major="$(rpm -E %fedora)"
proton_release="protonvpn-stable-release-1.0.3-1.noarch.rpm"
curl -fsSLo "/tmp/${proton_release}" \
    "https://repo.protonvpn.com/fedora-${fedora_major}-stable/protonvpn-stable-release/${proton_release}"

dnf -y install "/tmp/${proton_release}"

# The daemon package tries to start systemd services in scriptlets during image
# builds. Install it without scriptlets and enable the units through presets.
dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=noscripts proton-vpn-gnome-desktop
