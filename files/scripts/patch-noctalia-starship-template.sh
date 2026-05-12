#!/usr/bin/env bash
set -euo pipefail

script_path="${NOCTALIA_TEMPLATE_APPLY_SCRIPT:-/etc/xdg/quickshell/noctalia-shell/Scripts/bash/template-apply.sh}"

if [[ ! -f "${script_path}" ]]; then
    exit 0
fi

python3 - "${script_path}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = 'starship)\n'
fallback = '    PALETTE_FILE="${PALETTE_FILE:-${HOME}/.cache/noctalia/starship-palette.toml}"\n'

if fallback in text or needle not in text:
    raise SystemExit(0)

text = text.replace(needle, needle + fallback, 1)
path.write_text(text, encoding="utf-8")
PY
