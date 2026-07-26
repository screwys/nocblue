#!/usr/bin/env bash
set -euo pipefail

root="${NOCBLUE_ROOT:-}"

root_path() {
    printf '%s%s\n' "${root}" "$1"
}

workdir="$(mktemp -d)"
cleanup() {
    rm -rf "${workdir}"
}
trap cleanup EXIT

install_launcher() {
    local name="$1"
    local command
    local target
    local source

    command="$(root_path "/usr/bin/${name}")"
    target="$(root_path "/usr/libexec/nocblue/${name}")"
    source="${workdir}/${name}-launcher.go"

    test -x "${command}"
    install -d -m 0755 "$(dirname "${target}")"
    mv "${command}" "${target}"

    cat >"${source}" <<GO
package main

import (
    "fmt"
    "os"
    "syscall"
)

const target = "${target}"

func cleanEnv(env []string) []string {
    cleaned := make([]string, 0, len(env))
    for _, entry := range env {
        switch {
        case len(entry) >= len("LD_PRELOAD=") && entry[:len("LD_PRELOAD=")] == "LD_PRELOAD=":
            continue
        case len(entry) >= len("LD_AUDIT=") && entry[:len("LD_AUDIT=")] == "LD_AUDIT=":
            continue
        default:
            cleaned = append(cleaned, entry)
        }
    }
    return cleaned
}

func main() {
    if err := syscall.Exec(target, os.Args, cleanEnv(os.Environ())); err != nil {
        fmt.Fprintf(os.Stderr, "${name}: failed to exec %s: %v\n", target, err)
        os.Exit(127)
    }
}
GO

    CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "${command}" "${source}"
    chmod 0755 "${command}"
}

install_launcher uv
install_launcher uvx
