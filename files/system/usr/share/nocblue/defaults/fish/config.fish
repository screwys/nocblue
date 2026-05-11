set -g fish_greeting

set -q EDITOR; or set -gx EDITOR nvim
set -q VISUAL; or set -gx VISUAL nvim
set -q TERMINAL; or set -gx TERMINAL /usr/bin/ghostty

if test -d /home/linuxbrew/.linuxbrew/bin
    fish_add_path /home/linuxbrew/.linuxbrew/bin
end
