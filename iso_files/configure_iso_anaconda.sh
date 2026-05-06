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
    gparted \
    rsync

mkdir -p \
    /etc/anaconda/conf.d \
    /etc/skel/.cache/noctalia \
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

%include /usr/share/anaconda/post-scripts/nocblue-install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/nocblue-flatpak-restore-selinux-labels.ks

%post --log=/tmp/nocblue-bootc-origin.log
bootc switch --mutate-in-place --transport registry ${install_image} || :
%end
EOF

cat >/usr/share/anaconda/post-scripts/nocblue-install-flatpaks.ks <<'EOF'
%post --erroronfail --nochroot --log=/tmp/nocblue-install-flatpaks.log
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/${deployment}.0/var/lib"
mkdir -p "${target}"
rsync -aAXUHKP --open-noatime /var/lib/flatpak "${target}/"
sync "${target}"
%end
EOF

cat >/usr/share/anaconda/post-scripts/nocblue-flatpak-restore-selinux-labels.ks <<'EOF'
%post --erroronfail --log=/tmp/nocblue-flatpak-restore-selinux-labels.log
chcon -R -t var_lib_t /var/lib/flatpak
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
forbidden_modules =
    org.fedoraproject.Anaconda.Modules.Subscription

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[User Interface]
hidden_spokes =
hidden_webui_pages =
can_change_users = True
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
    python3 - <<'PY'
import json
from pathlib import Path

path = Path("/etc/skel/.config/noctalia/settings.json")
if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))
    data.setdefault("general", {})["showChangelogOnStartup"] = False
    data.setdefault("general", {})["telemetryEnabled"] = False

    def remove_widget(widgets, widget_id):
        for section in ("left", "center", "right"):
            widgets[section] = [
                item for item in widgets.get(section, [])
                if item.get("id") != widget_id
            ]

    def add_after(widgets, target_id, widget):
        left = widgets.setdefault("left", [])
        widget_id = widget["id"]
        if any(item.get("id") == widget_id for item in left):
            return
        for index, item in enumerate(left):
            if item.get("id") == target_id:
                left.insert(index + 1, widget)
                return
        left.append(widget)

    bar = data.setdefault("bar", {})
    widgets = bar.setdefault("widgets", {})
    remove_widget(widgets, "VPN")
    add_after(widgets, "plugin:noctalia-calculator", {"id": "Network"})
    for override in bar.get("screenOverrides", []):
        override_widgets = override.get("widgets")
        if isinstance(override_widgets, dict):
            remove_widget(override_widgets, "VPN")

    path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
PY
    chmod -R a+rX /etc/skel/.config/noctalia
fi

cat >/etc/skel/.cache/noctalia/shell-state.json <<'EOF'
{
  "display": {},
  "notificationsState": {
    "lastSeenTs": 0
  },
  "changelogState": {
    "lastSeenVersion": "v4.0.2"
  },
  "colorSchemesList": {
    "schemes": [],
    "timestamp": 0
  },
  "ui": {
    "settingsSidebarExpanded": true
  },
  "telemetry": {
    "instanceId": ""
  },
  "launcherUsage": {}
}
EOF

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
if [[ -f /usr/share/nocblue/manifests/flatpaks.txt ]]; then
    while IFS= read -r flatpak_ref; do
        [[ -z "${flatpak_ref}" || "${flatpak_ref}" =~ ^# ]] && continue
        flatpak info --system "${flatpak_ref}" >/dev/null
    done < /usr/share/nocblue/manifests/flatpaks.txt
fi

cat >/etc/systemd/system/var-lib-flatpak.mount <<'EOF'
[Mount]
Type=none
What=/var/lib/flatpak
Where=/var/lib/flatpak
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF
systemctl enable var-lib-flatpak.mount >/dev/null 2>&1 || :

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
    nocblue-user-defaults.service
)

for unit in "${user_units[@]}"; do
    systemctl --global disable "${unit}" >/dev/null 2>&1 || :
done

rm -f /etc/xdg/autostart/nocblue-user-defaults.desktop
