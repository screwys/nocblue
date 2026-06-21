# shellcheck shell=sh
if [ -x /usr/bin/nocblue-codex ]; then
    codex() {
        command /usr/bin/nocblue-codex "$@"
    }
fi
