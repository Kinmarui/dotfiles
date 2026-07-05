#!/usr/bin/env bash
# zellij — terminal multiplexer, pinned, with our custom config + zjstatus bar.
#
# Versions are pinned (override via env): zellij ships session/plugin format
# changes between versions, so we bump deliberately. zjstatus 0.23.x targets
# zellij 0.44.x.
ZELLIJ_VERSION="${ZELLIJ_VERSION:-0.44.3}"
ZJSTATUS_VERSION="${ZJSTATUS_VERSION:-0.23.0}"
# ZELLIJ_GLIBC: auto|1|0. The official Linux release is musl-static, and Rust's
# std cannot read a file's btime on musl — which silently breaks zellij session
# *resurrection* ("Failed to read created stamp of resurrection file" in the log,
# sessions drop to EXITED). A glibc build fixes it. 'auto' (default) builds glibc
# from source when running inside a container (LXC/Docker) — where this bites —
# and downloads the fast musl release otherwise. Force with ZELLIJ_GLIBC=1 / 0.
ZELLIJ_GLIBC="${ZELLIJ_GLIBC:-auto}"

ZJ_DIR="$HOME/.config/zellij"
src="$(config_dir zellij)"

# --- binary -------------------------------------------------------------------
# is_container: true inside LXC / Docker / podman / systemd-nspawn.
is_container() {
  if has_cmd systemd-detect-virt; then systemd-detect-virt --container --quiet && return 0; fi
  { [ -f /run/.containerenv ] || [ -f /.dockerenv ]; } && return 0
  grep -qaE 'container=(lxc|docker|podman)' /proc/1/environ 2>/dev/null
}
zellij_ver()      { zellij --version 2>/dev/null | awk '{print $2}'; }
zellij_is_glibc() { ldd "$(command -v zellij 2>/dev/null)" 2>/dev/null | grep -q 'libc\.so\.6'; }

# Download the official musl-static release (fast; note: btime/resurrection off).
zellij_install_musl() {
  local ver="$1"
  log "installing zellij $ver (musl release, have: $(zellij_ver 2>/dev/null || echo none))"
  cd /tmp
  curl -fsSLo zellij.tar.gz \
    "https://github.com/zellij-org/zellij/releases/download/v${ver}/zellij-${ARCH}-unknown-linux-musl.tar.gz"
  tar -xf zellij.tar.gz zellij
  sudo install zellij /usr/local/bin/zellij
  rm -f zellij.tar.gz zellij
  cd - >/dev/null
  ok "installed musl zellij $(zellij_ver)"
}

# Build a glibc-linked zellij from crates.io (fixes musl btime/resurrection).
# Pinned + --locked for reproducibility; builds to a temp root, then installs.
zellij_build_glibc() {
  local ver="$1" root
  local -a CARGO
  if   has_cmd cargo; then CARGO=(cargo)
  elif has_cmd mise;  then CARGO=(mise exec rust@latest -- cargo)
  else err "need cargo or mise to build glibc zellij (enable 'mise' in manifest.conf)"; return 1; fi
  # vendored openssl+curl (default features) need a C toolchain + perl (+cmake).
  [ "$PKG" = "apt" ] && pkg_install build-essential pkg-config cmake perl
  log "building zellij $ver from source (glibc — fixes session resurrection); this takes a while"
  root="$(mktemp -d)"
  "${CARGO[@]}" install --locked --version "$ver" --root "$root" zellij
  sudo install "$root/bin/zellij" /usr/local/bin/zellij
  rm -rf "$root"
  hash -r
  zellij_is_glibc \
    && ok "installed glibc zellij $(zellij_ver) -> /usr/local/bin/zellij" \
    || { err "built binary is not glibc-linked"; return 1; }
}

