#!/usr/bin/env bash
# Neovim (latest stable release binary) + checkhealth deps.
# Adapted from omakub install/terminal/app-neovim.sh, minus the LazyVim/desktop
# bits — bring your own nvim config via the private overlay (config/nvim).
# Upstream stable, version-gated. Like lazygit/delta this is our own install
# rather than a distro package, so "current" means the newest stable release —
# `has_cmd nvim` alone left boxes on whatever they happened to have (and on a
# box with a PPA nvim, meant this installer never ran at all). /releases/latest
# skips prereleases, so neovim's nightlies are correctly ignored; the resolved
# tag is used for the download instead of the `stable` alias so the version we
# compared against is the version we fetch.
if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  cur="$(tool_version nvim 2>/dev/null || true)"
  tag="$(latest_tag neovim/neovim)" || tag=""
  ver="${tag#v}"
  if [ -z "$ver" ]; then
    [ -n "$cur" ] && warn "could not resolve the latest neovim release — keeping $cur"
    [ -n "$cur" ] || err "could not resolve the latest neovim release and none is installed"
  elif [ -n "$cur" ] && ver_ge "$ver" "$cur"; then
    ok "neovim $cur already current"
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
    pkg_install luarocks tree-sitter-cli || warn "luarocks/tree-sitter-cli not installed (optional)"
  fi

  # A packaged nvim beside ours is a second copy that apt keeps updating, and
  # whichever comes first in PATH wins — confusing when only one of them is the
  # version reported above. (Ubuntu 22.04 has no usable neovim package, so this
  # is normally a PPA.)
  if has_cmd dpkg && dpkg -s neovim >/dev/null 2>&1; then
    warn "an apt 'neovim' package is installed as well ($(dpkg-query -W -f='${Version}' neovim 2>/dev/null))"
    warn "this repo manages /usr/local/bin/nvim — remove the duplicate with: $SUDO apt remove neovim"
  fi
  live="$(command -v nvim 2>/dev/null || true)"
  if [ -n "$live" ] && [ "$live" != "/usr/local/bin/nvim" ]; then
    warn "PATH resolves nvim to $live, shadowing /usr/local/bin/nvim"
  fi
fi

# Apply nvim config only if one is provided (overlay or public config/nvim).
src="$(config_dir nvim)"
if [ -d "$src" ] && [ ! -e "$HOME/.config/nvim" ]; then
  link "$src" "$HOME/.config/nvim"
  ok "linked nvim config from $src"
fi
