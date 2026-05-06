#!/usr/bin/env bash
set -euo pipefail

sed -i -f - /usr/lib/os-release <<'EOF'
s|^NAME=.*|NAME="nocblue"|
s|^PRETTY_NAME=.*|PRETTY_NAME="nocblue Fedora 44 bootc"|
EOF

install_efi() {
    local name="${1}"
    local src

    src="$(find /usr/lib/efi -path "*/EFI/fedora/${name}" -print -quit)"
    test -n "${src}"
    install -D -m 0644 "${src}" "/boot/efi/EFI/fedora/${name}"
}

install_efi shimx64.efi
install_efi mmx64.efi
install_efi gcdx64.efi

ensure_plain_dir() {
    local path="${1}"
    local mode="${2:-0755}"

    if [[ -L "${path}" || ( -e "${path}" && ! -d "${path}" ) ]]; then
        rm -f "${path}"
    fi

    mkdir -p "${path}"
    chmod "${mode}" "${path}"
}

ensure_plain_dir /mnt
ensure_plain_dir /var/mnt
ensure_plain_dir /var/tmp 1777

ln -sfn Candy /usr/share/icons/candy-icons

if [[ -f /usr/share/applications/firefox.desktop ]]; then
    ln -sfn firefox.desktop /usr/share/applications/org.mozilla.firefox.desktop
fi

find /etc/yum.repos.d -name '*.repo' -type f -print0 \
    | xargs -0 -r sed -i 's/^countme=1$/countme=0/'
