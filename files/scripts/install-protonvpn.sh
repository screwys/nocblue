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

# Prepare process tracking before login and queue events before scanning apps.
# Flatpak selections use metadata identity independently of launcher arguments.
# Invalid bytes in exec arguments must not abort the process event callback.
site_packages="$(python3 -c 'from importlib.metadata import distribution; print(distribution("proton-vpn-daemon").locate_file(""))')"
patch --batch --fuzz=0 -p1 -d "${site_packages}" <<'PATCH'
--- a/proton/vpn/daemon/split_tunneling/apps/process_matcher.py
+++ b/proton/vpn/daemon/split_tunneling/apps/process_matcher.py
@@ -18,6 +18,7 @@
 """

 from dataclasses import dataclass, field
+from configparser import ConfigParser, Error as ConfigError
 import time

 import psutil
@@ -89,6 +90,17 @@
             return set([cls.VPN_APP_BIN])

         matches = set()
+        # Flatpak supplies this identity independently of the desktop launcher.
+        if any(path.startswith("flatpak:") for path in config.app_paths):
+            info = ConfigParser(interpolation=None)
+            try:
+                info.read(f"/proc/{process.pid}/root/.flatpak-info", encoding="utf-8")
+                app_id = info.get("Application", "name", fallback="")
+            except (OSError, ConfigError, UnicodeError):
+                app_id = ""
+            if app_id and f"flatpak:{app_id}" in config.app_paths:
+                matches.add(f"flatpak:{app_id}")
+
         for app_path in config.app_paths:
             if not app_path:
                 continue
--- a/proton/vpn/daemon/split_tunneling/apps/process_monitor.py
+++ b/proton/vpn/daemon/split_tunneling/apps/process_monitor.py
@@ -99,11 +99,11 @@
         if not self._background_task:
             logger.info("Starting process monitor")

+            # Queue events before scanning, so launches cannot fall between the two.
+            self._attach_bpf()
             self._tracked_procs = self._process_matcher.check_all_processes(config_by_uid)
             for process in self._tracked_procs.values():
                 self._process_event_callback(process, config_by_uid[process.uid].mode)
-
-            self._attach_bpf()

             # start listening for process events via ebpf
             self._background_task = asyncio.create_task(
@@ -144,7 +144,8 @@
         self.__init__(process_event_callback=callback)  # pylint: disable=C2801
         logger.info("Process monitor stopped")

-    def _attach_bpf(self):
+    def prepare(self):
+        """Compile the process probes before the login connection starts."""
         if not self._bpf:
             with open(BPF_PROGRAM_PATH, "r", encoding="utf-8") as file:
                 bpf_text = file.read()
@@ -158,6 +159,11 @@
                     ) from exc
                 raise

+    def _attach_bpf(self):
+        self.prepare()
+        # Subscribe before attaching exec probes or scanning existing processes.
+        self._bpf["events"].open_perf_buffer(self._process_perf_buffer_event, page_cnt=256)
+
         # Explicitly attach kprobes/kretprobes,
         # tracepoints using TRACEPOINT_PROBE are automatically attached when
         # the BPF object is created
@@ -182,7 +188,6 @@
         )

     def _run_blocking_process_monitoring(self):
-        self._bpf["events"].open_perf_buffer(self._process_perf_buffer_event)
         while not self._stop_requested:
             self._bpf.perf_buffer_poll(timeout=30)  # timeout in ms

@@ -200,7 +205,7 @@
         if event.type == PerfBufferEventType.EXEC.value:
             # Once the exec syscall returns, the final exe path is built out of all the
             # previous EXEC_ARGV_FRAGMENT events containing the fragments that make it up.
-            exe = b' '.join(self._argv[event.pid]).replace(b'\n', b'\\n').decode('utf-8')
+            exe = b' '.join(self._argv[event.pid]).replace(b'\n', b'\\n').decode('utf-8', errors='replace')
             try:
                 del self._argv[event.pid]
             except KeyError:
--- a/proton/vpn/daemon/split_tunneling/apps/socket_monitor.py
+++ b/proton/vpn/daemon/split_tunneling/apps/socket_monitor.py
@@ -17,6 +17,7 @@
 along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
 """
 import ctypes
+import errno
 import os

 from bcc import BPF
