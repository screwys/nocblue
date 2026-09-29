#!/usr/bin/env bash
set -euo pipefail

browser_no_preload_wrapper="/usr/bin/nocblue-browser-no-preload"
applications_dir="${NOCBLUE_APPLICATIONS_DIR:-/usr/share/applications}"

install_command_wrapper() {
    local command_path="$1"
    local target_path="$2"
    local tmpfile

    if [[ ! -x "${target_path}" ]]; then
        printf 'missing browser target for command wrapper: %s\n' "${target_path}" >&2
        exit 1
    fi

    tmpfile="$(mktemp)"
    cat >"${tmpfile}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec ${browser_no_preload_wrapper} ${target_path} "\$@"
EOF

    rm -f "${command_path}"
    install -D -m 0755 "${tmpfile}" "${command_path}"
    rm -f "${tmpfile}"
}

patch_shell_launcher() {
    local launcher_path="$1"
    local wrapper_target="$2"

    [[ -f "${launcher_path}" ]] || return 0

    python3 - "${launcher_path}" "${browser_no_preload_wrapper}" "${wrapper_target}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
wrapper = sys.argv[2]
target = sys.argv[3]
marker = "NOCBLUE_BROWSER_NO_PRELOAD"
block = [
    "",
    f'if [ "${{{marker}:-}}" != "1" ]; then',
    f'    exec {wrapper} {target} "$@"',
    "fi",
]

lines = path.read_text(encoding="utf-8").splitlines()
filtered = []
i = 0
while i < len(lines):
    if (
        marker in lines[i]
        and i + 2 < len(lines)
        and lines[i + 1].lstrip().startswith("exec ")
        and lines[i + 2] == "fi"
    ):
        if filtered and filtered[-1] == "":
            filtered.pop()
        i += 3
        continue
    filtered.append(lines[i])
    i += 1
lines = filtered

insert_at = 1 if lines and lines[0].startswith("#!") else 0
lines[insert_at:insert_at] = block
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

patch_desktop_exec() {
    local desktop_file="$1"
    shift

    [[ -f "${desktop_file}" ]] || return 0

    python3 - "${desktop_file}" "$@" <<'PY'
from pathlib import Path
import shlex
import sys

path = Path(sys.argv[1])
targets = sys.argv[2:]
preferred_command = targets[0]
hardened_wrapper = "/usr/bin/nocblue-hardened-malloc-run"
standard_wrapper = "/usr/bin/nocblue-standard-malloc-run"
browser_no_preload_wrapper = "/usr/bin/nocblue-browser-no-preload"
known_wrappers = {hardened_wrapper, standard_wrapper, browser_no_preload_wrapper}
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
    try:
        parts = shlex.split(command, posix=True)
    except (IndexError, ValueError):
        out.append(line)
        continue

    if not parts:
        out.append(line)
        continue

    first = parts[0]
    command_to_wrap = parts
    if first in known_wrappers and len(parts) > 1:
        first = parts[1]
        command_to_wrap = parts[1:]

    if first in aliases or Path(first).name in aliases:
        command_to_wrap[0] = preferred_command
        out.append(f"Exec={shlex.join(command_to_wrap)}")
    else:
        out.append(line)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

patch_desktop_exec \
    "${applications_dir}/org.mozilla.firefox.desktop" \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox \
    firefox

patch_desktop_exec \
    "${applications_dir}/firefox.desktop" \
    /usr/bin/firefox \
    /usr/lib64/firefox/firefox \
    firefox

patch_desktop_exec \
    "${applications_dir}/librewolf.desktop" \
    /usr/bin/librewolf \
    /usr/share/librewolf/librewolf \
    librewolf

patch_desktop_exec \
    "${applications_dir}/brave-origin-beta.desktop" \
    /usr/bin/brave-origin-beta \
    brave-origin-beta \
    /usr/bin/brave-browser-beta \
    /opt/brave.com/brave-beta/brave-browser-beta \
    /opt/brave.com/brave/brave-browser

patch_desktop_exec \
    "${applications_dir}/com.brave.Origin.beta.desktop" \
    /usr/bin/brave-origin-beta \
    brave-origin-beta \
    /usr/bin/brave-browser-beta \
    /opt/brave.com/brave-beta/brave-browser-beta \
    /opt/brave.com/brave/brave-browser

patch_desktop_exec \
    "${applications_dir}/helium.desktop" \
    /usr/bin/helium \
    helium \
    /opt/helium/helium

patch_desktop_exec \
    "${applications_dir}/mullvad-browser.desktop" \
    /usr/bin/mullvad-browser \
    /usr/lib/mullvad-browser/start-mullvad-browser \
    mullvad-browser

patch_shell_launcher /usr/bin/firefox /usr/lib64/firefox/firefox
install_command_wrapper /usr/bin/librewolf /usr/share/librewolf/librewolf
patch_shell_launcher /usr/lib/mullvad-browser/start-mullvad-browser /usr/lib/mullvad-browser/start-mullvad-browser
patch_shell_launcher /opt/brave.com/brave-origin-beta/brave-origin-beta /opt/brave.com/brave-origin-beta/brave-origin-beta
patch_shell_launcher /usr/lib/opt/brave.com/brave-origin-beta/brave-origin-beta /usr/lib/opt/brave.com/brave-origin-beta/brave-origin-beta
patch_shell_launcher /opt/helium/helium-wrapper /opt/helium/helium-wrapper
patch_shell_launcher /usr/lib/opt/helium/helium-wrapper /usr/lib/opt/helium/helium-wrapper
