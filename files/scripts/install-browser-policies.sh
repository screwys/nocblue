#!/usr/bin/env bash
set -euo pipefail

install -D -m 0644 \
    /usr/share/nocblue/browser-policies/firefox.json \
    /usr/lib64/firefox/distribution/policies.json

python3 - <<'PY'
import json
from pathlib import Path

targets = (
    Path("/usr/share/librewolf/distribution/policies.json"),
    Path("/usr/lib64/librewolf/distribution/policies.json"),
    Path("/usr/lib/librewolf/distribution/policies.json"),
)
extra_path = Path("/usr/share/nocblue/browser-policies/librewolf-extension-settings.json")

data = {"policies": {}}
for target in targets:
    if target.exists():
        data = json.loads(target.read_text(encoding="utf-8"))
        break

extra = json.loads(extra_path.read_text(encoding="utf-8"))
policies = data.setdefault("policies", {})

for key, value in extra["policies"].items():
    if isinstance(value, dict) and isinstance(policies.get(key), dict):
        policies[key].update(value)
    else:
        policies[key] = value

for target in targets:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY

install -D -m 0644 \
    /usr/share/nocblue/browser-policies/trivalent-duckduckgo.json \
    /etc/trivalent/policies/managed/nocblue-search.json

install -D -m 0644 \
    /usr/share/nocblue/browser-policies/trivalent-extensions.json \
    /etc/trivalent/policies/managed/nocblue-extensions.json

install_chromium_policy() {
    local target_dir="$1"
    install -D -m 0644 \
        /usr/share/nocblue/browser-policies/chromium-extensions.json \
        "${target_dir}/nocblue-extensions.json"
}

install_chromium_policy /etc/chromium/policies/managed

python3 - <<'PY'
import json
from pathlib import Path

target = Path("/etc/trivalent/master_preferences")
extra_path = Path("/usr/share/nocblue/browser-policies/trivalent-master-preferences.json")

try:
    data = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
except Exception:
    data = {}

extra = json.loads(extra_path.read_text(encoding="utf-8"))

def deep_merge(dst, src):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            deep_merge(dst[key], value)
        else:
            dst[key] = value

deep_merge(data, extra)
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY

install -d -m 0755 /etc/trivalent/trivalent.conf.d
cat > /etc/trivalent/trivalent.conf.d/20-nocblue.conf <<'EOF'
CHROMIUM_FLAGS+=" --gtk-version=4"
EOF
