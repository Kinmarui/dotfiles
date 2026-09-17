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

# --- privilege escalation -----------------------------------------------------
# Use $SUDO (never a bare `sudo`) for anything needing root: it is empty when we
# are already root — common on Debian minimal and in containers — and "sudo"
# otherwise. Debian's minimal install ships neither sudo nor a sudo group, so
# bootstrap.sh preflights the "non-root and no sudo" case with a clear message.
if [ "$(id -u)" = 0 ]; then SUDO=""
elif has_cmd sudo;   then SUDO="sudo"
else                      SUDO=""
fi

# --- OS / arch detection ------------------------------------------------------
OS_ID=""; OS_VERSION_ID=""; OS_CODENAME=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"; OS_VERSION_ID="${VERSION_ID:-}"; OS_CODENAME="${VERSION_CODENAME:-}"
fi
ARCH="$(uname -m)"   # x86_64 | aarch64

is_ubuntu() { [ "$OS_ID" = "ubuntu" ]; }
is_debian() { [ "$OS_ID" = "debian" ]; }
# ver_ge MIN HAVE -> true if HAVE >= MIN (version-sorted; ver_ge 24.04 22.04 -> false)
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }
# ubuntu_ge 24.04 -> true iff running Ubuntu >= 24.04; debian_ge 13 likewise.
ubuntu_ge() { [ "$OS_ID" = "ubuntu" ] || return 1; ver_ge "$1" "$OS_VERSION_ID"; }
debian_ge() { [ "$OS_ID" = "debian" ] || return 1; ver_ge "$1" "$OS_VERSION_ID"; }
# Map uname arch to the {x86_64|arm64} naming most GitHub release assets use.
release_arch() {
  case "$ARCH" in
    x86_64) echo "x86_64" ;;
    aarch64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}
require_x86_64() { [ "$ARCH" = "x86_64" ] || { warn "skipping: only x86_64 is supported (have $ARCH)"; return 1; }; }

# --- tool versions ------------------------------------------------------------
# tool_version <cmd> : first dotted version in `<cmd> --version`, or empty.
# Deliberately loose — every tool prints its own shape ("bat 0.19.0",
# "jq-1.6", "btop version: 1.2.3", "gh version 2.4.0+dfsg1", "NVIM v0.11.0-dev",
# lazygit's "commit=..., version=0.46.0, ...") and the first x.y[.z] in the
# output is the version in all of them.
tool_version() {
  has_cmd "$1" || return 1
  "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}
# outdated <cmd> <min> : true when <cmd> is missing, unreadable, or older than
# <min>. The counterpart to has_cmd: installers that only ask "is it here?"
# never upgrade the distro's 2022 build (see fzf 0.29 on Ubuntu 22.04).
outdated() {
  local cur; cur="$(tool_version "$1" 2>/dev/null || true)"
  [ -n "$cur" ] || return 0
  ! ver_ge "$2" "$cur"
}

# --- package manager (apt | brew) ---------------------------------------------
PKG=""
if has_cmd apt-get; then PKG="apt"
elif has_cmd brew; then PKG="brew"
fi
APT_UPDATED=0
apt_update_once() { [ "$APT_UPDATED" = "1" ] && return 0; $SUDO apt-get update -y; APT_UPDATED=1; }
# pkg_install <pkg...> : install OS packages via the detected manager.
pkg_install() {
  case "$PKG" in
    apt)  apt_update_once; $SUDO apt-get install -y "$@" ;;
    brew) brew install "$@" ;;
    *)    err "no supported package manager (need apt or brew)"; return 1 ;;
  esac
}

# --- upstream release fetching ------------------------------------------------
# Distro packages for these tools are often years behind (Ubuntu 22.04 ships fzf
# 0.29, bat 0.19, jq 1.6), so installers upgrade from upstream when `outdated`
# says so. Both helpers stage into a temp dir and clean up after themselves.
#
# latest_tag <owner/repo> : newest release tag, verbatim ("v0.74.4", "15.2.0",
# "jq-1.8.2"). Kept raw because it is half of the download URL; strip a leading
# "v" with ${tag#v} when you need the bare version.
latest_tag() {
  local repo="$1" tok="${GITHUB_TOKEN:-${GH_TOKEN:-}}" tag=""
  # Unauthenticated api.github.com allows 60 requests/hour per IP and a bootstrap
  # spends several, so use a token when one is lying around. Never insist on it:
  # a *stale* token is answered with 401 where anonymous would have worked (the
  # failure that broke the zellij build — mise sends gh's token and gives up), so
  # an authenticated attempt that fails falls back to an anonymous one.
  [ -z "$tok" ] && has_cmd gh && tok="$(gh auth token 2>/dev/null || true)"
  if [ -n "$tok" ]; then
    # stderr silenced: a failure here is not the user's problem, the anonymous
    # attempt below is, and its errors are shown.
    tag="$(curl -fsSL -H "Authorization: Bearer $tok" \
             "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
             | grep -Po '"tag_name": "\K[^"]*' || true)"
  fi
  [ -n "$tag" ] || tag="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
                            | grep -Po '"tag_name": "\K[^"]*' || true)"
  [ -n "$tag" ] || return 1
  printf '%s\n' "$tag"
}
# install_deb <url> : apt-install a .deb from a URL. apt (not dpkg) so that
# dependencies resolve; a .deb whose package name matches the distro's replaces
# it in place and will not be silently downgraded by a later apt upgrade.
install_deb() {
  local url="$1" tmp rc=0
  tmp="$(mktemp -d)"
  if curl -fsSLo "$tmp/pkg.deb" "$url"; then
    $SUDO apt-get install -y "$tmp/pkg.deb" || rc=1
  else
    err "download failed: $url"; rc=1
  fi
  rm -rf "$tmp"
  return "$rc"
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
