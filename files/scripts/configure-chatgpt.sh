#!/usr/bin/env bash
set -euo pipefail

wrapper=/usr/libexec/nocblue/chatgpt
vendor_launcher=/usr/lib/chatgpt/codex-launcher

if [[ ! -x "${wrapper}" ]]; then
    printf 'missing nocblue ChatGPT wrapper: %s\n' "${wrapper}" >&2
    exit 1
fi
if [[ ! -x "${vendor_launcher}" ]]; then
    printf 'missing official ChatGPT launcher: %s\n' "${vendor_launcher}" >&2
    exit 1
fi

rm -f /usr/bin/chatgpt
ln -s ../libexec/nocblue/chatgpt /usr/bin/chatgpt
