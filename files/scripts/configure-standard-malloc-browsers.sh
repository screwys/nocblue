#!/usr/bin/env bash
set -euo pipefail

standard_wrapper="/usr/bin/nocblue-standard-malloc-run"
applications_dir="${NOCBLUE_APPLICATIONS_DIR:-/usr/share/applications}"

patch_desktop_exec() {
    local desktop_file="$1"
    local wrapper="$2"
    shift
    shift

    [[ -f "${desktop_file}" ]] || return 0

    python3 - "${desktop_file}" "${wrapper}" "$@" <<'PY'
from pathlib import Path
import shlex
import sys

path = Path(sys.argv[1])
wrapper = sys.argv[2]
targets = sys.argv[3:]
hardened_wrapper = "/usr/bin/nocblue-hardened-malloc-run"
standard_wrapper = "/usr/bin/nocblue-standard-malloc-run"
known_wrappers = {wrapper, hardened_wrapper, standard_wrapper}
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
        parts = shlex.split(command, posix=True)
    except (IndexError, ValueError):
        out.append(line)
        continue

    if not parts:
        out.append(line)
        continue

    first = parts[0]
    command_to_wrap = command
    if first in known_wrappers and len(parts) > 1:
        first = parts[1]
        command_to_wrap = shlex.join(parts[1:])

    if first in aliases or Path(first).name in aliases:
        out.append(f"Exec={wrapper} {command_to_wrap}")
    else:
        out.append(line)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

patch_desktop_exec \
    "${applications_dir}/org.mozilla.firefox.desktop" \
    "${standard_wrapper}" \
    firefox \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox

patch_desktop_exec \
    "${applications_dir}/firefox.desktop" \
    "${standard_wrapper}" \
    firefox \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox

patch_desktop_exec \
    "${applications_dir}/librewolf.desktop" \
    "${standard_wrapper}" \
    librewolf \
    /usr/bin/librewolf \
    /usr/share/librewolf/librewolf

patch_desktop_exec \
    "${applications_dir}/mullvad-browser.desktop" \
    "${standard_wrapper}" \
    mullvad-browser \
    /usr/bin/mullvad-browser \
    /usr/lib/mullvad-browser/start-mullvad-browser
