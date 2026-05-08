#!/usr/bin/env bash
set -euo pipefail

wrapper="/usr/bin/nocblue-hardened-malloc-run"
applications_dir="${NOCBLUE_APPLICATIONS_DIR:-/usr/share/applications}"

wrap_desktop_exec() {
    local desktop_file="$1"
    shift

    [[ -f "${desktop_file}" ]] || return 0

    python3 - "${desktop_file}" "${wrapper}" "$@" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
wrapper = sys.argv[2]
targets = sys.argv[3:]

lines = path.read_text(encoding="utf-8").splitlines()
out = []
for line in lines:
    if not line.startswith("Exec="):
        out.append(line)
        continue

    command = line.removeprefix("Exec=")
    if command.startswith(f"{wrapper} "):
        out.append(line)
        continue

    for target in targets:
        aliases = [target]
        if "/" in target:
            aliases.append(Path(target).name)
        for alias in aliases:
            if command == alias or command.startswith(f"{alias} "):
                line = f"Exec={wrapper} {command}"
                break
        else:
            continue
        break

    out.append(line)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

wrap_desktop_exec "${applications_dir}/trivalent.desktop" /usr/bin/trivalent
wrap_desktop_exec \
    "${applications_dir}/brave-origin-beta.desktop" \
    /usr/bin/brave-origin-beta \
    /usr/bin/brave-browser-beta \
    /opt/brave.com/brave-beta/brave-browser-beta \
    /opt/brave.com/brave/brave-browser
wrap_desktop_exec \
    "${applications_dir}/com.brave.Origin.beta.desktop" \
    /usr/bin/brave-origin-beta \
    /usr/bin/brave-browser-beta \
    /opt/brave.com/brave-beta/brave-browser-beta \
    /opt/brave.com/brave/brave-browser
wrap_desktop_exec "${applications_dir}/helium.desktop" /usr/bin/helium-browser
