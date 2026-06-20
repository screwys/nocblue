#!/usr/bin/env bash
set -euo pipefail

NOCBLUE_SELINUX_SYNC_NO_STAMP=1 /usr/bin/nocblue-sync-browser-userns-selinux
