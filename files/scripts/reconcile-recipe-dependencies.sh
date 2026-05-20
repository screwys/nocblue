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

select_latest_package_providing_qt_abi() {
    local package="$1"
    local qt_abi="$2"
    local candidate selected

    while IFS= read -r candidate; do
        [[ -n "${candidate}" ]] || continue
        if repoquery_provides "${candidate}" | grep -q "Qt_${qt_abi}_PRIVATE_API"; then
            selected="${candidate}"
        fi
    done < <(repoquery_available "${package}" | sort -V)

    [[ -n "${selected:-}" ]] || return 1
    printf '%s\n' "${selected}"
}

select_latest_package_requiring_only_qt_abi() {
    local package="$1"
    local qt_abi="$2"
    local candidate required_versions selected

    while IFS= read -r candidate; do
        [[ -n "${candidate}" ]] || continue
        required_versions="$(repoquery_requires "${candidate}" | private_abi_versions_from_requires)"
        if [[ -z "${required_versions}" || "${required_versions}" == "${qt_abi}" ]]; then
            selected="${candidate}"
        fi
    done < <(repoquery_available "${package}" | sort -V)

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

while IFS= read -r capability; do
    [[ -n "${capability}" ]] || continue
    add_nevra "$(select_latest_provider_for_capability "${capability}")"
done < <(repoquery_requires noctalia-qs | grep "Qt_${qt_abi}_PRIVATE_API" | sort -u)

for package in qt6-qtsvg qt6-qt5compat; do
    add_nevra "$(select_latest_package_providing_qt_abi "${package}" "${qt_abi}")"
done

add_nevra "$(select_latest_package_requiring_only_qt_abi plasma-workspace "${qt_abi}")"

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
