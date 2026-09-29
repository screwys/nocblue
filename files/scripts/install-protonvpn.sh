#!/usr/bin/env bash
set -euo pipefail

fedora_major="$(rpm -E %fedora)"
proton_release="protonvpn-beta-release-1.0.3-1.noarch.rpm"
curl -fsSLo "/tmp/${proton_release}" \
    "https://repo.protonvpn.com/fedora-${fedora_major}-unstable/protonvpn-beta-release/${proton_release}"

dnf -y install "/tmp/${proton_release}"

# The daemon package tries to start systemd services in scriptlets during image
# builds. Install it without scriptlets; the recipe enables the daemon unit.
dnf -y install \
    --disablerepo=terra \
    --disablerepo=terra-extras \
    --setopt=install_weak_deps=False \
    --setopt=tsflags=noscripts \
    proton-vpn-gnome-desktop

# The package currently ships two equivalent launchers. Keep the application ID
# used by Noctalia defaults and hide the duplicate from launchers.
rm -f /usr/share/applications/com.protonvpn.www.desktop

# The Fedora beta package ships a DBus activation file that points at
# proton.VPN.service, but the installed unit is named below.
sed -i \
    's/^SystemdService=proton\.VPN\.service$/SystemdService=me.proton.vpn.split_tunneling.service/' \
    /etc/dbus-1/system-services/me.proton.vpn.split_tunneling.service

python3 - <<'PY'
import glob
import os
import py_compile

daemon_dirs = glob.glob("/usr/lib/python3.*/site-packages/proton/vpn/daemon/split_tunneling/apps")
if not daemon_dirs:
    raise RuntimeError("Missing proton vpn daemon split tunneling package directory")
daemon_dir = daemon_dirs[0]

gtk_dirs = glob.glob("/usr/lib/python3.*/site-packages/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app")
if not gtk_dirs:
    raise RuntimeError("Missing proton vpn gtk app split tunneling package directory")
gtk_dir = gtk_dirs[0]

# 1. process_monitor.py: prevent unhandled UnicodeDecodeError from aborting perf event callback
pm_file = os.path.join(daemon_dir, "process_monitor.py")
content = open(pm_file, encoding="utf-8").read()
old_exec = """        if event.type == PerfBufferEventType.EXEC.value:
            # Once the exec syscall returns, the final exe path is built out of all the
            # previous EXEC_ARGV_FRAGMENT events containing the fragments that make it up.
            exe = b' '.join(self._argv[event.pid]).replace(b'\\n', b'\\\\n').decode('utf-8')
            try:
                del self._argv[event.pid]
            except KeyError:
                pass"""
new_exec = """        if event.type == PerfBufferEventType.EXEC.value:
            # Once the exec syscall returns, the final exe path is built out of all the
            # previous EXEC_ARGV_FRAGMENT events containing the fragments that make it up.
            try:
                raw_bytes = b' '.join(self._argv[event.pid]).replace(b'\\n', b'\\\\n')
                exe = raw_bytes.decode('utf-8', errors='replace')
            finally:
                self._argv.pop(event.pid, None)"""
if old_exec in content:
    content = content.replace(old_exec, new_exec)
    open(pm_file, "w", encoding="utf-8").write(content)
    py_compile.compile(pm_file, doraise=True)

# 2. socket_monitor.py: match both TGID (process ID) and TID (thread ID) in BPF socket filter
sm_file = os.path.join(daemon_dir, "socket_monitor.py")
content = open(sm_file, encoding="utf-8").read()
old_lookup = """    u32 pid = bpf_get_current_pid_tgid();

    u32 *pid_found = pid_map.lookup(&pid);"""
new_lookup = """    u64 pid_tgid = bpf_get_current_pid_tgid();
    u32 tgid = pid_tgid >> 32;
    u32 tid = (u32)pid_tgid;

    u32 *pid_found = pid_map.lookup(&tgid);
    if (!pid_found) {{
        pid_found = pid_map.lookup(&tid);
    }}"""
