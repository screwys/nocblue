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

build_launcher() {
    local output="$1"
    local wrapper="$2"
    local source="$3"
    local launcher

    launcher="$(root_path "${output}")"
    install -d -m 0755 "$(dirname "${launcher}")"

    cat >"${source}" <<GO
package main

import (
	"fmt"
	"os"
	"syscall"
)

const wrapper = "${wrapper}"

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
	argv := make([]string, 0, len(os.Args)+1)
	argv = append(argv, wrapper)
	if len(os.Args) > 1 {
		argv = append(argv, os.Args[1:]...)
	}

	if err := syscall.Exec(wrapper, argv, cleanEnv(os.Environ())); err != nil {
		fmt.Fprintf(os.Stderr, "nix: failed to exec %s: %v\n", wrapper, err)
		os.Exit(127)
	}
}
GO

    CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "${launcher}" "${source}"
    chmod 0755 "${launcher}"
}

build_launcher /usr/bin/nix /usr/libexec/nocblue/nix-portable/nix-wrapper "${workdir}/nix-launcher.go"
build_launcher /usr/bin/nix-profile-exec /usr/libexec/nocblue/nix-portable/nix-profile-exec-wrapper "${workdir}/nix-profile-exec-launcher.go"
