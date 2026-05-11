#!/usr/bin/env bash
set -euo pipefail

candy_ref="${NOCBLUE_CANDY_ICONS_REF:-master}"
archive_url="${NOCBLUE_CANDY_ICONS_ARCHIVE_URL:-https://github.com/EliverLara/candy-icons/archive/refs/heads/${candy_ref}.tar.gz}"
workdir="$(mktemp -d)"
root="${NOCBLUE_ROOT:-}"

root_path() {
    printf '%s%s\n' "${root}" "$1"
}

cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

curl -fsSLo "${workdir}/candy-icons.tar.gz" "${archive_url}"
tar -xzf "${workdir}/candy-icons.tar.gz" -C "${workdir}"
src_root="$(find "${workdir}" -maxdepth 1 -type d -name 'candy-icons-*' -print -quit)"
test -n "${src_root}"
test -f "${src_root}/index.theme"

theme_dir="$(root_path /usr/share/icons/candy-icons)"
compat_dir="$(root_path /usr/share/icons/Candy)"
rm -rf "${theme_dir}"
install -d -m 0755 "${theme_dir}"

for entry in apps devices mimetypes places preferences status; do
    test -d "${src_root}/${entry}"
    cp -a "${src_root}/${entry}" "${theme_dir}/"
done

install -m 0644 "${src_root}/index.theme" "${theme_dir}/"
install -m 0644 "${src_root}/LICENSE" "${theme_dir}/"

ln -sfn chromium.svg "${theme_dir}/apps/scalable/trivalent.svg"
ln -sfn brave-browser-beta.svg "${theme_dir}/apps/scalable/brave-origin-beta.svg"
ln -sfn brave-browser-beta.svg "${theme_dir}/apps/scalable/com.brave.Origin.beta.svg"
printf '%s\n' "${candy_ref}" >"${theme_dir}/nocblue-source-ref"
rm -rf "${compat_dir}"
ln -sfnT candy-icons "${compat_dir}"
