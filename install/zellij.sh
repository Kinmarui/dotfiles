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
# sessions drop to EXITED). A glibc build fixes it. 'auto' (default): on a host
# where we live in long-lived resurrected sessions (containers and WSL2 — see
# is_container) reuse an existing glibc zellij if present, else build it from
# source; on bare metal/VM just download the fast musl release. It never
# rebuilds when a matching glibc binary already exists. Force with ZELLIJ_GLIBC=1/0.
ZELLIJ_GLIBC="${ZELLIJ_GLIBC:-auto}"

ZJ_DIR="$HOME/.config/zellij"
src="$(config_dir zellij)"

# --- binary -------------------------------------------------------------------
# is_container: true inside LXC / Docker / podman / systemd-nspawn — and on
# WSL2, which `systemd-detect-virt --container` reports as "wsl". WSL2 is
# deliberately left in: it is a daily-driver dev box where we rely on zellij
# session resurrection, so it wants the glibc build for the same reason a
# container does (the musl btime bug). Set ZELLIJ_GLIBC=0 to opt out.
is_container() {
  if has_cmd systemd-detect-virt; then systemd-detect-virt --container --quiet && return 0; fi
  { [ -f /run/.containerenv ] || [ -f /.dockerenv ]; } && return 0
  grep -qaE 'container=(lxc|docker|podman)' /proc/1/environ 2>/dev/null
}
zellij_ver()      { zellij --version 2>/dev/null | awk '{print $2}'; }
zellij_is_glibc() { ldd "$(command -v zellij 2>/dev/null)" 2>/dev/null | grep -q 'libc\.so\.6'; }
# zellij_bin_ok <path> <ver> : true if that binary is zellij <ver> AND glibc-linked.
zellij_bin_ok() {
  local b="$1" ver="$2"
  [ -x "$b" ] || return 1
  [ "$("$b" --version 2>/dev/null | awk '{print $2}')" = "$ver" ] || return 1
  ldd "$b" 2>/dev/null | grep -q 'libc\.so\.6'
}

# Download the official musl-static release (fast; note: btime/resurrection off).
zellij_install_musl() {
  local ver="$1"
  log "installing zellij $ver (musl release, have: $(zellij_ver 2>/dev/null || echo none))"
  cd /tmp
  curl -fsSLo zellij.tar.gz \
    "https://github.com/zellij-org/zellij/releases/download/v${ver}/zellij-${ARCH}-unknown-linux-musl.tar.gz"
  tar -xf zellij.tar.gz zellij
  $SUDO install zellij /usr/local/bin/zellij
  rm -f zellij.tar.gz zellij
  cd - >/dev/null
  ok "installed musl zellij $(zellij_ver)"
}

# Build a glibc-linked zellij from crates.io (fixes musl btime/resurrection).
# Pinned + --locked for reproducibility. Installs to ~/.cargo/bin (cargo default)
# so a later run can reuse it without recompiling, then copies to /usr/local/bin.
zellij_build_glibc() {
  local ver="$1"
  # Pick a cargo that actually RUNS, before the apt install and the ~15-min
  # build. `has_cmd cargo` alone is not enough on a mise-activated shell: mise
  # puts a `cargo` shim on PATH that fails with "no version set" unless rust is
  # selected for this directory, so a found-but-dead cargo must fall through to
  # `mise exec`. (The other way this fails: mise resolves rust@latest over the
  # GitHub API using the token from gh's hosts.yml, so a stale token gives 401
  # Bad credentials -> no rust -> `"cargo" couldn't exec process`.) Until this
  # check existed the build limped on to `install: cannot stat .../zellij`.
  local -a CARGO=()
  if   has_cmd cargo && cargo --version >/dev/null 2>&1; then CARGO=(cargo)
  elif has_cmd mise  && mise exec rust@latest -- cargo --version >/dev/null 2>&1; then
    CARGO=(mise exec rust@latest -- cargo)
  fi
  if [ "${#CARGO[@]}" -eq 0 ]; then
    err "no usable rust toolchain — not building zellij $ver"
    if has_cmd mise; then
      err "see why: 'mise exec rust@latest -- cargo --version' (a 401 there = expired GitHub token: 'gh auth status', then 'gh auth login')"
      err "or make cargo work everywhere: 'mise use -g rust@latest'"
    else
      err "install cargo, or enable 'mise' in manifest.conf"
    fi
    return 1
  fi
  log "using '${CARGO[*]}' ($("${CARGO[@]}" --version 2>/dev/null | head -1))"
  # vendored openssl+curl (default features) need a C toolchain + perl (+cmake).
  [ "$PKG" = "apt" ] && pkg_install build-essential pkg-config cmake perl
  log "building zellij $ver from source (glibc — fixes session resurrection); this takes a while"
  if ! "${CARGO[@]}" install --locked --force --version "$ver" zellij; then   # -> ~/.cargo/bin/zellij
    err "cargo install zellij $ver failed"; return 1
  fi
  [ -x "$HOME/.cargo/bin/zellij" ] || { err "build reported success but $HOME/.cargo/bin/zellij is missing"; return 1; }
  $SUDO install "$HOME/.cargo/bin/zellij" /usr/local/bin/zellij
  hash -r
}

