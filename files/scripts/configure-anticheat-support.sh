#!/usr/bin/env bash
set -euo pipefail

sysctl_ptrace_file="/etc/sysctl.d/61-ptrace-scope.conf"

ptrace_enabled() {
    grep -q '^kernel.yama.ptrace_scope[[:blank:]]*=[[:blank:]]*1$' "${sysctl_ptrace_file}" 2>/dev/null
}

if ptrace_enabled; then
    exit 0
fi

if command -v ujust >/dev/null 2>&1 &&
    ujust --list | grep -Eq '^[[:space:]]*toggle-anticheat-support([[:space:]]|$)' &&
    ujust toggle-anticheat-support &&
    ptrace_enabled; then
    exit 0
fi

if ! ptrace_enabled; then
    umask 022
    for conf_file in /etc/sysctl.d/*.conf; do
        [[ -e "${conf_file}" ]] || continue
        if [[ "${conf_file}" < "${sysctl_ptrace_file}" ]]; then
            sed -i -e '/^kernel.yama.ptrace_scope[[:blank:]]*=[[:blank:]]*3/d' "${conf_file}"
        fi
    done
    printf 'kernel.yama.ptrace_scope = 1\n' >"${sysctl_ptrace_file}"
fi

ptrace_enabled
