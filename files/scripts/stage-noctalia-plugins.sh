#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

archive="${workdir}/noctalia-plugins.tar.gz"
archive_url="${NOCTALIA_PLUGINS_URL:-https://github.com/noctalia-dev/noctalia-plugins/archive/refs/heads/main.tar.gz}"
curl -fsSLo "${archive}" "${archive_url}"
tar -C "${workdir}" -xzf "${archive}"
src_root=""
while IFS= read -r candidate; do
    if [[ -f "${candidate}/clipper/manifest.json" && -f "${candidate}/noctalia-calculator/manifest.json" ]]; then
        src_root="${candidate}"
        break
    fi
done < <(find "${workdir}" -mindepth 1 -maxdepth 1 -type d -print)
if [[ -z "${src_root}" ]]; then
    printf 'No Noctalia plugin source root found in archive\n' >&2
    exit 1
fi

dst_root="${NOCTALIA_PLUGINS_DST:-/usr/share/nocblue/defaults/noctalia/plugins}"
mkdir -p "${dst_root}"

plugins=(
    clipper
    file-search
    kaomoji-provider
    niri-animation-picker
    niri-overview-launcher
    noctalia-calculator
    notes-scratchpad
    polkit-agent
    pomodoro
    screen-recorder
    screen-toolkit
    timer
    todo
    weather-indicator
)

for plugin in "${plugins[@]}"; do
    src="${src_root}/${plugin}"
    dst="${dst_root}/${plugin}"
    test -f "${src}/manifest.json"
    mkdir -p "${dst}"
    settings_backup=""
    if [[ -f "${dst}/settings.json" ]]; then
        settings_backup="${workdir}/${plugin}.settings.json"
        cp -a "${dst}/settings.json" "${settings_backup}"
    fi
    cp -a "${src}/." "${dst}/"
    if [[ -n "${settings_backup}" ]]; then
        cp -a "${settings_backup}" "${dst}/settings.json"
    fi
done
