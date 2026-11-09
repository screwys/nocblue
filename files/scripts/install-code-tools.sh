#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/nocblue-code-tools.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# Microsoft's universal RPM does not depend on Fedora repository availability.
powershell_version=7.6.9
curl -fsSL --retry 3 -o "$workdir/powershell.rpm" \
    "https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-1.rh.x86_64.rpm"
printf '%s  %s\n' \
    91c7f3d518389b1042b1465d70d365bcd040b67a3c0f79849658c695b777a6be \
    "$workdir/powershell.rpm" | sha256sum -c -
dnf -y install --setopt=install_weak_deps=False "$workdir/powershell.rpm"

# Luau has no Fedora or Terra package; upstream's Linux build needs only glibc and libstdc++.
luau_version=0.745
curl -fsSL --retry 3 -o "$workdir/luau.zip" \
    "https://github.com/luau-lang/luau/releases/download/${luau_version}/luau-ubuntu.zip"
printf '%s  %s\n' \
    186e5ddaa2b048ebc7390c11ed1b00c04e7d3beaffed429250329e3575d2ece2 \
    "$workdir/luau.zip" | sha256sum -c -
unzip -q "$workdir/luau.zip" luau luau-analyze -d "$workdir/luau"
install -m 0755 "$workdir/luau/luau" /usr/bin/luau
install -m 0755 "$workdir/luau/luau-analyze" /usr/bin/luau-analyze

GOBIN="$workdir/go-bin" GOMODCACHE="$workdir/go-mod" GOCACHE="$workdir/go-cache" \
    CGO_ENABLED=0 go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
GOBIN="$workdir/go-bin" GOMODCACHE="$workdir/go-mod" GOCACHE="$workdir/go-cache" \
    CGO_ENABLED=0 go install github.com/a-h/templ/cmd/templ@v0.3.1020
GOBIN="$workdir/go-bin" GOMODCACHE="$workdir/go-mod" GOCACHE="$workdir/go-cache" \
    CGO_ENABLED=0 go install mvdan.cc/sh/v3/cmd/shfmt@v3.14.1
install -m 0755 "$workdir/go-bin/actionlint" /usr/bin/actionlint
install -m 0755 "$workdir/go-bin/templ" /usr/bin/templ
install -m 0755 "$workdir/go-bin/shfmt" /usr/bin/shfmt
install -D -m 0644 "$workdir/go-mod/mvdan.cc/sh/v3@v3.14.1/LICENSE" /usr/share/licenses/shfmt/LICENSE

CARGO_HOME="$workdir/cargo-home" CARGO_TARGET_DIR="$workdir/cargo-target" \
    cargo install --root "$workdir/rust" --locked --version 0.45.3 ast-grep
CARGO_HOME="$workdir/cargo-home" CARGO_TARGET_DIR="$workdir/cargo-target" \
    cargo install --root "$workdir/rust" --locked \
    --git https://github.com/hxpe-dev/kotofetch --tag v0.2.23 kotofetch
install -m 0755 "$workdir/rust/bin/ast-grep" /usr/bin/ast-grep
install -m 0755 "$workdir/rust/bin/kotofetch" /usr/bin/kotofetch

/usr/bin/actionlint -version
/usr/bin/templ version
/usr/bin/shfmt --version
/usr/bin/pwsh --version
/usr/bin/ast-grep --version
/usr/bin/kotofetch --version
printf 'print(_VERSION)\n' >"$workdir/version.luau"
/usr/bin/luau "$workdir/version.luau"
