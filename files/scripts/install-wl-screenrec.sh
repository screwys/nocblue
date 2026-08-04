#!/usr/bin/env bash
set -euo pipefail

wl_screenrec_version="0.2.0"
# The v0.2.0 tag predates upstream's FFmpeg 8.1 dependency update. Pin the
# current upstream revision that builds against Fedora 44's headers.
wl_screenrec_revision="09252908c6304f0b71a5af9ddddf587559fbc471"
build_dir="$(mktemp -d /tmp/nocblue-wl-screenrec-build-XXXXXX)"
source_dir="${build_dir}/source"

cleanup() {
    rm -rf "${build_dir}"
}
trap cleanup EXIT

export CARGO_HOME="${build_dir}/cargo-home"

git init "${source_dir}"
git -C "${source_dir}" remote add origin https://github.com/russelltg/wl-screenrec
git -C "${source_dir}" fetch --depth 1 origin "${wl_screenrec_revision}"
git -C "${source_dir}" checkout --detach FETCH_HEAD
test "$(git -C "${source_dir}" rev-parse HEAD)" = "${wl_screenrec_revision}"

# Fedora's FFmpeg chooses MPEG-4 Part 2 for MP4 output. wl-screenrec has no
# VA-API mapping for that codec, so automatic recording fails before the first
# frame. Prefer AVC only when the muxer returns MPEG-4; explicit codec choices
# and other automatic container defaults remain unchanged.
patch -d "${source_dir}" -p1 <<'PATCH'
--- a/src/main.rs
+++ b/src/main.rs
@@ -1704,7 +1704,10 @@ fn get_encoder(args: &Args, format: &Output) -> anyhow::Result<ffmpeg::Codec> {
         })?
     } else {
         let codec_id = match args.codec {
-            Codec::Auto => format.codec(&args.filename, media::Type::Video),
+            Codec::Auto => match format.codec(&args.filename, media::Type::Video) {
+                codec::Id::MPEG4 => codec::Id::H264,
+                codec_id => codec_id,
+            },
             Codec::Avc => codec::Id::H264,
             Codec::Hevc => codec::Id::HEVC,
             Codec::VP8 => codec::Id::VP8,
PATCH

env -u LD_PRELOAD cargo install \
    --path "${source_dir}" \
    --locked \
    --root "${build_dir}/install" \
    wl-screenrec

install -D -m 0755 "${build_dir}/install/bin/wl-screenrec" /usr/bin/wl-screenrec

/usr/bin/wl-screenrec --version | grep -Fq "wl-screenrec ${wl_screenrec_version}"
