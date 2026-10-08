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

# --- upstream upgrades for stale distro packages ------------------------------
# Older targets package some of these years behind: Ubuntu 22.04 ships fzf 0.29,
# bat 0.19.0, fd 8.3.1 and zoxide 0.4.3. The floor for each tool is the oldest
# version any *supported* target ships (Debian 12, mostly), so a 22.04 box comes
# up to parity while Debian 12/13 and Ubuntu 24.04 keep their own packages —
# deliberately not a chase-the-latest upgrade. Upstream publishes .debs under the
# same package name, so apt replaces the distro build in place and no later
# `apt upgrade` downgrades it.
#
# zoxide's floor is the exception that is about a bug, not parity: 0.4.3 (Ubuntu
# 22.04 *and* Debian 12) emits `_z_cd() { cd "$@"; }`, which an `alias cd='z'`
# turns into recursion until the shell segfaults — see config/shell/init.
#
# upgrade_if_below_floor <cmd> <alt cmd|-> <floor> <owner/repo> <asset>
#   alt cmd: the distro's renamed binary (Ubuntu ships bat as batcat, fd as
#   fdfind) — checked for the current version when <cmd> itself is absent.
#   asset: release file name, @V = version, @A = dpkg architecture.
upgrade_if_below_floor() {
  local cmd="$1" alt="$2" floor="$3" repo="$4" asset="$5" cur tag ver
  cur="$(tool_version "$cmd" 2>/dev/null || true)"
  if [ -z "$cur" ] && [ "$alt" != "-" ]; then cur="$(tool_version "$alt" 2>/dev/null || true)"; fi
  if [ -n "$cur" ] && ver_ge "$floor" "$cur"; then
    ok "$cmd $cur — at or above the $floor floor, keeping the distro package"
    return 0
  fi
  tag="$(latest_tag "$repo")" || tag=""
  if [ -z "$tag" ]; then warn "could not resolve the latest $cmd release — keeping ${cur:-none}"; return 0; fi
  ver="${tag#v}"
  log "$cmd ${cur:-none} is below the $floor floor — installing upstream $ver"
  asset="${asset//@V/$ver}"; asset="${asset//@A/$(dpkg --print-architecture)}"
  if install_deb "https://github.com/$repo/releases/download/$tag/$asset"; then
    ok "$cmd ${cur:-none} -> $(tool_version "$cmd")"
    UPSTREAM_UPGRADED=1
  else
    warn "$cmd upgrade failed — keeping ${cur:-none}"
  fi
}

UPSTREAM_UPGRADED=0
upgrade_if_below_floor fzf    -      0.38.0 junegunn/fzf       'fzf_@V_@A.deb'
upgrade_if_below_floor bat    batcat 0.22.1 sharkdp/bat        'bat_@V_@A.deb'
upgrade_if_below_floor fd     fdfind 8.6.0  sharkdp/fd         'fd_@V_@A.deb'
upgrade_if_below_floor zoxide -      0.9.0  ajeetdsouza/zoxide 'zoxide_@V-1_@A.deb'
# Note: upstream's bat package is also called "bat" so it replaces the distro
# one (and provides `bat`, not `batcat`), but upstream's fd package is "fd"
# while Ubuntu's is "fd-find" — those coexist, leaving the old `fdfind` beside
# the new `fd`. Harmless: config/shell/aliases only aliases the names that are
# missing, and scripts here probe for both.

if [ "$UPSTREAM_UPGRADED" = "1" ]; then
  warn "open a new shell or run: source ~/.bashrc   (fzf/zoxide shell hooks are set up per shell)"
fi
