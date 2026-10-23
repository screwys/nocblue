#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/claude-desktop.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# Build dewzor's Fedora RPM from Anthropic's signed Linux package.
# Keep the packaging script fixed while following official app updates.
revision=f9f3faa5ab360cddd84101a50917cbff77c2fe01
curl -fsSL --retry 3 -o "${workdir}/build-official.sh" \
    "https://raw.githubusercontent.com/dewzor/claude-desktop-fedora/${revision}/build-official.sh"
printf '%s  %s\n' \
    4a1475051036cda38f5b2719f9cbbde48a3ab81821d12fc856abe254e91fefe6 \
    "${workdir}/build-official.sh" | sha256sum -c -

dnf -y install --setopt=install_weak_deps=False \
    rpm-build binutils file gnupg2 xz \
    alsa-lib ca-certificates openssh-clients pipewire-libs gjs

bash "${workdir}/build-official.sh" --outdir "${workdir}/rpm"
dnf -y install --setopt=install_weak_deps=False "${workdir}"/rpm/claude-desktop-*.rpm

rpm -q claude-desktop
test -x /usr/bin/claude-desktop
ldd /usr/lib/claude-desktop/claude-desktop >"${workdir}/libraries"
if grep -F 'not found' "${workdir}/libraries"; then
    printf 'Claude Desktop has missing shared libraries\n' >&2
    exit 1
fi