if old_lookup in content:
    content = content.replace(old_lookup, new_lookup)
    open(sm_file, "w", encoding="utf-8").write(content)
    py_compile.compile(sm_file, doraise=True)

# 3. process_map.py: snapshot process dict in __init__ to avoid dictionary modified during iteration
pmap_file = os.path.join(daemon_dir, "process_map.py")
content = open(pmap_file, encoding="utf-8").read()
old_init = """    def __init__(self, processes: dict[int, Process]):
        self.processes = processes"""
new_init = """    def __init__(self, processes: dict[int, Process]):
        self.processes = dict(processes)"""
if old_init in content:
    content = content.replace(old_init, new_init)
    open(pmap_file, "w", encoding="utf-8").write(content)
    py_compile.compile(pmap_file, doraise=True)

# 4. process_matcher.py: recognize Flatpak app IDs and resolve symlinks/scripts
pmatch_file = os.path.join(daemon_dir, "process_matcher.py")
content = open(pmatch_file, encoding="utf-8").read()
helpers = r'''import os
import re
import psutil

_FLATPAK_ID_RE = re.compile(r"^[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+){2,}$")


def _extract_flatpak_id(path: str):
    if not path:
        return None
    if "flatpak" in path:
        for token in path.split():
            token = token.strip("'\x22")
            if not token.startswith("-") and _FLATPAK_ID_RE.match(token):
                return token
    elif _FLATPAK_ID_RE.match(path):
        return path
    return None


def _get_process_flatpak_id(pid: int):
    try:
        with open(f"/proc/{pid}/cgroup", "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                if "app-flatpak-" in line:
                    part = line.split("app-flatpak-", 1)[1]
                    return part.split("-", 1)[0].split(".scope", 1)[0]
    except Exception:
        pass
    try:
        info_path = f"/proc/{pid}/root/.flatpak-info"
        if os.path.exists(info_path):
            with open(info_path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    if line.startswith("name="):
                        return line.split("=", 1)[1].strip()
    except Exception:
        pass
    try:
        with open(f"/proc/{pid}/environ", "rb") as f:
            for item in f.read().split(b"\0"):
                if item.startswith(b"FLATPAK_ID="):
                    return item.split(b"=", 1)[1].decode("utf-8", errors="replace")
    except Exception:
        pass
    return None
'''
if "import psutil" in content and "_extract_flatpak_id" not in content:
    content = content.replace("import psutil", helpers)

old_psutil = """        return Process(
            pid=process.pid, uid=uid, ppid=ppid, exe=exe
        )"""
new_psutil = """        try:
            cmd = " ".join(process.cmdline())
            if cmd:
                exe = f"{exe} {cmd}".strip() if exe else cmd
        except Exception:
            pass

        return Process(
            pid=process.pid, uid=uid, ppid=ppid, exe=exe
        )"""
if old_psutil in content:
    content = content.replace(old_psutil, new_psutil)

old_check = """        matches = set()
        for app_path in config.app_paths:
            if not app_path:
                continue
            if process.exe.startswith(app_path):
                matches.add(app_path)

        return matches"""
new_check = """        matches = set()
        proc_fid = _get_process_flatpak_id(process.pid)
        proc_real = None
        try:
            if process.exe:
                proc_real = os.path.realpath(process.exe.split()[0])
        except Exception:
            pass

        for app_path in config.app_paths:
            if not app_path:
                continue
            if process.exe.startswith(app_path):
                matches.add(app_path)
                continue

            app_fid = _extract_flatpak_id(app_path)
            if app_fid:
                if proc_fid == app_fid or ("flatpak" in process.exe and app_fid in process.exe):
                    matches.add(app_path)
                    continue

            try:
                app_first = app_path.split()[0]
                app_real = os.path.realpath(app_first)
                if app_real and (process.exe.startswith(app_real) or (proc_real and proc_real == app_real)):
                    matches.add(app_path)
                    continue
            except Exception:
                pass

        return matches"""
if old_check in content:
    content = content.replace(old_check, new_check)
    open(pmatch_file, "w", encoding="utf-8").write(content)
    py_compile.compile(pmatch_file, doraise=True)

