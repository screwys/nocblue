#!/usr/bin/env bash
set -euo pipefail

wrapper="/usr/bin/nocblue-standard-malloc-run"
applications_dir="${NOCBLUE_APPLICATIONS_DIR:-/usr/share/applications}"

patch_desktop_exec() {
    local desktop_file="$1"
    shift

    [[ -f "${desktop_file}" ]] || return 0

    python3 - "${desktop_file}" "${wrapper}" "$@" <<'PY'
from pathlib import Path
import shlex
import sys

path = Path(sys.argv[1])
wrapper = sys.argv[2]
targets = sys.argv[3:]
aliases = set(targets)
for target in targets:
    aliases.add(Path(target).name)

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

    try:
        first = shlex.split(command, posix=True)[0]
    except (IndexError, ValueError):
        out.append(line)
        continue

    if first in aliases or Path(first).name in aliases:
        out.append(f"Exec={wrapper} {command}")
    else:
        out.append(line)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

patch_desktop_exec \
    "${applications_dir}/org.mozilla.firefox.desktop" \
    firefox \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox

patch_desktop_exec \
    "${applications_dir}/firefox.desktop" \
    firefox \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox

patch_desktop_exec \
    "${applications_dir}/librewolf.desktop" \
    librewolf \
    /usr/bin/librewolf \
    /usr/share/librewolf/librewolf
