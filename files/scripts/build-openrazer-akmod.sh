#!/usr/bin/env bash
set -euo pipefail

dnf_cmd="$(command -v dnf5 || command -v dnf)"
repo_root="${CONFIG_DIRECTORY:-/tmp/files}/dnf"

log() {
    printf 'nocblue openrazer akmod: %s\n' "$*"
}

install_repo_file() {
    local repo_file="$1"
    local source="${repo_root}/${repo_file}"

    if [[ -f "${source}" ]]; then
        if [[ -w /etc/yum.repos.d ]]; then
            install -D -m 0644 "${source}" "/etc/yum.repos.d/${repo_file}"
        elif [[ ! -f "/etc/yum.repos.d/${repo_file}" ]]; then
            printf 'nocblue openrazer akmod: cannot install %s without write access to /etc/yum.repos.d\n' "${repo_file}" >&2
            exit 1
        fi
    fi
}

install_repo_file ublue-akmods.repo

mapfile -t kernel_versions < <(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -V)
if ((${#kernel_versions[@]} == 0)); then
    printf 'nocblue openrazer akmod: no installed kernel module trees found\n' >&2
    exit 1
fi

printf 'nocblue openrazer akmod: target kernels:\n'
printf '  %s\n' "${kernel_versions[@]}"

if [[ "${NOCBLUE_OPENRAZER_AKMOD_DRY_RUN:-}" == "1" ]]; then
    "${dnf_cmd}" -q repoquery --available --queryformat '%{full_nevra}\n' akmod-openrazer openrazer-kmod-common
    exit 0
fi

"${dnf_cmd}" -y --setopt=install_weak_deps=False install \
    akmod-openrazer \
    cpio \
    kernel-devel-matched

srpm="$(find /usr/src/akmods -maxdepth 1 -type f -name 'openrazer-kmod-*.src.rpm' | sort -V | tail -n 1)"
if [[ -z "${srpm}" ]]; then
    printf 'nocblue openrazer akmod: no OpenRazer source RPM found in /usr/src/akmods\n' >&2
    exit 1
fi

tmpdir="$(mktemp -d -p /tmp nocblue-openrazer.XXXXXXXX)"
cleanup() {
    rm -rf "${tmpdir}"
}
trap cleanup EXIT

install -d -o akmods -g akmods "${tmpdir}/results"
chown akmods:akmods "${tmpdir}"

for kernel_version in "${kernel_versions[@]}"; do
    log "building OpenRazer module for ${kernel_version}"
    if ! runuser -u akmods -- akmodsbuild \
        --kernels "${kernel_version}" \
        --outputdir "${tmpdir}/results" \
        --logfile "${tmpdir}/akmodsbuild-${kernel_version}.log" \
        "${srpm}"; then
        sed -n '1,220p' "${tmpdir}/akmodsbuild-${kernel_version}.log" 2>/dev/null || true
        exit 1
    fi
done

mapfile -t module_rpms < <(find "${tmpdir}/results" -type f -name '*.rpm' ! -name '*debuginfo*' | sort -V)
if ((${#module_rpms[@]} == 0)); then
    printf 'nocblue openrazer akmod: OpenRazer akmod build did not produce module RPMs\n' >&2
    exit 1
fi

"${dnf_cmd}" -y --setopt=install_weak_deps=False install "${module_rpms[@]}"

for kernel_version in "${kernel_versions[@]}"; do
    depmod "${kernel_version}"
    if ! find "/usr/lib/modules/${kernel_version}" -type f -name 'razer*.ko*' | grep -q .; then
        printf 'nocblue openrazer akmod: no razer kernel module found for %s\n' "${kernel_version}" >&2
        exit 1
    fi
done
