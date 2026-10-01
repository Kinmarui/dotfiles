#!/usr/bin/env bash
# mise — runtime version manager. Adapted from omakub install/terminal/mise.sh.
# Global default node (override with MISE_NODE=22 etc.). Language servers that
# mason installs from npm (bash-language-server, ...) run on this node, and an
# old global pin breaks them (node 16 can't load bash-language-server's wasm).
MISE_NODE="${MISE_NODE:-lts}"
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

set_global_node() {
  mise use -g "node@$MISE_NODE"
  ok "mise global node@$MISE_NODE ($(mise exec -- node --version 2>/dev/null))"
}

if has_cmd mise; then ok "mise already installed"; set_global_node; return 0; fi

if [ "$PKG" = "brew" ]; then pkg_install mise; set_global_node; return 0; fi

# apt repo (works on jammy 22.04 and noble 24.04)
pkg_install gpg wget curl
$SUDO install -dm 755 /etc/apt/keyrings
wget -qO- https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | $SUDO tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
  | $SUDO tee /etc/apt/sources.list.d/mise.list >/dev/null
APT_UPDATED=0; pkg_install mise
set_global_node
