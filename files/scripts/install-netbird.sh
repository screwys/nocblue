#!/usr/bin/env bash
set -euo pipefail

# The package scriptlet runs `netbird service install/start`, which writes and
# starts a unit during image builds. Install it without scriptlets; the image
# ships netbird.service and the recipe enables it.
dnf -y install \
    --repo=netbird \
    --setopt=install_weak_deps=False \
    --setopt=tsflags=noscripts \
    netbird

# The scriptlet would also restrict this file, which may hold a token PIN.
chmod 0600 /etc/sysconfig/netbird
