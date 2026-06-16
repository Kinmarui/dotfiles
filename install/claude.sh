#!/usr/bin/env bash
# Claude Code — native installer (no node required). Installs to ~/.local/bin.

# Install (skipped in --config-only or when already present).
if [ "${CONFIG_ONLY:-0}" != "1" ] && ! has_cmd claude; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

bindir="$HOME/.local/bin"
[ -x "$bindir/claude" ] || { warn "claude not found at $bindir after install"; return 0; }
ok "claude installed ($("$bindir/claude" --version 2>/dev/null))"

# Ensure ~/.local/bin is on PATH for future shells.
case ":$PATH:" in
  *":$bindir:"*)
    ok "~/.local/bin already on PATH"
    ;;
  *)
    line='export PATH="$HOME/.local/bin:$PATH"'
    if grep -qsF "$line" "$HOME/.bashrc"; then
      ok "PATH line already present in ~/.bashrc"
    else
      printf '\n# added by dotfiles bootstrap (claude / ~/.local/bin)\n%s\n' "$line" >> "$HOME/.bashrc"
      ok "added ~/.local/bin to PATH in ~/.bashrc"
    fi
    warn "open a new shell or run: source ~/.bashrc   (to pick up claude now)"
    warn "if your login shell is zsh/fish, add ~/.local/bin to its rc instead"
    ;;
esac
