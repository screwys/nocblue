#!/usr/bin/env python3
"""Check the image's secret service using an encrypted, synthetic keyring."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


PASSWORD = "nocblue-test-password"
SECRET = "synthetic-secret"
# Also allow checking downloaded Fedora RPMs without installing them.
OO7 = Path(os.environ.get("TEST_OO7_DAEMON", "/usr/libexec/oo7-daemon"))


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, timeout=15, **kwargs)


def check_session():
    daemon = None
    try:
        if OO7.exists():
            daemon = subprocess.Popen([str(OO7), "--login"], stdin=subprocess.PIPE, text=True)
            daemon.stdin.write(PASSWORD)
            daemon.stdin.close()
        else:
            run("gnome-keyring-daemon", "--login", "--daemonize", input=PASSWORD)
            run("gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                "--object-path", "/org/freedesktop/DBus",
                "--method", "org.freedesktop.DBus.StartServiceByName",
                "org.freedesktop.secrets", "0")

        # The first request must work as soon as the daemon owns the bus name.
        run("gdbus", "wait", "--session", "--timeout=10", "org.freedesktop.secrets")
        old = run("secret-tool", "lookup", "nocblue-test", "migration", capture_output=True)
        assert old.stdout.strip() == SECRET, "The existing secret is unreadable"
        run("secret-tool", "store", "--label=Image keyring test",
            "nocblue-test", "new", input="new-synthetic-secret")
        new = run("secret-tool", "lookup", "nocblue-test", "new", capture_output=True)
        assert new.stdout.strip() == "new-synthetic-secret", "The new secret is unreadable"
    finally:
        if daemon is not None:
            daemon.terminate()
            daemon.wait(timeout=5)


def main():
    fixture = Path(__file__).resolve().parent.parent / "fixtures/keyring/login.keyring"
    with tempfile.TemporaryDirectory(prefix="secret-service-test-") as directory:
        home = Path(directory)
        for name in ("config", "data/keyrings", "cache", "state", "runtime"):
            (home / name).mkdir(parents=True, mode=0o700)
        original = home / "data/keyrings/login.keyring"
        shutil.copyfile(fixture, original)
        original.chmod(0o600)
        before = original.read_bytes()
        env = os.environ.copy()
        for name in ("DBUS_SESSION_BUS_ADDRESS", "DBUS_STARTER_ADDRESS", "DBUS_STARTER_BUS_TYPE",
                     "GNOME_KEYRING_CONTROL", "DISPLAY", "WAYLAND_DISPLAY", "XDG_SESSION_ID"):
            env.pop(name, None)
        env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
                   XDG_DATA_HOME=str(home / "data"), XDG_CACHE_HOME=str(home / "cache"),
                   XDG_STATE_HOME=str(home / "state"), XDG_RUNTIME_DIR=str(home / "runtime"),
                   OO7_PAM_SOCKET=str(home / "runtime/oo7-pam.sock"))
        try:
            subprocess.run(["dbus-run-session", "--", sys.executable, __file__, "--session"],
                           env=env, check=True, timeout=45)
        finally:
            if OO7.exists():
                assert original.read_bytes() == before, "Migration changed the original keyring"
                print("The original keyring is unchanged")
        if OO7.exists():
            assert (home / "data/keyrings/v1/login.keyring").is_file()
            print("oo7 migrated the existing secret")
        print("Existing and new secrets are readable")


if __name__ == "__main__":
    if sys.argv[1:] == ["--session"]:
        check_session()
    else:
        main()
