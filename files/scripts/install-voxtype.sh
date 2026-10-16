#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/voxtype.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

version=1.1.1
package="voxtype-${version}-1.x86_64.rpm"
curl -fsSL --retry 3 -o "${workdir}/${package}" \
    "https://github.com/peteonrails/voxtype/releases/download/v${version}/${package}"
printf '%s  %s\n' \
    5d0704d2f8bff4b02ca7d6ace1eab20caf8b3bbbc137f3e1a268af5021509872 \
    "${workdir}/${package}" | sha256sum -c -
dnf -y install --setopt=install_weak_deps=False "${workdir}/${package}"

# Include a small multilingual model so dictation works offline on first use.
curl -fsSL --retry 3 -o "${workdir}/ggml-base.bin" \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
printf '%s  %s\n' \
    60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe \
    "${workdir}/ggml-base.bin" | sha256sum -c -
install -D -m 0644 "${workdir}/ggml-base.bin" /usr/share/voxtype/models/ggml-base.bin

voxtype --version
