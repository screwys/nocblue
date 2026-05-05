#!/usr/bin/env bash
set -euo pipefail

pywalfox_version="2.7.4"

pipx install --global --force --pip-args='--no-cache-dir' "pywalfox==${pywalfox_version}"

/usr/local/bin/pywalfox install --global

test -x /usr/local/bin/pywalfox
test -f /usr/lib/mozilla/native-messaging-hosts/pywalfox.json
