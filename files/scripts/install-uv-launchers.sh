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

func hasPreload() bool {
    fi, err := os.Stat("/etc/ld.so.preload")
    if err == nil && fi.Mode().IsRegular() && fi.Size() > 0 {
        return true
    }
    fi, err = os.Stat("/usr/etc/ld.so.preload")
    if err == nil && fi.Mode().IsRegular() && fi.Size() > 0 {
        return true
    }
    return false
}

func main() {
    env := cleanEnv(os.Environ())
    if hasPreload() {
        bwrapArgs := []string{
            "bwrap",
            "--dev-bind", "/", "/",
            "--ro-bind-try", "/dev/null", "/etc/ld.so.preload",
            "--ro-bind-try", "/dev/null", "/usr/etc/ld.so.preload",
            "--unsetenv", "LD_PRELOAD",
            "--unsetenv", "LD_AUDIT",
            "--",
            target,
        }
        bwrapArgs = append(bwrapArgs, os.Args[1:]...)
        if err := syscall.Exec("/usr/bin/bwrap", bwrapArgs, env); err != nil {
            fmt.Fprintf(os.Stderr, "${name}: failed to exec bwrap: %v\n", err)
            os.Exit(127)
        }
    }

    if err := syscall.Exec(target, os.Args, env); err != nil {
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
