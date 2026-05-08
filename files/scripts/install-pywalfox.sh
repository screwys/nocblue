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
    /usr/lib64/mozilla/native-messaging-hosts \
    /usr/share/mozilla/native-messaging-hosts \
    /usr/share/librewolf/native-messaging-hosts \
    /usr/lib64/librewolf/native-messaging-hosts \
    /usr/lib/librewolf/native-messaging-hosts

cat >/usr/libexec/pywalfox-native-messaging-host <<'EOF'
#!/usr/bin/env bash
unset LD_PRELOAD
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
    Path("/usr/share/mozilla/native-messaging-hosts/pywalfox.json"),
    Path("/usr/share/librewolf/native-messaging-hosts/pywalfox.json"),
    Path("/usr/lib64/librewolf/native-messaging-hosts/pywalfox.json"),
    Path("/usr/lib/librewolf/native-messaging-hosts/pywalfox.json"),
):
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

python3 - <<'PY'
import json
import struct
import subprocess

payload = json.dumps({"action": "debug:version"}).encode("utf-8")
message = struct.pack("<I", len(payload)) + payload
proc = subprocess.run(
    ["/usr/libexec/pywalfox-native-messaging-host"],
    input=message,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
    timeout=5,
)
length = struct.unpack("<I", proc.stdout[:4])[0]
response = json.loads(proc.stdout[4 : 4 + length].decode("utf-8"))
assert response["action"] == "debug:version"
assert response["success"] is True
assert response["data"] == "2.7.4"
PY

test -x /usr/bin/pywalfox
test ! -e /usr/local/bin/pywalfox
test -x /usr/libexec/pywalfox-native-messaging-host
test -f /usr/lib/mozilla/native-messaging-hosts/pywalfox.json
test -f /usr/lib64/mozilla/native-messaging-hosts/pywalfox.json
test -f /usr/share/mozilla/native-messaging-hosts/pywalfox.json
test -f /usr/share/librewolf/native-messaging-hosts/pywalfox.json
test -f /usr/lib64/librewolf/native-messaging-hosts/pywalfox.json
test -f /usr/lib/librewolf/native-messaging-hosts/pywalfox.json
