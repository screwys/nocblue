#!/usr/bin/sh

# Nix store binaries cannot load secureblue's host allocator libraries.
# Fedora's /etc/bashrc sources profile.d again in Nix-descended Bash shells.
if [ "${NOCBLUE_NIX_PORTABLE:-}" = "1" ]; then
    unset LD_PRELOAD LD_AUDIT
fi
