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

install -d -m 0755 /mnt /var/mnt

ln -sfn Candy /usr/share/icons/candy-icons

find /etc/yum.repos.d -name '*.repo' -type f -print0 \
    | xargs -0 -r sed -i 's/^countme=1$/countme=0/'
