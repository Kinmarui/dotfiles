#!/usr/bin/env bash
# Shell environment — aliases, functions, and runtime hooks (mise/zoxide/fzf)
# for the tools installed by the other apps. Adapted from omakub's
# defaults/bash/{aliases,functions,init}. Pure config: no binaries to install,
# so this runs the same in --config-only.

src="$(config_dir shell)"

# Symlink each config file into a stable location (private overlay wins via
# config_dir), so ~/.bashrc always sources the same path regardless of where
# this repo (or an overlay) is checked out.
dest="$HOME/.config/dotfiles/shell"
mkdir -p "$dest"
for f in "$src"/*; do
  [ -e "$f" ] || continue
  link "$f" "$dest/$(basename "$f")"
done

# Wire it into ~/.bashrc once.
line='[ -f "$HOME/.config/dotfiles/shell/rc" ] && source "$HOME/.config/dotfiles/shell/rc"'
if grep -qsF "$line" "$HOME/.bashrc" 2>/dev/null; then
  ok "~/.bashrc already sources dotfiles shell config"
else
  printf '\n# added by dotfiles bootstrap (shell aliases/functions/init)\n%s\n' "$line" >> "$HOME/.bashrc"
  ok "wired dotfiles shell config into ~/.bashrc"
fi

warn "open a new shell or run: source ~/.bashrc   (to pick up aliases now)"
ok "shell config linked ($dest)"
