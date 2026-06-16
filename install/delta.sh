#!/usr/bin/env bash
# git-delta — syntax-highlighting pager for git diffs, wired into global git config.
# Installed from the upstream .deb (delta isn't packaged on Ubuntu 22.04).

if [ "${CONFIG_ONLY:-0}" != "1" ] && ! has_cmd delta; then
  if [ "$PKG" = "brew" ]; then
    pkg_install git-delta
  else
    ver="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep -Po '"tag_name": "\K[^"]*')"
    arch="$(dpkg --print-architecture)"   # amd64 | arm64
    cd /tmp
    curl -fsSLo git-delta.deb "https://github.com/dandavison/delta/releases/download/${ver}/git-delta_${ver}_${arch}.deb"
    sudo apt-get install -y ./git-delta.deb
    rm -f git-delta.deb
    cd - >/dev/null
  fi
elif has_cmd delta; then
  ok "delta already installed"
fi

# Wire delta into git (re-applied on --config-only).
if has_cmd delta || [ "${CONFIG_ONLY:-0}" = "1" ]; then
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  # zdiff3 needs git >= 2.35 (Ubuntu 22.04 ships 2.34); fall back to diff3.
  gitver="$(git --version | awk '{print $3}')"
  if [ "$(printf '%s\n2.35.0\n' "$gitver" | sort -V | head -1)" = "2.35.0" ]; then
    git config --global merge.conflictStyle zdiff3
  else
    git config --global merge.conflictStyle diff3
  fi
  ok "git configured to use delta"
fi
