#!/usr/bin/env bash
# Claude Code — native installer (no node required). Installs to ~/.local/bin.

# Install (skipped in --config-only or when already present).
if [ "${CONFIG_ONLY:-0}" != "1" ] && ! has_cmd claude; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Agent context files (config/claude/). Claude Code reads CLAUDE.md (not
# AGENTS.md) from ~/.claude/ in every session, and ~/.claude/rules/*.md the
# same way — link into both. AGENTS.md keeps the cross-agent name as source of
# truth. Private overlay wins via config_dir (an overlay config/claude/ must
# ship every file linked here).
src="$(config_dir claude)"
if [ -f "$src/AGENTS.md" ]; then
  link "$src/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  ok "linked AGENTS.md -> ~/.claude/CLAUDE.md (loads in every claude session)"
fi
# Dev-workstation notes (WSL2, server-connect helpers) — only on the XPS dev
# box; servers skip them so agents there don't burn context on WSL advice.
if [ -f "$src/dev-machine.md" ]; then
  case "$(hostname | tr '[:upper:]' '[:lower:]')" in
    xps*)
      link "$src/dev-machine.md" "$HOME/.claude/rules/dev-machine.md"
      ok "linked dev-machine.md -> ~/.claude/rules/ (XPS dev workstation)"
      ;;
    *)
      ok "skipped dev-machine.md (host '$(hostname)' is not the dev workstation)"
      ;;
  esac
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
