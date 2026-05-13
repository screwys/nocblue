#!/usr/bin/env bash
set -euo pipefail

real_builder="/usr/libexec/nocblue/flatpak-builder"
wrapper="/usr/bin/flatpak-builder"

if [[ ! -x "${wrapper}" ]]; then
    printf 'flatpak-builder is not installed at %s\n' "${wrapper}" >&2
    exit 1
fi

install -d -m 0755 "$(dirname "${real_builder}")"

if [[ ! -e "${real_builder}" ]]; then
    mv "${wrapper}" "${real_builder}"
fi

cat >"${wrapper}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

real_builder="/usr/libexec/nocblue/flatpak-builder"

if [[ ! -x "${real_builder}" ]]; then
    printf 'nocblue flatpak-builder wrapper cannot find %s\n' "${real_builder}" >&2
    exit 1
fi

if [[ -z "${FLATPAK_BWRAP+x}" && -x /usr/bin/nocblue-portal-bwrap ]]; then
    export FLATPAK_BWRAP=/usr/bin/nocblue-portal-bwrap
fi

exec "${real_builder}" "$@"
EOF

chmod 0755 "${wrapper}"
