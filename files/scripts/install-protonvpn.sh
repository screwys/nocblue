#!/usr/bin/env bash
set -euo pipefail

fedora_major="$(rpm -E %fedora)"
proton_release="protonvpn-beta-release-1.0.3-1.noarch.rpm"
curl -fsSLo "/tmp/${proton_release}" \
    "https://repo.protonvpn.com/fedora-${fedora_major}-unstable/protonvpn-beta-release/${proton_release}"

dnf -y install "/tmp/${proton_release}"

# The daemon package tries to start systemd services in scriptlets during image
# builds. Install it without scriptlets; the recipe enables the daemon unit.
dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=noscripts proton-vpn-gnome-desktop

# The package currently ships two equivalent launchers. Keep the application ID
# used by Noctalia defaults and hide the duplicate from launchers.
rm -f /usr/share/applications/com.protonvpn.www.desktop

# The Fedora beta package ships a DBus activation file that points at
# proton.VPN.service, but the installed unit is named below.
sed -i \
    's/^SystemdService=proton\.VPN\.service$/SystemdService=me.proton.vpn.split_tunneling.service/' \
    /etc/dbus-1/system-services/me.proton.vpn.split_tunneling.service
