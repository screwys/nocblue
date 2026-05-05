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
    /etc/anaconda/conf.d \
    /etc/skel/.config/autostart \
    /etc/skel/.config/niri \
    /etc/skel/.config/noctalia \
    /usr/lib64/firefox/distribution \
    /usr/share/anaconda/post-scripts \
    /usr/share/glib-2.0/schemas \
    /var/lib/livesys/livesys-session-extra.d \
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

cat >/etc/anaconda/conf.d/90-nocblue.conf <<'EOF'
# Keep Anaconda interactive enough for live USB installs.
[Anaconda]
kickstart_modules =
    org.fedoraproject.Anaconda.Modules.Storage
    org.fedoraproject.Anaconda.Modules.Runtime
    org.fedoraproject.Anaconda.Modules.Network
    org.fedoraproject.Anaconda.Modules.Security
    org.fedoraproject.Anaconda.Modules.Services
    org.fedoraproject.Anaconda.Modules.Users
    org.fedoraproject.Anaconda.Modules.Timezone
EOF

cat >/usr/bin/nocblue-liveinst-once <<'EOF'
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
chmod 0755 /usr/bin/nocblue-liveinst-once

cat >/usr/lib64/firefox/distribution/policies.json <<'EOF'
{
  "policies": {
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableTelemetry": true,
    "DontCheckDefaultBrowser": true,
    "FirefoxHome": {
      "Highlights": false,
      "Locked": false,
      "Pocket": false,
      "Snippets": false,
      "SponsoredPocket": false,
      "SponsoredStories": false,
      "SponsoredTopSites": false,
      "Stories": false
    },
    "FirefoxSuggest": {
      "ImproveSuggest": false,
      "Locked": false,
      "SponsoredSuggestions": false,
      "WebSuggestions": false
    },
    "ManualAppUpdateOnly": true,
    "NoDefaultBookmarks": true,
    "OfferToSaveLoginsDefault": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "SearchEngines": {
      "Default": "DuckDuckGo",
      "PreventInstalls": true
    },
    "SearchSuggestEnabled": false,
    "SkipTermsOfUse": true,
    "UserMessaging": {
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "FirefoxLabs": false,
      "Locked": false,
      "MoreFromMozilla": false,
      "SkipOnboarding": true,
      "UrlbarInterventions": false
    }
  }
}
EOF

cat >/var/lib/livesys/livesys-session-extra.d/10-nocblue-live-user <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if id liveuser >/dev/null 2>&1; then
    usermod -c "Live User" liveuser || :
    usermod -aG wheel liveuser || :
    passwd -d liveuser || :
fi
EOF
chmod 0755 /var/lib/livesys/livesys-session-extra.d/10-nocblue-live-user

if [[ -d /usr/share/nocblue/defaults/noctalia ]]; then
    cp -a /usr/share/nocblue/defaults/noctalia/. /etc/skel/.config/noctalia/
    chmod -R a+rX /etc/skel/.config/noctalia
fi

install -D -m 0644 /etc/xdg/niri/config.kdl /etc/skel/.config/niri/config.kdl

cat >>/etc/skel/.config/niri/config.kdl <<'EOF'

window-rule {
    match app-id=r"^(org\.fedoraproject\.Anaconda|anaconda|liveinst)$"
    match title=r"(?i).*installation.*"
    open-maximized true
}
EOF

cat >>/etc/xdg/niri/config.kdl <<'EOF'

window-rule {
    match app-id=r"^(org\.fedoraproject\.Anaconda|anaconda|liveinst)$"
    match title=r"(?i).*installation.*"
    open-maximized true
}
EOF

cat >/etc/skel/.config/autostart/nocblue-liveinst.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Nocblue
Exec=/usr/bin/nocblue-liveinst-once
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
