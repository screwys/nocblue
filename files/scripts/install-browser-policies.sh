#!/usr/bin/env bash
set -euo pipefail

install -D -m 0644 \
    /usr/share/nocblue/browser-policies/firefox.json \
    /usr/lib64/firefox/distribution/policies.json

python3 - <<'PY'
import json
from pathlib import Path

target = Path("/usr/share/librewolf/distribution/policies.json")
extra_path = Path("/usr/share/nocblue/browser-policies/librewolf-extension-settings.json")

if target.exists():
    data = json.loads(target.read_text(encoding="utf-8"))
else:
    data = {"policies": {}}

extra = json.loads(extra_path.read_text(encoding="utf-8"))
policies = data.setdefault("policies", {})
settings = policies.setdefault("ExtensionSettings", {})
settings.update(extra["policies"]["ExtensionSettings"])

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY

install -D -m 0644 \
    /usr/share/nocblue/browser-policies/trivalent-duckduckgo.json \
    /etc/trivalent/policies/managed/nocblue-search.json
