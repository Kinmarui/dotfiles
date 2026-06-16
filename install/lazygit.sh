#!/usr/bin/env bash
# lazygit — terminal UI for git. Adapted from omakub install/terminal/app-lazygit.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd lazygit && { ok "lazygit already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install lazygit; return 0; fi

ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "v\K[^"]*')"
arch="$(release_arch)"   # x86_64 | arm64
cd /tmp
curl -fsSLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${ver}_Linux_${arch}.tar.gz"
tar -xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm -f lazygit.tar.gz lazygit
cd - >/dev/null
