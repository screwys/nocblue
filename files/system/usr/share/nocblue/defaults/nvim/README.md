# Neovim Setup

This config is LazyVim with a small local layer for this machine. It is meant to feel like a full editor immediately: file tree on the left, fuzzy file search, text search, tabs/buffers, diagnostics, completion, formatting, git signs, and a code outline.

## First Run

Open a project directory, then start Neovim:

```sh
cd ~/Projects/some-project
nvim
```

The first launch downloads plugins and language tools. When it finishes, run:

```vim
:LazyHealth
```

Quit with `:qa`.

## The Keys That Matter First

Neovim has modes. Press `i` to type text. Press `Esc` to go back to normal mode. Most commands below are used in normal mode.

| Key | Action |
| --- | --- |
| `Space` | Open the command menu for this config |
| `Space e` | Toggle the file tree |
| `Space E` | Focus the file tree |
| `Space f f` | Find files |
| `Space f g` | Search text in the project |
| `Space s r` | Find and replace in file or selected lines |
| `Space b b` | Pick an open buffer |
| `Tab` / `Shift Tab` | Next / previous open buffer |
| `Space t t` / `Ctrl /` | Toggle the bottom terminal |
| `Alt h` / `Alt l` | Scroll long lines left / right |
| `Alt Shift h` / `Alt Shift l` | Scroll long lines left / right faster |
| `Space u w` | Toggle line wrap |
| `Space w` | Save |
| `Space q` | Close the current window |
| `Space o` | Toggle code outline |
| `Space g g` | Open LazyGit when `lazygit` is installed |
| `Space g f` | Fetch Git remotes |
| `Space g c` | Commit staged changes |
| `Space g p` | Push |
| `Space g P` | Pull with fast-forward only |
| `g d` | Go to definition |
| `g r` | Find references |
| `K` | Show documentation under cursor |
| `Space c a` | Code action |
| `Space c r` | Rename symbol |
| `] d` / `[ d` | Next / previous diagnostic |
| `Ctrl h/j/k/l` | Move between windows |
| `Tab` / `Shift Tab` in visual mode | Indent / outdent selected lines |

## File Tree

The tree opens on the left by default. Toggle it with `Space e`. In the tree, use `Enter` to open a file. Common tree actions are shown by `?` while the tree is focused.

## Git

Use `Space g g` for the full LazyGit interface once `lazygit` is installed. Inside LazyGit, use `space` to stage files, `c` to commit, and `P` to push.

The direct fallback keys are `Space g f` for fetch, `Space g c` for commit, `Space g p` for push, and `Space g P` for pull. In Git repositories, the statusline also shows small clickable `fetch`, `commit`, and `push` actions when mouse support is available.

## Search

Use `Space f f` when you know the filename. Use `Space f g` when you remember text inside a file. Type a query, move with arrows or `Ctrl j/k`, and press `Enter`.

Use `Space s r` for find and replace. In normal mode it replaces in the whole file. If you select lines first with `V`, it replaces only inside the selected lines.

## Indent Lines

Use `V` to select full lines, then move with `j/k`. Press `Tab` to indent the selected lines to the right, or `Shift Tab` to move them left. The selection stays active so you can press it more than once.

## Buffers And Tabs

A buffer is an open file. Use `Space b b` to switch between open files. Use `:bd` to close the current buffer.

## Long Lines

Long lines wrap visually by default. Wrapped continuation lines start with `↳` and keep the original indent, so the file is easier to inspect without changing the actual text. Use `Space u w` to toggle wrapping off, or `Alt h/l` to pan left or right when wrap is off.

## Terminal

The integrated terminal opens automatically at the bottom of Neovim. Use `Space t t` or `Ctrl /` to toggle or focus it. Press `Esc` twice to leave terminal input mode, then use normal window keys like `Ctrl h/j/k/l`.

## Plugins And Updates

Use these commands inside Neovim:

```vim
:Lazy
:Mason
:checkhealth
```

`:Lazy` manages plugins. `:Mason` manages language servers and formatters. `:checkhealth` reports missing tools.

## Customizing Later

Local changes live in these files:

```text
~/.config/nvim/lua/config/options.lua
~/.config/nvim/lua/config/keymaps.lua
~/.config/nvim/lua/plugins/
```

Because `~/.config/nvim` is restored from this repo, edits there are repo changes.
