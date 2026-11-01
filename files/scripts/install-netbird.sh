#!/usr/bin/env bash
set -euo pipefail

# The client scriptlet runs `netbird service install/start`, which writes and
# starts a unit during image builds. Install without scriptlets; the image
# ships netbird.service and the recipe enables it. The UI scriptlet only
# restarts a running UI.
dnf -y install \
    --setopt=install_weak_deps=False \
    --setopt=tsflags=noscripts \
    netbird \
    netbird-ui

# The scriptlet would also restrict this file, which may hold a token PIN.
chmod 0600 /etc/sysconfig/netbird
