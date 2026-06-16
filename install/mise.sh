#!/usr/bin/env bash
# mise — runtime version manager. Adapted from omakub install/terminal/mise.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd mise && { ok "mise already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install mise; return 0; fi

# apt repo (works on jammy 22.04 and noble 24.04)
pkg_install gpg wget curl
sudo install -dm 755 /etc/apt/keyrings
wget -qO- https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
APT_UPDATED=0; pkg_install mise
