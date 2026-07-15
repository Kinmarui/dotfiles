#!/usr/bin/env bash
# fastfetch — system info. Adapted from omakub install/terminal/app-fastfetch.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd fastfetch && { ok "fastfetch already installed"; return 0; }

if [ "$PKG" = "brew" ]; then pkg_install fastfetch; return 0; fi

# Debian 13 (trixie) ships fastfetch in its main repos; PPAs are Ubuntu-only.
if is_debian; then pkg_install fastfetch; return 0; fi

# Ubuntu: a PPA provides fastfetch for both 22.04 and 24.04.
$SUDO apt-get install -y software-properties-common
$SUDO add-apt-repository -y ppa:zhangsongcui3371/fastfetch
APT_UPDATED=0; pkg_install fastfetch
