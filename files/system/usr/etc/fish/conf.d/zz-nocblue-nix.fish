set -q NIX_REMOTE; or set -gx NIX_REMOTE local
if test -n "$HOME"; and not contains -- "$HOME/.nix-profile/bin" $PATH
    set -gx PATH $PATH "$HOME/.nix-profile/bin"
end
if test "$NOCBLUE_NIX_ENV" = 1
    set -e LD_PRELOAD LD_AUDIT
end