# 5. installed_apps.py: parse target from env wrappers and detect flatpaks
ia_file = os.path.join(gtk_dir, "installed_apps.py")
content = open(ia_file, encoding="utf-8").read()

old_flatpak_check = """def _check_is_flatpak(app: Gio.AppInfo) -> bool:
    \"\"\"Check if executable is a flatpak. \"\"\"
    command_line = app.get_commandline()
    if command_line is None:
        return False
    return command_line.startswith("flatpak") or command_line.startswith("/usr/bin/flatpak")"""
new_flatpak_check = """def _check_is_flatpak(app: Gio.AppInfo) -> bool:
    \"\"\"Check if executable is a flatpak. \"\"\"
    command_line = app.get_commandline()
    if command_line is None:
        return False
    return "flatpak" in command_line"""
if old_flatpak_check in content:
    content = content.replace(old_flatpak_check, new_flatpak_check)

old_get_flatpak = """def _get_flatpak_executable(app: Gio.AppInfo) -> str:
    \"\"\"
    Returns the flatpak command line string trimming file forwarding
    specified with @@ ... @@. See FLATPAK_PATTERN regex.
    More info:
    https://unix.stackexchange.com/questions/797031/what-does-u-and-mean-in-the-a-desktop-entry
    https://docs.flatpak.org/en/latest/flatpak-command-reference.html
    \"\"\"
    command_line = app.get_commandline()
    result = FLATPAK_PATTERN.search(command_line)

    if not result:
        raise DesktopFileParsingError(
            "Could not parse flatpack executable string from: {command_line}"
        )

    return result.group(1).rstrip()"""
new_get_flatpak = """def _get_flatpak_executable(app: Gio.AppInfo) -> str:
    \"\"\"
    Returns the flatpak command line string trimming file forwarding
    specified with @@ ... @@. See FLATPAK_PATTERN regex.
    More info:
    https://unix.stackexchange.com/questions/797031/what-does-u-and-mean-in-the-a-desktop-entry
    https://docs.flatpak.org/en/latest/flatpak-command-reference.html
    \"\"\"
    command_line = app.get_commandline()
    if "flatpak" in command_line and not command_line.startswith("flatpak") and not command_line.startswith("/usr/bin/flatpak"):
        flatpak_idx = command_line.find("flatpak")
        command_line = command_line[flatpak_idx:]
    result = FLATPAK_PATTERN.search(command_line)

    if not result:
        raise DesktopFileParsingError(
            f"Could not parse flatpak executable string from: {command_line}"
        )

    return result.group(1).rstrip()"""
if old_get_flatpak in content:
    content = content.replace(old_get_flatpak, new_get_flatpak)

old_get_native = """def _get_native_app_executable(app: Gio.AppInfo):
    \"\"\"Gets the full exe path for a command (+args).\"\"\"
    executable = app.get_executable()

    if _check_is_command(executable):
        executable: Optional[str] = shutil.which(executable)

    if not executable:
        raise DesktopFileParsingError(
            "Could not get path from command: {command}"
        )

    return executable"""
new_get_native = """def _get_native_app_executable(app: Gio.AppInfo):
    \"\"\"Gets the full exe path for a command (+args).\"\"\"
    import shlex
    executable = app.get_executable()

    if _check_is_command(executable):
        executable: Optional[str] = shutil.which(executable)

    if executable in ("/usr/bin/env", "env"):
        cmdline = app.get_commandline()
        if cmdline:
            parts = shlex.split(cmdline)
            idx = 1
            while idx < len(parts):
                arg = parts[idx]
                if arg.startswith("-") or "=" in arg:
                    idx += 1
                else:
                    break
            if idx < len(parts):
                target = parts[idx]
                if "/" not in target:
                    executable = shutil.which(target) or target
                else:
                    executable = target

    if not executable:
        raise DesktopFileParsingError(
            f"Could not get path from command: {executable}"
        )

    return executable"""
if old_get_native in content:
    content = content.replace(old_get_native, new_get_native)
    open(ia_file, "w", encoding="utf-8").write(content)
    py_compile.compile(ia_file, doraise=True)
PY