# Ensure /usr/local/bin/zellij is a glibc build of $1, REUSING an existing glibc
# binary (already installed, or a prior cargo build in ~/.cargo/bin) before paying
# for a ~15-min compile.
zellij_provide_glibc() {
  local ver="$1" cand
  if zellij_bin_ok /usr/local/bin/zellij "$ver"; then
    ok "zellij $ver already installed (glibc)"; return 0
  fi
  for cand in "$HOME/.cargo/bin/zellij" "$(command -v zellij 2>/dev/null || true)"; do
    [ -n "$cand" ] && zellij_bin_ok "$cand" "$ver" || continue
    $SUDO install "$cand" /usr/local/bin/zellij; hash -r
    ok "reused existing glibc zellij $ver from $cand (skipped source build)"; return 0
  done
  zellij_build_glibc "$ver"
  zellij_bin_ok /usr/local/bin/zellij "$ver" \
    && ok "installed glibc zellij $ver -> /usr/local/bin/zellij" \
    || { err "resulting zellij is not glibc/$ver"; return 1; }
}

# Binary failures are recorded, not fatal: the config below is still worth
# applying (and is idempotent), but the installer must exit non-zero so
# bootstrap.sh reports "[zellij] failed" instead of "done".
zellij_bin_failed=0

if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  want_glibc=0
  case "$ZELLIJ_GLIBC" in
    1|yes|true)  want_glibc=1 ;;
    0|no|false)  want_glibc=0 ;;
    *)           is_container && want_glibc=1 ;;   # auto (containers + WSL2)
  esac
  cur="$(zellij_ver 2>/dev/null || true)"

  if [ "$want_glibc" = "1" ]; then
    zellij_provide_glibc "$ZELLIJ_VERSION" || zellij_bin_failed=1   # reuse-then-build (see fn)
  else
    if [ "$cur" = "$ZELLIJ_VERSION" ] && ! zellij_is_glibc; then
      ok "zellij $ZELLIJ_VERSION already installed (musl)"
    else
      zellij_install_musl "$ZELLIJ_VERSION" || zellij_bin_failed=1
    fi
  fi

  # An older zellij earlier in PATH (e.g. a distro/omakub one in /usr/bin) would
  # keep winning over the binary we just installed — a silent version mismatch
  # against the config and zjstatus build below.
  if [ "$zellij_bin_failed" = "0" ]; then
    live="$(command -v zellij 2>/dev/null || true)"
    if [ -n "$live" ] && [ "$live" != "/usr/local/bin/zellij" ]; then
      warn "PATH resolves zellij to $live ($("$live" --version 2>/dev/null || echo unknown)), shadowing /usr/local/bin/zellij — remove it or fix PATH order"
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

# Report the binary step's verdict last, so bootstrap.sh sees it.
[ "$zellij_bin_failed" = "0" ] || { err "zellij $ZELLIJ_VERSION binary step failed (config was still applied)"; return 1; }
