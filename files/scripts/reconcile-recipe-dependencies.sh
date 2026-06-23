#!/usr/bin/env bash
set -euo pipefail

dnf_cmd="$(command -v dnf5 || command -v dnf)"
base_arch="$(rpm -E '%{_arch}')"
repo_root="${CONFIG_DIRECTORY:-/tmp/files}/dnf"

log() {
    printf 'nocblue dependency resolver: %s\n' "$*"
}

install_repo_file() {
    local repo_file="$1"
    local source="${repo_root}/${repo_file}"

    if [[ -f "${source}" ]]; then
        if [[ -w /etc/yum.repos.d ]]; then
            install -D -m 0644 "${source}" "/etc/yum.repos.d/${repo_file}"
        elif [[ ! -f "/etc/yum.repos.d/${repo_file}" ]]; then
            printf 'nocblue dependency resolver: cannot install %s without write access to /etc/yum.repos.d\n' "${repo_file}" >&2
            exit 1
        fi
    fi
}

repoquery_available() {
    "${dnf_cmd}" -q repoquery --available --arch "${base_arch}" --queryformat '%{full_nevra}\n' "$@" 2>/dev/null || true
}

repoquery_evr() {
    "${dnf_cmd}" -q repoquery --available --arch "${base_arch}" --queryformat '%{evr}\n' "$1" 2>/dev/null | head -n 1
}

repoquery_provides() {
    "${dnf_cmd}" -q repoquery --available --provides "$@" 2>/dev/null || true
}

repoquery_requires() {
    "${dnf_cmd}" -q repoquery --available --requires "$@" 2>/dev/null || true
}

repoquery_provider_nevras() {
    "${dnf_cmd}" -q repoquery --available --arch "${base_arch}" --whatprovides "$1" --queryformat '%{full_nevra}\n' 2>/dev/null || true
}

private_abi_versions_from_requires() {
    sed -nE 's/.*Qt_([0-9]+\.[0-9]+)_PRIVATE_API.*/\1/p' | sort -Vu
}

add_nevra() {
    local nevra="$1"

    [[ -n "${nevra}" ]] || return 0
    if [[ -z "${seen_nevras[${nevra}]+x}" ]]; then
        seen_nevras["${nevra}"]=1
        selected_nevras+=("${nevra}")
    fi
}

select_latest_provider_for_capability() {
    local capability="$1"

    repoquery_provider_nevras "${capability}" | sort -V | tail -n 1
}

select_latest_package() {
    local package="$1"

    repoquery_available "${package}" | sort -V | tail -n 1
}

select_package_with_evr() {
    local package="$1"
    local evr="$2"
    local selected

    selected="$(repoquery_available "${package}-${evr}.${base_arch}" | sort -V | tail -n 1)"
    [[ -n "${selected:-}" ]] || return 1
    printf '%s\n' "${selected}"
}

install_repo_file terra.repo

mapfile -t noctalia_qt_abis < <(repoquery_requires noctalia-qs | private_abi_versions_from_requires)
if ((${#noctalia_qt_abis[@]} == 0)); then
    log 'no noctalia-qs Qt private ABI requirement found; nothing to reconcile'
    exit 0
fi

if ((${#noctalia_qt_abis[@]} != 1)); then
    printf 'nocblue dependency resolver: ambiguous noctalia-qs Qt private ABI requirements:\n' >&2
    printf '  %s\n' "${noctalia_qt_abis[@]}" >&2
    exit 1
fi

qt_abi="${noctalia_qt_abis[0]}"
declare -A seen_nevras=()
selected_nevras=()

log "reconciling desktop Qt stack for Qt ${qt_abi} private ABI"

qtbase_capability="libQt6Core.so.6(Qt_${qt_abi}_PRIVATE_API)(64bit)"
qtbase_nevra="$(select_latest_provider_for_capability "${qtbase_capability}")"
qt_evr="$(repoquery_evr "${qtbase_nevra}")"
if [[ -z "${qtbase_nevra}" || -z "${qt_evr}" ]]; then
    printf 'nocblue dependency resolver: could not resolve provider for %s\n' "${qtbase_capability}" >&2
    exit 1
fi

for package in \
    qt6-qtbase \
    qt6-qtbase-gui \
    qt6-qtdeclarative \
    qt6-qtmultimedia \
    qt6-qtsvg \
    qt6-qt5compat \
    qt6-qtwayland; do
    if nevra="$(select_package_with_evr "${package}" "${qt_evr}")"; then
        add_nevra "${nevra}"
    fi
done

add_nevra "$(select_latest_package noctalia-shell)"

if ((${#selected_nevras[@]} == 0)); then
    log 'no packages selected; nothing to reconcile'
    exit 0
fi

printf 'nocblue dependency resolver: selected compatible packages:\n'
printf '  %s\n' "${selected_nevras[@]}"

if [[ "${NOCBLUE_RECONCILE_DRY_RUN:-}" == "1" ]]; then
    "${dnf_cmd}" --assumeno --setopt=install_weak_deps=False install --allowerasing "${selected_nevras[@]}"
else
    "${dnf_cmd}" -y --setopt=install_weak_deps=False install --allowerasing "${selected_nevras[@]}"
fi
