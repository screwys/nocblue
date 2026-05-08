#!/usr/bin/env bash
set -euo pipefail

pywalfox_version="2.7.4"

export PIPX_GLOBAL_HOME=/usr/lib/opt/pipx
export PIPX_GLOBAL_BIN_DIR=/usr/bin
export PIPX_GLOBAL_MAN_DIR=/usr/share/man

pipx install --global --force --pip-args='--no-cache-dir' "pywalfox==${pywalfox_version}"

rm -f /usr/local/bin/pywalfox

/usr/bin/pywalfox install --global

install -d -m 0755 \
    /usr/libexec \
    /usr/lib/mozilla/native-messaging-hosts \
    /usr/lib64/mozilla/native-messaging-hosts

cat >/usr/libexec/pywalfox-native-messaging-host <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/pywalfox start "$@"
EOF
chmod 0755 /usr/libexec/pywalfox-native-messaging-host

python3 - <<'PY'
import json
from pathlib import Path

manifest = Path("/usr/lib/mozilla/native-messaging-hosts/pywalfox.json")
data = json.loads(manifest.read_text(encoding="utf-8"))
data["path"] = "/usr/libexec/pywalfox-native-messaging-host"
for target in (
    manifest,
    Path("/usr/lib64/mozilla/native-messaging-hosts/pywalfox.json"),
):
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

test -x /usr/bin/pywalfox
test ! -e /usr/local/bin/pywalfox
test -x /usr/libexec/pywalfox-native-messaging-host
test -f /usr/lib/mozilla/native-messaging-hosts/pywalfox.json
test -f /usr/lib64/mozilla/native-messaging-hosts/pywalfox.json
