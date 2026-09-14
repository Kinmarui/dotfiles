#!/usr/bin/env bash
# Core terminal CLI tools. Adapted from omakub install/terminal/apps-terminal.sh.
# Helpers (has_cmd, pkg_install, ubuntu_ge, ...) come from lib/common.sh.

[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

if [ "$PKG" = "brew" ]; then
  pkg_install fzf ripgrep bat eza zoxide fd jq ncdu
  return 0
fi

# apt path (Ubuntu 22.04 / 24.04)
# (plocate omitted: its daily updatedb walks the whole FS — little value on servers; use fd)
pkg_install fzf ripgrep bat zoxide apache2-utils fd-find jq unzip zip ncdu

# eza is packaged on Ubuntu 24.04+ and Debian 13 (trixie); older Ubuntu and
# Debian 12 (bookworm) lack it and need the maintainer's apt repo.
if ! has_cmd eza; then
  if ubuntu_ge 24.04 || debian_ge 13; then
    pkg_install eza
  else
    log "eza not in $OS_VERSION_ID repos — adding deb.gierens.de"
    $SUDO mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | $SUDO tee /etc/apt/sources.list.d/gierens.list >/dev/null
    $SUDO chmod 0644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    APT_UPDATED=0; pkg_install eza
  fi
fi

# zoxide: Ubuntu 22.04 ships 0.4.3 (2021), which is not just old — its shell
# init defines `_z_cd() { cd "$@"; }`, and an `alias cd='z'` that exists when
# that function is parsed expands inside it, so cd recurses until the shell
# dies of SIGSEGV (config/shell/init keeps the alias after the eval to prevent
# this). Modern zoxide emits `builtin cd` and jumps straight into an argument
# that is already a directory. Upgrade from the upstream .deb (same package
# name, so apt just replaces the distro one) when apt's is older than ZOXIDE_MIN.
ZOXIDE_MIN="${ZOXIDE_MIN:-0.9.0}"
zoxide_ver() { zoxide --version 2>/dev/null | awk '{print $2}' | sed 's/^v//; s/-.*//'; }
cur_zoxide="$(zoxide_ver)"
if [ -n "$cur_zoxide" ] && ! ver_ge "$ZOXIDE_MIN" "$cur_zoxide"; then
  log "zoxide $cur_zoxide is older than $ZOXIDE_MIN — installing the upstream release"
  zver="$(curl -fsSL https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep -Po '"tag_name": "v\K[^"]*')"
  zarch="$(dpkg --print-architecture)"   # amd64 | arm64
  cd /tmp
  curl -fsSLo zoxide.deb "https://github.com/ajeetdsouza/zoxide/releases/download/v${zver}/zoxide_${zver}-1_${zarch}.deb"
  $SUDO apt-get install -y ./zoxide.deb
  rm -f zoxide.deb
  cd - >/dev/null
  ok "zoxide upgraded $cur_zoxide -> $(zoxide_ver)"
  warn "open a new shell or run: source ~/.bashrc   (running shells keep the old zoxide init)"
fi
