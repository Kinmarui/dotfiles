#!/usr/bin/env bash
# GitHub CLI (gh). Adapted from omakub install/terminal/app-github-cli.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd gh && { ok "gh already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install gh; return 0; fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  [ -f /usr/share/keyrings/githubcli-archive-keyring.gpg ] && sudo rm /usr/share/keyrings/githubcli-archive-keyring.gpg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi
APT_UPDATED=0; pkg_install gh
