#!/usr/bin/env bash
set -euo pipefail

version="v012"
base_url="https://github.com/DavHau/nix-portable/releases/download/${version}"
root="${NOCBLUE_ROOT:-}"

root_path() {
    printf '%s%s\n' "${root}" "$1"
}

case "$(uname -m)" in
    x86_64)
        asset="nix-portable-x86_64"
        sha256="b409c55904c909ac3aeda3fb1253319f86a89ddd1ba31a5dec33d4a06414c72a"
        ;;
    aarch64)
        asset="nix-portable-aarch64"
        sha256="af41d8defdb9fa17ee361220ee05a0c758d3e6231384a3f969a314f9133744ea"
        ;;
    *)
        printf 'unsupported nix-portable architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

workdir="$(mktemp -d)"
cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

curl -fL --retry 3 -o "${workdir}/${asset}" "${base_url}/${asset}"
printf '%s  %s\n' "${sha256}" "${workdir}/${asset}" | sha256sum -c -

install_dir="$(root_path /usr/libexec/nocblue/nix-portable)"
install -d -m 0755 "${install_dir}"
install -m 0755 "${workdir}/${asset}" "${install_dir}/nix-portable"
printf '%s\n' "${version}" >"${workdir}/source-version"
printf '%s\n' "${sha256}" >"${workdir}/source-sha256"
install -m 0644 "${workdir}/source-version" "${install_dir}/source-version"
install -m 0644 "${workdir}/source-sha256" "${install_dir}/source-sha256"
