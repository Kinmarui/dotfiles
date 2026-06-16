#!/usr/bin/env bash
# Claude Code — native installer (no node required). Installs to ~/.local/bin.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd claude && { ok "claude already installed ($(claude --version 2>/dev/null))"; return 0; }

curl -fsSL https://claude.ai/install.sh | bash

if ! has_cmd claude && [ -x "$HOME/.local/bin/claude" ]; then
  warn "claude installed to ~/.local/bin — ensure it is on your PATH:"
  warn '  export PATH="$HOME/.local/bin:$PATH"'
fi
