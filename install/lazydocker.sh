#!/usr/bin/env bash
# lazydocker — terminal UI for docker. Adapted from omakub install/terminal/app-lazydocker.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd lazydocker && { ok "lazydocker already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install lazydocker; return 0; fi

ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep -Po '"tag_name": "v\K[^"]*')"
arch="$(release_arch)"
cd /tmp
curl -fsSLo lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_${ver}_Linux_${arch}.tar.gz"
tar -xf lazydocker.tar.gz lazydocker
sudo install lazydocker /usr/local/bin
rm -f lazydocker.tar.gz lazydocker
cd - >/dev/null
