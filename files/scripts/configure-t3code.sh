#!/usr/bin/env bash
set -euo pipefail

test -x /usr/lib64/t3code-nightly/t3code
rm -f /usr/bin/t3code-nightly
install -m 0755 /usr/share/nocblue/launchers/t3code-nightly /usr/bin/t3code-nightly
