#!/usr/bin/env bash
# fastfetch — system info. Adapted from omakub install/terminal/app-fastfetch.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd fastfetch && { ok "fastfetch already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install fastfetch; return 0; fi

# PPA provides fastfetch for both 22.04 and 24.04.
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
APT_UPDATED=0; pkg_install fastfetch
