#!/usr/bin/env bash
# Shared helpers for the bootstrap installers.
# Sourced by bootstrap.sh and by every install/<app>.sh (in a subshell).

set -euo pipefail

# --- paths --------------------------------------------------------------------
# DOTFILES_ROOT is exported by bootstrap.sh; fall back to this file's parent.
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_SRC="$DOTFILES_ROOT/config"
# Optional private overlay (separate private repo). Layered on top when present.
PRIVATE_ROOT="${DOTFILES_PRIVATE:-$HOME/dotfiles-private}"

# --- logging ------------------------------------------------------------------
if [ -t 1 ]; then
  C_BLUE=$'\033[34m'; C_YEL=$'\033[33m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_RST=$'\033[0m'
else
  C_BLUE=; C_YEL=; C_RED=; C_GRN=; C_RST=
fi
log()  { printf '%s==>%s %s\n' "$C_BLUE" "$C_RST" "$*"; }
ok()   { printf '%s  +%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s  ! %s%s\n' "$C_YEL" "$*" "$C_RST" >&2; }
err()  { printf '%s  x %s%s\n' "$C_RED" "$*" "$C_RST" >&2; }

# --- predicates ---------------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# --- OS / arch detection ------------------------------------------------------
OS_ID=""; OS_VERSION_ID=""; OS_CODENAME=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"; OS_VERSION_ID="${VERSION_ID:-}"; OS_CODENAME="${VERSION_CODENAME:-}"
fi
ARCH="$(uname -m)"   # x86_64 | aarch64

is_ubuntu() { [ "$OS_ID" = "ubuntu" ]; }
# ubuntu_ge 24.04  -> true if running Ubuntu >= 24.04
ubuntu_ge() {
  [ "$OS_ID" = "ubuntu" ] || return 1
  [ "$(printf '%s\n%s\n' "$1" "$OS_VERSION_ID" | sort -V | head -1)" = "$1" ]
}
# Map uname arch to the {x86_64|arm64} naming most GitHub release assets use.
release_arch() {
  case "$ARCH" in
    x86_64) echo "x86_64" ;;
    aarch64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}
require_x86_64() { [ "$ARCH" = "x86_64" ] || { warn "skipping: only x86_64 is supported (have $ARCH)"; return 1; }; }

# --- package manager (apt | brew) ---------------------------------------------
PKG=""
if has_cmd apt-get; then PKG="apt"
elif has_cmd brew; then PKG="brew"
fi
APT_UPDATED=0
apt_update_once() { [ "$APT_UPDATED" = "1" ] && return 0; sudo apt-get update -y; APT_UPDATED=1; }
# pkg_install <pkg...> : install OS packages via the detected manager.
pkg_install() {
  case "$PKG" in
    apt)  apt_update_once; sudo apt-get install -y "$@" ;;
    brew) brew install "$@" ;;
    *)    err "no supported package manager (need apt or brew)"; return 1 ;;
  esac
}

# --- config layering ----------------------------------------------------------
# config_dir <app> : effective config source dir; private overlay wins.
config_dir() {
  local app="$1"
  if [ -d "$PRIVATE_ROOT/config/$app" ]; then echo "$PRIVATE_ROOT/config/$app"
  else echo "$CONFIG_SRC/$app"; fi
}

# --- filesystem helpers -------------------------------------------------------
# link <src> <dest> : symlink, backing up any pre-existing real file.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then rm -f "$dest"
  elif [ -e "$dest" ]; then mv "$dest" "$dest.bak.$$"; warn "backed up $dest -> $dest.bak.$$"; fi
  ln -s "$src" "$dest"
}
# render <src> <dest> : copy, expanding leading "~/ to "$HOME/ (for tools whose
# config values are NOT shell-expanded, e.g. zjstatus command_* paths).
render() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  sed "s#\"~/#\"$HOME/#g" "$src" > "$dest"
}
