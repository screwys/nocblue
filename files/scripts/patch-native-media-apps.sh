#!/usr/bin/env bash
set -euo pipefail

rewrite_desktop_entry() {
    local desktop_file="$1"
    local exec_line="$2"

    python3 - "${desktop_file}" "${exec_line}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
exec_line = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()

out = []
seen_exec = False
seen_dbus = False
for line in lines:
    if line.startswith("Exec="):
        out.append(exec_line)
        seen_exec = True
    elif line.startswith("DBusActivatable="):
        out.append("DBusActivatable=false")
        seen_dbus = True
    else:
        out.append(line)

if not seen_exec:
    out.append(exec_line)
if not seen_dbus:
    out.append("DBusActivatable=false")

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

install_media_launchers() {
    install -d /usr/share/applications /usr/share/dbus-1/services

    rewrite_desktop_entry \
        /usr/share/applications/org.gnome.Loupe.desktop \
        "Exec=/usr/bin/nocblue-bwrap-loupe %U"
    rewrite_desktop_entry \
        /usr/share/applications/org.gnome.Showtime.desktop \
        "Exec=/usr/bin/nocblue-bwrap-showtime %U"

    cat > /usr/share/dbus-1/services/org.gnome.Loupe.service <<'EOF'
[D-BUS Service]
Name=org.gnome.Loupe
Exec=/usr/bin/nocblue-bwrap-loupe --gapplication-service
EOF

    cat > /usr/share/dbus-1/services/org.gnome.Showtime.service <<'EOF'
[D-BUS Service]
Name=org.gnome.Showtime
Exec=/usr/bin/nocblue-bwrap-showtime --gapplication-service
EOF
}

patch_showtime() {
    local site_packages
    site_packages="$(python3 - <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.find_spec("showtime")
if spec is None or spec.origin is None:
    raise SystemExit("showtime module not found")
print(Path(spec.origin).parent.parent)
PY
)"

    set +e
    patch --forward -p1 -d "${site_packages}" <<'EOF'
--- a/showtime/main.py
+++ b/showtime/main.py
@@ -134,51 +134,57 @@
         self._create_action("new-window", lambda *_: self.activate(), ("<primary>n",))
         self._create_action("quit", lambda *_: self.quit(), ("<primary>q",))

     def do_activate(self, gfile: Gio.File | None = None) -> None:
-        """Create a new window, set up MPRIS."""
-        win = Window(
-            application=self,  # pyright: ignore[reportAttributeAccessIssue]
-            maximized=state_settings.get_boolean("is-maximized"),  # pyright: ignore[reportAttributeAccessIssue]
-        )
-        state_settings.bind("is-maximized", win, "maximized", Gio.SettingsBindFlags.SET)
-
-        win.connect(
-            "media-info-updated",
-            lambda win: (
-                self.emit("media-info-updated")
-                if win == self.props.active_window
-                else None
-            ),
-        )
-
-        win.connect(
-            "volume-changed",
-            lambda win: (
-                self.emit("volume-changed") if win == self.props.active_window else None
-            ),
-        )
-
-        win.connect(
-            "rate-changed",
-            lambda win: (
-                self.emit("rate-changed") if win == self.props.active_window else None
-            ),
-        )
-
-        win.connect(
-            "seeked",
-            lambda win: (
-                self.emit("seeked") if win == self.props.active_window else None
-            ),
-        )
-
-        win.connect(
-            "notify::paused",
-            lambda win, *_: (
-                self.emit("state-changed") if win == self.props.active_window else None
-            ),
+        """Reuse existing window or create a new one, set up MPRIS."""
+        win = next(
+            (w for w in self.get_windows() if isinstance(w, Window)),
+            None,
         )

+        if win is None:
+            win = Window(
+                application=self,  # pyright: ignore[reportAttributeAccessIssue]
+                maximized=state_settings.get_boolean("is-maximized"),  # pyright: ignore[reportAttributeAccessIssue]
+            )
+            state_settings.bind("is-maximized", win, "maximized", Gio.SettingsBindFlags.SET)
+
+            win.connect(
+                "media-info-updated",
+                lambda win: (
+                    self.emit("media-info-updated")
+                    if win == self.props.active_window
+                    else None
+                ),
+            )
+
+            win.connect(
+                "volume-changed",
+                lambda win: (
+                    self.emit("volume-changed") if win == self.props.active_window else None
+                ),
+            )
+
+            win.connect(
+                "rate-changed",
+                lambda win: (
+                    self.emit("rate-changed") if win == self.props.active_window else None
+                ),
+            )
+
+            win.connect(
+                "seeked",
+                lambda win: (
+                    self.emit("seeked") if win == self.props.active_window else None
+                ),
+            )
+
+            win.connect(
+                "notify::paused",
+                lambda win, *_: (
+                    self.emit("state-changed") if win == self.props.active_window else None
+                ),
+            )
+
         if gfile:
             win.play_video(gfile)

@@ -203,23 +209,13 @@
             MPRIS(self)

     def do_open(self, gfiles: Sequence[Gio.File], _n_files: int, _hint: str) -> None:  # pyright: ignore[reportIncompatibleMethodOverride]
-        """Open the given files."""
-        for gfile in gfiles:
-            self.do_activate(gfile)
+        """Open the given files in the existing window."""
+        if gfiles:
+            self.do_activate(gfiles[-1])

     def do_handle_local_options(self, options: GLib.VariantDict) -> int:
         """Handle local command line arguments."""
         self.register()  # This is so props.is_remote works
-        if self.props.is_remote:
-            if options.contains("new-window"):
-                return -1
-
-            logger.warning(
-                "Showtime is already running. "
-                "To open a new window, run the app with --new-window."
-            )
-            return 0
-
         return -1

    def _create_action(
EOF
    rc=$?
    set -e
    if [[ "${rc}" -ne 0 ]]; then
        if [[ "${rc}" -eq 1 ]] && grep -q 'Reuse existing window' "${site_packages}/showtime/main.py"; then
            return 0
        fi
        return "${rc}"
    fi

    rm -rf "${site_packages}/showtime/__pycache__"
    python3 -m py_compile "${site_packages}/showtime/main.py"
    install -D -m 0644 /dev/null /usr/share/nocblue/media-patches/showtime-reuse-window.patch-applied
}

rpm -q loupe showtime >/dev/null
patch_showtime
install_media_launchers
