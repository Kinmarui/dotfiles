#!/usr/bin/env bash
# Neovim (latest stable release binary) + checkhealth deps.
# Adapted from omakub install/terminal/app-neovim.sh, minus the LazyVim/desktop
# bits — bring your own nvim config via the private overlay (config/nvim).
if [ "${CONFIG_ONLY:-0}" != "1" ] && ! has_cmd nvim; then
  arch="$(release_arch)"   # x86_64 | arm64
  cd /tmp
  curl -fsSLo nvim.tar.gz "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-${arch}.tar.gz"
  tar -xf nvim.tar.gz
  sudo install "nvim-linux-${arch}/bin/nvim" /usr/local/bin/nvim
  sudo cp -R "nvim-linux-${arch}/lib" /usr/local/
  sudo cp -R "nvim-linux-${arch}/share" /usr/local/
  rm -rf "nvim-linux-${arch}" nvim.tar.gz
  cd - >/dev/null
  pkg_install luarocks tree-sitter-cli || warn "luarocks/tree-sitter-cli not installed (optional)"
elif has_cmd nvim; then
  ok "neovim already installed"
fi

# Apply nvim config only if one is provided (overlay or public config/nvim).
src="$(config_dir nvim)"
if [ -d "$src" ] && [ ! -e "$HOME/.config/nvim" ]; then
  link "$src" "$HOME/.config/nvim"
  ok "linked nvim config from $src"
fi
