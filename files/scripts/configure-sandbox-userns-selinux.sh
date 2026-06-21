#!/usr/bin/env bash
set -euo pipefail

NOCBLUE_SELINUX_SYNC_FORCE=1 \
    NOCBLUE_SELINUX_SYNC_NO_STAMP=1 \
    /usr/bin/nocblue-sync-sandbox-userns-selinux
