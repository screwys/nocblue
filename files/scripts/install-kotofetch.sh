#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/nocblue-kotofetch.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT
package="$workdir/kotofetch.rpm"
curl -fsSL \
    https://github.com/hxpe-dev/kotofetch/releases/download/v0.2.23/kotofetch-v0.2.23-1.x86_64.rpm \
    -o "$package"
printf '%s  %s\n' \
    73c0fcf6f361a2df4c6afabe9f8e7090f89112be3939daff6c4e3028678db60a \
    "$package" | sha256sum -c -
dnf -y --setopt=install_weak_deps=False install "$package"
/usr/bin/kotofetch --version
