#!/usr/bin/env bash
# Core terminal CLI tools. Adapted from omakub install/terminal/apps-terminal.sh.
# Helpers (has_cmd, pkg_install, ubuntu_ge, ...) come from lib/common.sh.

[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

if [ "$PKG" = "brew" ]; then
  pkg_install fzf ripgrep bat eza zoxide fd jq ncdu
  return 0
fi

# apt path (Ubuntu 22.04 / 24.04)
pkg_install fzf ripgrep bat zoxide plocate apache2-utils fd-find jq unzip zip ncdu

# eza is only packaged from Ubuntu 24.04 onward; older releases need the
# maintainer's apt repo.
if ! has_cmd eza; then
  if ubuntu_ge 24.04; then
    pkg_install eza
  else
    log "eza not in $OS_VERSION_ID repos — adding deb.gierens.de"
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 0644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    APT_UPDATED=0; pkg_install eza
  fi
fi
