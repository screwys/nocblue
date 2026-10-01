#!/usr/bin/sh

if [ "${NIX_REMOTE+x}" != x ]; then
    export NIX_REMOTE=local
fi

if [ -n "${HOME:-}" ]; then
    case ":${PATH:-}:" in
        *":${HOME}/.nix-profile/bin:"*) ;;
        *) export PATH="${PATH:+${PATH}:}${HOME}/.nix-profile/bin" ;;
    esac
fi
