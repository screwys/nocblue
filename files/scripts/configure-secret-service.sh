#!/usr/bin/env bash
set -euo pipefail

# GDM pulls in Fedora's secret service and PAM module, including in Niri images.
if (( $(rpm -E '%fedora') >= 45 )); then
    rpm -q oo7-daemon pam_oo7 oo7-portal
    # oo7 needs to run before the login helper can deliver the keyring password.
    systemctl --global enable oo7-daemon.service

    # Some apps still require the GNOME Keyring package. Keep their dependencies,
    # but let oo7 handle secrets even when D-Bus activates the provider first.
    cat >/usr/share/dbus-1/services/org.freedesktop.secrets.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.secrets
Exec=/usr/libexec/oo7-daemon
SystemdService=oo7-daemon.service
EOF
    sed -i '/pam_gnome_keyring\.so/d' /etc/pam.d/greetd
    if [[ -f /etc/xdg/autostart/gnome-keyring-secrets.desktop ]]; then
        desktop-file-edit --set-key=Hidden --set-value=true /etc/xdg/autostart/gnome-keyring-secrets.desktop
    fi
    if [[ -f /usr/lib/systemd/user/gnome-keyring-daemon.service ]]; then
        systemctl --global disable gnome-keyring-daemon.service gnome-keyring-daemon.socket
    fi
else
    rpm -q gnome-keyring gnome-keyring-pam
fi
