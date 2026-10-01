#!/usr/bin/env bash
# Neovim (latest stable release binary) + what config/nvim needs at runtime.
# Adapted from omakub install/terminal/app-neovim.sh, minus the LazyVim/desktop
# bits — config comes from config/nvim (or the private overlay's).
#
# Runtime deps of config/nvim, provided here so every box behaves the same:
#   - tree-sitter CLI >= $TS_MIN + a C compiler: nvim-treesitter's `main` branch
#     compiles parsers locally. Distro packages are far too old (Ubuntu 24.04
#     ships 0.20.8), and upstream's prebuilt binary needs glibc 2.39, so on
#     Debian 12 / Ubuntu 22.04 it is built from source with cargo instead.
#   - Java >= $JAVA_MIN for the lang.java / lang.kotlin extras (jdtls,
#     kotlin-language-server), via mise.
TS_MIN="0.26.1"
JAVA_MIN="21"
JAVA_MISE="${JAVA_MISE:-temurin-21}"

# --- neovim -------------------------------------------------------------------
# Upstream stable, version-gated: `has_cmd nvim` alone left boxes on whatever
# they happened to have. /releases/latest skips prereleases, and the resolved tag
# is downloaded rather than the moving `stable` alias, so the version compared is
# the version fetched. Upstream's linux tarball needs glibc 2.34 (fine on Debian
# 12+/Ubuntu 22.04+).
install_neovim() {
  local cur tag ver arch
  cur="$(tool_version nvim 2>/dev/null || true)"
  tag="$(latest_tag neovim/neovim)" || tag=""
  ver="${tag#v}"
  if [ -z "$ver" ]; then
    [ -n "$cur" ] && warn "could not resolve the latest neovim release — keeping $cur"
    [ -n "$cur" ] || err "could not resolve the latest neovim release and none is installed"
    return 0
  fi
  if [ -n "$cur" ] && ver_ge "$ver" "$cur"; then
    ok "neovim $cur already current"
  elif [ "$PKG" = "brew" ]; then
    pkg_install neovim
  else
    log "installing neovim $ver (have: ${cur:-none})"
    arch="$(release_arch)"   # x86_64 | arm64
    cd /tmp
    curl -fsSLo nvim.tar.gz "https://github.com/neovim/neovim/releases/download/${tag}/nvim-linux-${arch}.tar.gz"
    tar -xf nvim.tar.gz
    $SUDO install "nvim-linux-${arch}/bin/nvim" /usr/local/bin/nvim
    $SUDO cp -R "nvim-linux-${arch}/lib" /usr/local/
    $SUDO cp -R "nvim-linux-${arch}/share" /usr/local/
    rm -rf "nvim-linux-${arch}" nvim.tar.gz
    cd - >/dev/null
    hash -r
    ok "neovim ${cur:-none} -> $(tool_version nvim)"
  fi

  # A packaged nvim beside ours is a second copy that apt keeps updating, and
  # whichever comes first in PATH wins.
  if has_cmd dpkg && dpkg -s neovim >/dev/null 2>&1; then
    warn "an apt 'neovim' package is installed as well ($(dpkg-query -W -f='${Version}' neovim 2>/dev/null))"
    warn "this repo manages /usr/local/bin/nvim — remove the duplicate with: $SUDO apt remove neovim"
  fi
  local live; live="$(command -v nvim 2>/dev/null || true)"
  if [ -n "$live" ] && [ "$live" != "/usr/local/bin/nvim" ] && [ "$PKG" != "brew" ]; then
    warn "PATH resolves nvim to $live, shadowing /usr/local/bin/nvim"
  fi
}

# --- tree-sitter CLI + C compiler ---------------------------------------------
install_tree_sitter() {
  has_cmd cc || pkg_install gcc
  if ! outdated tree-sitter "$TS_MIN"; then
    ok "tree-sitter $(tool_version tree-sitter) already installed"
    return 0
  fi
  if [ "$PKG" = "brew" ]; then pkg_install tree-sitter-cli; return 0; fi

  local cur tag tmp asset; cur="$(tool_version tree-sitter 2>/dev/null || true)"
  tag="$(latest_tag tree-sitter/tree-sitter)" || { warn "could not resolve the latest tree-sitter release"; return 0; }
  case "$ARCH" in
    x86_64) asset="tree-sitter-linux-x64.gz" ;;
    aarch64) asset="tree-sitter-linux-arm64.gz" ;;
    *) warn "no prebuilt tree-sitter for $ARCH"; asset="" ;;
  esac
  tmp="$(mktemp -d)"
  # Try upstream's binary first; it only runs where glibc is new enough, so
  # "does it execute" is the compatibility check.
  if [ -n "$asset" ] && curl -fsSLo "$tmp/ts.gz" "https://github.com/tree-sitter/tree-sitter/releases/download/${tag}/${asset}" \
       && gunzip "$tmp/ts.gz" && chmod +x "$tmp/ts" && "$tmp/ts" --version >/dev/null 2>&1; then
    $SUDO install "$tmp/ts" /usr/local/bin/tree-sitter
  else
    local -a CARGO
    if   has_cmd cargo; then CARGO=(cargo)
    elif has_cmd mise;  then CARGO=(mise exec rust@latest -- cargo)
    else err "prebuilt tree-sitter won't run here and there is no cargo or mise to build it"; rm -rf "$tmp"; return 1; fi
    log "building tree-sitter ${tag#v} from source (prebuilt needs a newer glibc); this takes a few minutes"
    "${CARGO[@]}" install --locked --version "${tag#v}" --root "$tmp/cargo" tree-sitter-cli
    $SUDO install "$tmp/cargo/bin/tree-sitter" /usr/local/bin/tree-sitter
  fi
  rm -rf "$tmp"
  hash -r
  ok "tree-sitter ${cur:-none} -> $(/usr/local/bin/tree-sitter --version | awk '{print $2}')"
  local live; live="$(command -v tree-sitter 2>/dev/null || true)"
  [ "$live" = "/usr/local/bin/tree-sitter" ] || warn "PATH resolves tree-sitter to $live ($(tool_version tree-sitter)), shadowing /usr/local/bin/tree-sitter"
}

# --- Java (jdtls, kotlin-language-server) --------------------------------------
install_java() {
  local cur=""
  if has_cmd mise; then
    cur="$(mise exec -- java --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || true)"
  elif has_cmd java; then
    cur="$(tool_version java 2>/dev/null || true)"
  fi
  if [ -n "$cur" ] && ver_ge "$JAVA_MIN" "$cur"; then
    ok "java $cur already installed"
  elif has_cmd mise; then
    log "installing java $JAVA_MISE via mise (have: ${cur:-none})"
    mise use -g "java@$JAVA_MISE"
    ok "java $(mise exec -- java --version 2>/dev/null | head -1)"
  else
    warn "java >= $JAVA_MIN not found and mise is unavailable — the java/kotlin LSPs won't start"
  fi
}

if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  install_neovim
  install_tree_sitter
  install_java
fi

# --- config -------------------------------------------------------------------
# Symlinked (live-editable, follows `git pull`). An existing real ~/.config/nvim
# is moved aside to ~/.config/nvim.bak.<pid> by `link`.
src="$(config_dir nvim)"
if [ -d "$src" ]; then
  if [ "$(readlink "$HOME/.config/nvim" 2>/dev/null)" = "$src" ]; then
    ok "nvim config already linked from $src"
  else
    link "$src" "$HOME/.config/nvim"
    ok "linked nvim config from $src"
  fi
fi
