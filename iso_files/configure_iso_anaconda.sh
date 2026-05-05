#!/usr/bin/env bash
set -euo pipefail

install_image="ghcr.io/screwys/nocblue:latest"
dnf_cmd="$(command -v dnf5 || command -v dnf)"

"${dnf_cmd}" install -y --allowerasing \
    anaconda-live \
    firefox \
    libblockdev-btrfs \
    libblockdev-dm \
    libblockdev-lvm \
    btrfs-progs \
    gparted

mkdir -p \
    /etc/skel/.config/autostart \
    /usr/local/bin \
    /usr/share/anaconda/post-scripts \
    /usr/share/glib-2.0/schemas \
    /var/lib/rpm-state \
    /var/tmp
chmod 1777 /var/tmp

if [[ -f /etc/sysconfig/livesys ]]; then
    sed -i 's/^livesys_session=.*/livesys_session=gnome/' /etc/sysconfig/livesys
fi

cat >/usr/share/anaconda/interactive-defaults.ks <<EOF
ostreecontainer --url=${install_image} --transport=containers-storage --no-signature-verification

%post --log=/tmp/nocblue-bootc-origin.log
bootc switch --mutate-in-place --transport registry ${install_image} || :
%end
EOF

cat >/usr/local/bin/nocblue-liveinst-once <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
stamp="${runtime_dir}/nocblue-liveinst-started"
mkdir -p "${runtime_dir}"

if [[ -e "${stamp}" ]]; then
    exit 0
fi

touch "${stamp}"
sleep 2
exec liveinst
EOF
chmod 0755 /usr/local/bin/nocblue-liveinst-once

cat >/etc/skel/.config/autostart/nocblue-liveinst.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Nocblue
Exec=/usr/local/bin/nocblue-liveinst-once
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

cat >/usr/share/glib-2.0/schemas/zz2-nocblue-live.gschema.override <<'EOF'
[org.gnome.shell]
favorite-apps = ['anaconda.desktop', 'firefox.desktop', 'org.gnome.Nautilus.desktop']
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || :

sed -i 's@^\[Desktop Entry\]$@[Desktop Entry]\nHidden=true@' \
    /usr/share/anaconda/gnome/org.fedoraproject.welcome-screen.desktop 2>/dev/null || :

flatpak config --system --set languages "*" 2>/dev/null || :

system_units=(
    bootc-fetch-apply-updates.timer
    flatpak-system-update.timer
    input-remapper.service
    nocblue-brew-formulae.service
    nocblue-flatpak-overrides.service
    nocblue-hardened-malloc-flatpaks.service
    nocblue-session-defaults.service
)

for unit in "${system_units[@]}"; do
    systemctl disable "${unit}" >/dev/null 2>&1 || :
done

user_units=(
    nocblue-adwsteamgtk.timer
    nocblue-flatpak-icon-fixes.service
    nocblue-icon-theme-sync.timer
    nocblue-noctalia-theme.service
    nocblue-user-defaults.service
)

for unit in "${user_units[@]}"; do
    systemctl --global disable "${unit}" >/dev/null 2>&1 || :
done

rm -f /etc/xdg/autostart/nocblue-user-defaults.desktop
