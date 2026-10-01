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

runtime="$(root_path /usr/libexec/nocblue/nix)"
launcher="$(root_path /usr/bin/nix)"
install -d -m 0755 "$(dirname "${runtime}")"
if [[ ! -e "${runtime}" ]]; then
    install -m 0755 "${launcher}" "${runtime}"
fi

cat >"${workdir}/nix-launcher.go" <<'GO'
package main

import (
	"fmt"
	"os"
	"strings"
	"syscall"
)

const runtime = "/usr/libexec/nocblue/nix"

func cleanEnv(env []string) []string {
	cleaned := make([]string, 0, len(env)+2)
	hasRemote := false
	for _, entry := range env {
		name, _, _ := strings.Cut(entry, "=")
		switch name {
		case "LD_PRELOAD", "LD_AUDIT", "BASH_ENV", "SHELLOPTS", "NOCBLUE_NIX_ENV":
			continue
		case "NIX_REMOTE":
			hasRemote = true
		}
		cleaned = append(cleaned, entry)
	}
	if !hasRemote {
		cleaned = append(cleaned, "NIX_REMOTE=local")
	}
	cleaned = append(cleaned, "NOCBLUE_NIX_ENV=1")
	return cleaned
}

func main() {
	if os.Geteuid() == 0 {
		fmt.Fprintln(os.Stderr, "nix: run Nix as the desktop user, not root")
		os.Exit(1)
	}
	if err := syscall.Exec(runtime, os.Args, cleanEnv(os.Environ())); err != nil {
		fmt.Fprintf(os.Stderr, "nix: failed to exec %s: %v\n", runtime, err)
		os.Exit(127)
	}
}
GO

CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "${launcher}" "${workdir}/nix-launcher.go"
chmod 0755 "${launcher}"
