#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

api_url="https://api.github.com/repos/jesseduffield/lazygit/releases/latest"
release_json="${tmpdir}/release.json"
curl -fsSL "${api_url}" -o "${release_json}"

asset_url="$(
    jq -r '.assets[] | select(.name | test("linux_x86_64\\.tar\\.gz$")) | .browser_download_url' \
        "${release_json}" \
        | head -n 1
)"
checksum_url="$(
    jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url' \
        "${release_json}" \
        | head -n 1
)"

test -n "${asset_url}"
test -n "${checksum_url}"

asset="${tmpdir}/lazygit.tar.gz"
checksums="${tmpdir}/checksums.txt"
curl -fsSL "${asset_url}" -o "${asset}"
curl -fsSL "${checksum_url}" -o "${checksums}"

asset_name="$(basename "${asset_url}")"
expected="$(awk -v asset_name="${asset_name}" '$2 == asset_name { print $1 }' "${checksums}")"
test -n "${expected}"
printf '%s  %s\n' "${expected}" "${asset}" | sha256sum -c -

tar -xzf "${asset}" -C "${tmpdir}" lazygit
install -D -m 0755 "${tmpdir}/lazygit" /usr/bin/lazygit
