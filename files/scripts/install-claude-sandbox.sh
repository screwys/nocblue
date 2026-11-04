#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d /tmp/claude-sandbox.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

curl -fsSL --retry 3 -o "${workdir}/sandbox-runtime.tgz" \
    https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/-/sandbox-runtime-0.0.81.tgz
printf '%s  %s\n' \
    0e0b8249062047f7b592c7995f8ec2f251f3bbebdc0402db1ee23af09983953f \
    "${workdir}/sandbox-runtime.tgz" | sha256sum -c -
tar -xzf "${workdir}/sandbox-runtime.tgz" -C "$workdir" \
    package/vendor/seccomp/x64/apply-seccomp package/LICENSE
install -D -m 0755 "${workdir}/package/vendor/seccomp/x64/apply-seccomp" \
    /usr/libexec/claude-sandbox/apply-seccomp
install -D -m 0644 "${workdir}/package/LICENSE" /usr/share/licenses/claude-sandbox/LICENSE
