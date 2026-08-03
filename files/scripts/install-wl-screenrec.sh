#!/usr/bin/env bash
set -euo pipefail

wl_screenrec_version="0.2.0"
# The v0.2.0 tag predates upstream's FFmpeg 8.1 dependency update. Pin the
# current upstream revision that builds against Fedora 44's headers.
wl_screenrec_revision="09252908c6304f0b71a5af9ddddf587559fbc471"
build_dir="$(mktemp -d /tmp/nocblue-wl-screenrec-build-XXXXXX)"

cleanup() {
    rm -rf "${build_dir}"
}
trap cleanup EXIT

export CARGO_HOME="${build_dir}/cargo-home"

env -u LD_PRELOAD cargo install \
    --git https://github.com/russelltg/wl-screenrec \
    --rev "${wl_screenrec_revision}" \
    --locked \
    --root "${build_dir}/install" \
    wl-screenrec

install -D -m 0755 "${build_dir}/install/bin/wl-screenrec" /usr/bin/wl-screenrec

/usr/bin/wl-screenrec --version | grep -Fq "wl-screenrec ${wl_screenrec_version}"
