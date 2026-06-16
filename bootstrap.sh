#!/usr/bin/env bash
#
# bootstrap.sh — install + configure a machine from this repo.
#
#   git clone <this repo> ~/dotfiles && ~/dotfiles/bootstrap.sh
#
# Selects apps from manifest.conf (or from CLI args), then runs each
# install/<app>.sh. A private overlay repo (default ~/dotfiles-private, or
# $DOTFILES_PRIVATE) is layered on top: its install/<app>.sh and config/<app>
# take precedence over this repo's.
#
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT
# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

usage() {
  cat <<EOF
Usage: bootstrap.sh [options] [app ...]

  (no app)         install everything enabled in manifest.conf
  app ...          install only the named apps (overrides the manifest)

Options:
  --config-only    re-apply configuration only; skip binary installation
  --list           list available installers (public + overlay) and exit
  -h, --help       show this help

Env:
  DOTFILES_PRIVATE path to the private overlay repo (default: ~/dotfiles-private)
EOF
}

CONFIG_ONLY=0
DO_LIST=0
SELECTED=()
while [ $# -gt 0 ]; do
  case "$1" in
    --config-only) CONFIG_ONLY=1 ;;
    --list) DO_LIST=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) err "unknown option: $1"; usage; exit 1 ;;
    *) SELECTED+=("$1") ;;
  esac
  shift
done
export CONFIG_ONLY

installer_for() { # echo path to an app's installer (overlay wins), or nothing
  local app="$1"
  if [ -f "$PRIVATE_ROOT/install/$app.sh" ]; then echo "$PRIVATE_ROOT/install/$app.sh"
  elif [ -f "$DOTFILES_ROOT/install/$app.sh" ]; then echo "$DOTFILES_ROOT/install/$app.sh"; fi
}

if [ "$DO_LIST" = "1" ]; then
  log "available installers:"
  { ls "$DOTFILES_ROOT/install/" 2>/dev/null; [ -d "$PRIVATE_ROOT/install" ] && ls "$PRIVATE_ROOT/install/" 2>/dev/null; } \
    | sed -n 's/\.sh$//p' | sort -u | sed 's/^/  /'
  exit 0
fi

# --- environment sanity -------------------------------------------------------
if is_ubuntu; then
  if ! ubuntu_ge 22.04; then warn "Ubuntu $OS_VERSION_ID is older than 22.04 and untested"; fi
else
  warn "this repo targets Ubuntu 22.04/24.04; detected '${OS_ID:-unknown} ${OS_VERSION_ID:-}' — apt paths may not apply"
fi
[ -n "$PKG" ] || warn "no apt/brew detected; package installs will fail"
if [ -d "$PRIVATE_ROOT" ]; then log "private overlay: $PRIVATE_ROOT"; else log "no private overlay at $PRIVATE_ROOT (public-only run)"; fi

# --- resolve app list ---------------------------------------------------------
if [ ${#SELECTED[@]} -eq 0 ]; then
  manifest="$DOTFILES_ROOT/manifest.conf"
  [ -r "$manifest" ] || { err "no manifest.conf and no apps given"; exit 1; }
  # overlay manifest, if present, is appended
  for m in "$manifest" "$PRIVATE_ROOT/manifest.conf"; do
    [ -r "$m" ] || continue
    while IFS= read -r line; do
      line="${line%%#*}"                      # strip comments
      line="$(echo "$line" | tr -d '[:space:]')"
      [ -n "$line" ] && SELECTED+=("$line")
    done < "$m"
  done
fi
[ ${#SELECTED[@]} -gt 0 ] || { err "nothing selected"; exit 1; }

# --- run ----------------------------------------------------------------------
log "plan: ${SELECTED[*]}"
[ "$CONFIG_ONLY" = "1" ] && log "(config-only mode)"

failed=()
for app in "${SELECTED[@]}"; do
  script="$(installer_for "$app")"
  if [ -z "$script" ]; then err "no installer for '$app' — skipping"; failed+=("$app"); continue; fi
  log "[$app]"
  # Subshell isolates each installer's cd/traps; failure is contained.
  if ( source "$script" ); then ok "[$app] done"; else err "[$app] failed"; failed+=("$app"); fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  ok "bootstrap complete: ${SELECTED[*]}"
else
  warn "completed with failures: ${failed[*]}"
  exit 1
fi
