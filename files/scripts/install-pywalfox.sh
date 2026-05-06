#!/usr/bin/env bash
set -euo pipefail

pywalfox_version="2.7.4"

export PIPX_GLOBAL_HOME=/usr/lib/opt/pipx
export PIPX_GLOBAL_BIN_DIR=/usr/bin
export PIPX_GLOBAL_MAN_DIR=/usr/share/man

pipx install --global --force --pip-args='--no-cache-dir' "pywalfox==${pywalfox_version}"

rm -f /usr/local/bin/pywalfox

/usr/bin/pywalfox install --global

test -x /usr/bin/pywalfox
test ! -e /usr/local/bin/pywalfox
test -f /usr/lib/mozilla/native-messaging-hosts/pywalfox.json
