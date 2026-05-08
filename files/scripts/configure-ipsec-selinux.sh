#!/usr/bin/env bash
set -euo pipefail

semodule -X 300 -i /usr/share/nocblue/selinux/ipsec/deny_ipsec.cil
