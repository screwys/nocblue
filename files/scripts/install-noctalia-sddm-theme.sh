#!/usr/bin/env bash
set -euo pipefail

theme_commit="0b80d9a76f9bb7c871b0ceeb308b57e0b6e6f15a"
archive_url="${NOCBLUE_NOCTALIA_SDDM_ARCHIVE_URL:-https://github.com/screwys/noctalia-sddm-theme/archive/${theme_commit}.tar.gz}"
workdir="$(mktemp -d)"
root="${NOCBLUE_ROOT:-}"

root_path() {
    printf '%s%s\n' "${root}" "$1"
}

cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

curl -fsSLo "${workdir}/theme.tar.gz" "${archive_url}"
tar -xzf "${workdir}/theme.tar.gz" -C "${workdir}"
src_root="$(find "${workdir}" -maxdepth 1 -type d -name 'noctalia-sddm-theme*' -print -quit)"
test -n "${src_root}"

theme_dir="$(root_path /usr/share/sddm/themes/noctalia)"
state_dir="$(root_path /var/lib/nocblue/sddm)"

rm -rf "${theme_dir}"
install -d -m 0755 "${theme_dir}" "${state_dir}"

cp -a "${src_root}/Assets" "${theme_dir}/"
cp -a "${src_root}/Components" "${theme_dir}/"
install -m 0644 \
    "${src_root}/Globals.qml" \
    "${src_root}/LICENSE" \
    "${src_root}/Main.qml" \
    "${src_root}/metadata.desktop" \
    "${src_root}/qmldir" \
    "${src_root}/theme.template.conf" \
    "${theme_dir}/"
install -m 0644 "${src_root}/theme.conf" "${theme_dir}/theme.default.conf"

sed -i 's|^background=.*|background=file:///var/lib/nocblue/sddm/background.png|' \
    "${theme_dir}/theme.default.conf" \
    "${theme_dir}/theme.template.conf"

ln -sfn /var/lib/nocblue/sddm/theme.conf "${theme_dir}/theme.conf"
printf '%s\n' "${theme_commit}" > "${theme_dir}/nocblue-source-commit"

install -m 0666 "${theme_dir}/theme.default.conf" "${state_dir}/theme.conf"
install -m 0666 "$(root_path /usr/share/backgrounds/nocblue/green-eyes.png)" "${state_dir}/background.png"
