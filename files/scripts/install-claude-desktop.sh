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

# Use Chromium's namespace sandbox without installing a setuid-root helper.
grep -Fxq '%attr(4755,root,root) %{_prefix}/lib/claude-desktop/chrome-sandbox' \
    "${workdir}/build-official.sh"
sed -i 's|^%attr(4755,root,root) %{_prefix}/lib/claude-desktop/chrome-sandbox$|%attr(0755,root,root) %{_prefix}/lib/claude-desktop/chrome-sandbox|' \
    "${workdir}/build-official.sh"

dnf -y install --setopt=install_weak_deps=False \
    rpm-build binutils file gnupg2 xz \
    alsa-lib ca-certificates openssh-clients pipewire-libs gjs

bash "${workdir}/build-official.sh" --outdir "${workdir}/rpm"
dnf -y install --setopt=install_weak_deps=False "${workdir}"/rpm/claude-desktop-*.rpm

mv /usr/lib/claude-desktop/claude-desktop /usr/lib/claude-desktop/claude-desktop.bin
install -m 0755 /usr/share/nocblue/launchers/claude-desktop \
    /usr/lib/claude-desktop/claude-desktop

rpm -q claude-desktop
test -x /usr/bin/claude-desktop
test ! -u /usr/lib/claude-desktop/chrome-sandbox
test ! -g /usr/lib/claude-desktop/chrome-sandbox
ldd /usr/lib/claude-desktop/claude-desktop.bin >"${workdir}/libraries"
if grep -F 'not found' "${workdir}/libraries"; then
    printf 'Claude Desktop has missing shared libraries\n' >&2
    exit 1
fi
