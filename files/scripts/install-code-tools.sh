#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/nocblue-code-tools.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

GOBIN="$workdir/go-bin" GOMODCACHE="$workdir/go-mod" GOCACHE="$workdir/go-cache" \
    CGO_ENABLED=0 go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
GOBIN="$workdir/go-bin" GOMODCACHE="$workdir/go-mod" GOCACHE="$workdir/go-cache" \
    CGO_ENABLED=0 go install github.com/a-h/templ/cmd/templ@v0.3.1020
install -m 0755 "$workdir/go-bin/actionlint" /usr/bin/actionlint
install -m 0755 "$workdir/go-bin/templ" /usr/bin/templ

CARGO_HOME="$workdir/cargo-home" CARGO_TARGET_DIR="$workdir/cargo-target" \
    cargo install --root "$workdir/rust" --locked --version 0.45.3 ast-grep
CARGO_HOME="$workdir/cargo-home" CARGO_TARGET_DIR="$workdir/cargo-target" \
    cargo install --root "$workdir/rust" --locked \
    --git https://github.com/hxpe-dev/kotofetch --tag v0.2.23 kotofetch
install -m 0755 "$workdir/rust/bin/ast-grep" /usr/bin/ast-grep
install -m 0755 "$workdir/rust/bin/kotofetch" /usr/bin/kotofetch

/usr/bin/actionlint -version
/usr/bin/templ version
/usr/bin/ast-grep --version
/usr/bin/kotofetch --version
