#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "${BASH_SOURCE[0]}")"

# Fedora's client startup files prepend profiles to PATH. Nocblue appends them.
for startup in /etc/profile.d/nix.sh /etc/profile.d/nix.fish; do
    if [[ -e "${startup}" ]]; then
        unlink "${startup}"
    fi
done

# The packaged rules would make the mounted persistent state root-owned.
: >/usr/lib/tmpfiles.d/nix-filesystem.conf
for directory in /nix/var/log/nix /nix/var/log /nix/var; do
    if [[ -d "${directory}" ]]; then
        rmdir "${directory}"
    fi
done
install -d -m 0755 /nix

"${script_dir}/install-nix-launcher.sh"
bash "${script_dir}/configure-nix-selinux.sh"
