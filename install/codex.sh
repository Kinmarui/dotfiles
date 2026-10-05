#!/usr/bin/env bash
# Codex CLI (OpenAI) — installed as a mise global tool through the npm backend,
# so it does not depend on which node version is active and survives node
# upgrades. mise puts its bin dir on PATH (shell hook from install/shell.sh);
# in a shell without the hook use `mise exec -- codex`.
#
# Login is per host and not part of the dotfiles: `codex login --device-auth`
# (no browser needed on the host). Our shell alias (config/shell/aliases) keeps
# the login per project in "$PWD/.codex"; a plain `command codex` uses ~/.codex.
# Upgrade: mise upgrade npm:@openai/codex
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

has_cmd mise || { warn "mise not installed — run the mise installer first"; return 0; }

if mise ls --installed npm:@openai/codex 2>/dev/null | grep -q .; then
  ok "codex already installed ($(mise exec -- codex --version 2>/dev/null))"
else
  mise use -g npm:@openai/codex@latest
  ok "codex installed ($(mise exec -- codex --version 2>/dev/null))"
fi

# The per-project alias leaves a live OAuth token in <repo>/.codex/auth.json,
# and repos may track other .codex files (config.toml, hooks.json), so a plain
# `git add -A` would commit it. Ignore it globally, for every repo on the host.
excludes="$(git config --global core.excludesFile 2>/dev/null || true)"
excludes="${excludes:-$HOME/.config/git/ignore}"; excludes="${excludes/#\~/$HOME}"
mkdir -p "$(dirname "$excludes")"; touch "$excludes"
if grep -qxF '.codex/auth.json' "$excludes"; then
  ok "git global excludes already ignore .codex/auth.json"
else
  printf '\n# Codex CLI per-project login (CODEX_HOME alias) - never commit tokens\n.codex/auth.json\n' >> "$excludes"
  ok "added .codex/auth.json to git global excludes ($excludes)"
fi
