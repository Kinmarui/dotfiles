#!/usr/bin/env bash
# zellij — terminal multiplexer, pinned, with our custom config + zjstatus bar.
#
# Versions are pinned (override via env): zellij ships session/plugin format
# changes between versions, so we bump deliberately. zjstatus 0.23.x targets
# zellij 0.44.x.
ZELLIJ_VERSION="${ZELLIJ_VERSION:-0.44.3}"
ZJSTATUS_VERSION="${ZJSTATUS_VERSION:-0.23.0}"

ZJ_DIR="$HOME/.config/zellij"
src="$(config_dir zellij)"

# --- binary -------------------------------------------------------------------
if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  current="$(zellij --version 2>/dev/null | awk '{print $2}')"
  if [ "$current" != "$ZELLIJ_VERSION" ]; then
    log "installing zellij $ZELLIJ_VERSION (have: ${current:-none})"
    cd /tmp
    curl -fsSLo zellij.tar.gz \
      "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ARCH}-unknown-linux-musl.tar.gz"
    tar -xf zellij.tar.gz zellij
    sudo install zellij /usr/local/bin/zellij
    rm -f zellij.tar.gz zellij
    cd - >/dev/null
  else
    ok "zellij $ZELLIJ_VERSION already installed"
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