if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  want_glibc=0
  case "$ZELLIJ_GLIBC" in
    1|yes|true)  want_glibc=1 ;;
    0|no|false)  want_glibc=0 ;;
    *)           is_container && want_glibc=1 ;;   # auto
  esac
  cur="$(zellij_ver 2>/dev/null || true)"

  if [ "$want_glibc" = "1" ]; then
    if [ "$cur" = "$ZELLIJ_VERSION" ] && zellij_is_glibc; then
      ok "zellij $ZELLIJ_VERSION already installed (glibc)"
    else
      zellij_build_glibc "$ZELLIJ_VERSION"
    fi
  else
    if [ "$cur" = "$ZELLIJ_VERSION" ] && ! zellij_is_glibc; then
      ok "zellij $ZELLIJ_VERSION already installed (musl)"
    else
      zellij_install_musl "$ZELLIJ_VERSION"
    fi
  fi
fi

# --- config -------------------------------------------------------------------
mkdir -p "$ZJ_DIR/themes" "$ZJ_DIR/layouts" "$ZJ_DIR/plugins"

# config.kdl: symlinked (live-editable).
[ -f "$src/config.kdl" ] && link "$src/config.kdl" "$ZJ_DIR/config.kdl"

# themes: link FILES (not the dir) so omakub's own theme files can coexist in
# the same real directory instead of clobbering a symlinked dir.
if [ -d "$src/themes" ]; then
  for t in "$src"/themes/*.kdl; do [ -e "$t" ] && link "$t" "$ZJ_DIR/themes/$(basename "$t")"; done
fi

# layouts: RENDERED (copied) because zjstatus command_* paths are not shell-
# expanded — render() rewrites leading ~/ to $HOME/.
if [ -d "$src/layouts" ]; then
  for l in "$src"/layouts/*.kdl; do [ -e "$l" ] && render "$l" "$ZJ_DIR/layouts/$(basename "$l")"; done
fi

# status-bar helper scripts: symlinked + executable.
if [ -d "$src/plugins" ]; then
  for p in "$src"/plugins/*.sh; do
    [ -e "$p" ] || continue
    link "$p" "$ZJ_DIR/plugins/$(basename "$p")"
    chmod +x "$p"
  done
fi

# zjstatus plugin (gitignored binary; fetched on demand).
if [ ! -f "$ZJ_DIR/plugins/zjstatus.wasm" ]; then
  log "downloading zjstatus $ZJSTATUS_VERSION"
  curl -fsSLo "$ZJ_DIR/plugins/zjstatus.wasm" \
    "https://github.com/dj95/zjstatus/releases/download/v${ZJSTATUS_VERSION}/zjstatus.wasm"
fi

# zjstatus permission grant: zellij normally asks for plugin permissions on first
# load and caches the grant in <cache>/permissions.kdl. But zjstatus loads from a
# layout, and layout/background plugins can't display the permission dialog on
# zellij 0.44.x (upstream #4982) — so the bar loads permission-less and renders
# blank forever ("permission 'ReadApplicationState' is not allowed" in the log).
# Seed the grant so the bar works on the very first session.
#
# The cache KEY must be exactly `plugin.location.to_string()` as zellij computes
# it: RunPluginLocation::File's Display is the *bare, shell-expanded path* — NO
# "file:" prefix and ~ expanded (zellij-utils layout.rs). (The plugin *cache dir*
# is named "file:<path>" via a different method — do not copy that form here.)
# We generate the file rather than commit it because the key is an absolute path.
perm_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zellij/permissions.kdl"
perm_key="$ZJ_DIR/plugins/zjstatus.wasm"   # bare expanded path, no scheme prefix
if [ ! -e "$perm_cache" ] || ! grep -qF "\"$perm_key\"" "$perm_cache" 2>/dev/null; then
  mkdir -p "$(dirname "$perm_cache")"
  # append (don't clobber) — zellij rewrites this file when other plugins are
  # granted/denied; we only add our node if it isn't already present.
  {
    printf '"%s" {\n' "$perm_key"
    printf '    ReadApplicationState\n'
    printf '    ChangeApplicationState\n'
    printf '    RunCommands\n'
    printf '}\n'
  } >> "$perm_cache"
  ok "seeded zjstatus permission grant ($perm_cache)"
else
  ok "zjstatus permission grant already present"
fi

ok "zellij configured (config $([ -L "$ZJ_DIR/config.kdl" ] && echo linked), layouts rendered)"
