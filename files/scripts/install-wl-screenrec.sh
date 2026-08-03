#!/usr/bin/env bash
set -euo pipefail

wl_screenrec_version="0.2.0"
wl_screenrec_revision="719619426e1f5a5680ed1d05565366a1c28223f5"
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