@@ -32,7 +33,7 @@
 BPF_HASH(pid_map, u32, u32);

 int split_tunnel(struct bpf_sock *sk) {{
-    u32 pid = bpf_get_current_pid_tgid();
+    u32 pid = bpf_get_current_pid_tgid() >> 32;

     u32 *pid_found = pid_map.lookup(&pid);

@@ -111,7 +112,24 @@
             raise RuntimeError("Socket monitor was not started yet")

         logger.debug("Adding %s to pid map", pid)
-        self._bpf_pid_map[ctypes.c_uint32(pid)] = ctypes.c_uint32(1)
+        try:
+            self._bpf_pid_map[ctypes.c_uint32(pid)] = ctypes.c_uint32(1)
+        except Exception:
+            # BCC raises a plain Exception for a full kernel hash map.
+            if ctypes.get_errno() != errno.E2BIG:
+                raise
+            self._remove_exited_processes()
+            self._bpf_pid_map[ctypes.c_uint32(pid)] = ctypes.c_uint32(1)
+
+    def _remove_exited_processes(self):
+        # Lost exit events can leave dead task IDs occupying the map.
+        removed = 0
+        for key in list(self._bpf_pid_map.keys()):
+            if not os.path.exists(f"/proc/{key.value}"):
+                del self._bpf_pid_map[key]
+                removed += 1
+        logger.warning("Removed %d exited tasks from the split tunneling map", removed)
+        return removed

     def stop_tracking_process(self, pid: int):  # pylint: disable=redefined-outer-name
         """
--- a/proton/vpn/daemon/split_tunneling/apps/process_map.py
+++ b/proton/vpn/daemon/split_tunneling/apps/process_map.py
@@ -35,7 +35,7 @@
     """Utility class to dump tracked processes to disk for debugging purposes."""

     def __init__(self, processes: dict[int, Process]):
-        self.processes = processes
+        self.processes = dict(processes)

     def dump(self) -> str:
         """
--- a/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/installed_apps.py
+++ b/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/installed_apps.py
@@ -65,6 +65,9 @@
     https://docs.flatpak.org/en/latest/flatpak-command-reference.html
     """
     command_line = app.get_commandline()
+    flatpak = re.search(r"(?:^|\s)(?:/usr/bin/)?flatpak(?=\s)", command_line)
+    if flatpak:
+        command_line = "/usr/bin/flatpak" + command_line[flatpak.end():]
     result = FLATPAK_PATTERN.search(command_line)

     if not result:
@@ -141,6 +144,13 @@
     """
     Returns the executable to split tunnel, transformed if necessary.
     """
+
+    if isinstance(app, Gio.DesktopAppInfo):
+        app_id = app.get_string("X-Flatpak")
+        if app_id and app.get_id() == f"{app_id}.desktop":
+            return f"flatpak:{app_id}"
+        if app_id and re.search(r"(?:^|\s)(?:/usr/bin/)?flatpak(?=\s)", app.get_commandline() or ""):
+            return _get_flatpak_executable(app)

     if _check_is_flatpak(app):
         executable = _get_flatpak_executable(app)
@@ -150,6 +160,24 @@
         executable = _get_native_app_executable(app)

     return executable
+
+
+def normalize_flatpak_paths(paths: list[str]) -> list[str]:
+    """Keep existing app selections when switching to Flatpak identities."""
+    replacements = {}
+    for app in Gio.AppInfo.get_all():
+        if not isinstance(app, Gio.DesktopAppInfo):
+            continue
+        app_id = app.get_string("X-Flatpak")
+        command = app.get_commandline()
+        if not app_id or not command:
+            continue
+        raw_command = FLATPAK_PATTERN.search(command).group(1).rstrip()
+        normalized_command = _get_flatpak_executable(app)
+        app_path = get_app_executable(app)
+        for old_path in (raw_command, normalized_command, normalized_command.removeprefix("/usr/bin/")):
+            replacements[old_path] = app_path
+    return [replacements.get(path, path) for path in paths]


 def get_all_installed_apps() -> list[AppData]:
--- a/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/settings.py
+++ b/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/settings.py
@@ -35,7 +35,7 @@
 from proton.vpn.app.gtk.widgets.headerbar.menu.settings.split_tunneling.app.data_structures \
     import AppData
 from proton.vpn.app.gtk.widgets.headerbar.menu.settings.split_tunneling.app.installed_apps \
-    import get_all_installed_apps
+    import get_all_installed_apps, normalize_flatpak_paths


 LABEL_CONVERSION = {
@@ -192,7 +192,11 @@
         ]

     def _get_settings(self) -> list[str]:
-        return cast(list[str], self._controller.get_setting_attr(self._setting_path_name))
+        paths = cast(list[str], self._controller.get_setting_attr(self._setting_path_name))
+        normalized = normalize_flatpak_paths(paths)
+        if normalized != paths:
+            self._controller.save_setting_attr(self._setting_path_name, normalized)
+        return normalized

     def _save_settings(self):
         self._controller.save_setting_attr(self._setting_path_name, self._stored_apps)
--- a/proton/vpn/daemon/split_tunneling/apps/service.py
+++ b/proton/vpn/daemon/split_tunneling/apps/service.py
@@ -36,6 +36,7 @@
     def __init__(self):
         self._process_monitor = ProcessMonitor(self._on_process_event)
         self._socket_monitor = SocketMonitor()
+        self._process_monitor.prepare()

     def _on_process_event(self, process: Process, mode: SplitTunnelingMode):
         if process.matched_config_paths:
@@ -71,6 +72,8 @@
             await self._process_monitor.stop()
         finally:
             self._socket_monitor.stop()
+            # Prepare the next connection while the VPN is disconnected.
+            self._process_monitor.prepare()


 async def main():
PATCH
python3 -m py_compile \
    "${site_packages}/proton/vpn/daemon/split_tunneling/apps/process_matcher.py" \
    "${site_packages}/proton/vpn/daemon/split_tunneling/apps/process_monitor.py" \
    "${site_packages}/proton/vpn/daemon/split_tunneling/apps/service.py" \
    "${site_packages}/proton/vpn/daemon/split_tunneling/apps/socket_monitor.py" \
    "${site_packages}/proton/vpn/daemon/split_tunneling/apps/process_map.py" \
    "${site_packages}/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/installed_apps.py" \
    "${site_packages}/proton/vpn/app/gtk/widgets/headerbar/menu/settings/split_tunneling/app/settings.py"
