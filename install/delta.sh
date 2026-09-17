#!/usr/bin/env bash
# git-delta — syntax-highlighting pager for git diffs, wired into global git config.
# Installed from the upstream .deb (delta isn't packaged on Ubuntu 22.04).

# delta comes from upstream (it is not packaged on Ubuntu 22.04), so like
# lazygit/lazydocker "current" means the newest release rather than a distro
# floor — see install/terminal-tools.sh for the tools where the opposite holds.
if [ "${CONFIG_ONLY:-0}" != "1" ]; then
  if [ "$PKG" = "brew" ]; then
    has_cmd delta || pkg_install git-delta
  else
    cur="$(tool_version delta 2>/dev/null || true)"
    ver="$(latest_tag dandavison/delta)" || ver=""    # delta tags carry no "v"
    if [ -z "$ver" ]; then
      [ -n "$cur" ] && warn "could not resolve the latest delta release — keeping $cur"
      [ -n "$cur" ] || err "could not resolve the latest delta release and none is installed"
    elif [ -n "$cur" ] && ver_ge "$ver" "$cur"; then
      ok "delta $cur already current"
    else
      log "installing delta $ver (have: ${cur:-none})"
      install_deb "https://github.com/dandavison/delta/releases/download/${ver}/git-delta_${ver}_$(dpkg --print-architecture).deb" \
        && ok "delta ${cur:-none} -> $(tool_version delta)" \
        || warn "delta install failed — keeping ${cur:-none}"
    fi
  fi
fi

# Wire delta into git (re-applied on --config-only).
if has_cmd delta || [ "${CONFIG_ONLY:-0}" = "1" ]; then
  # Back up the existing global git config before changing keys (once).
  if [ -f "$HOME/.gitconfig" ] && [ ! -f "$HOME/.gitconfig.pre-delta.bak" ]; then
    cp "$HOME/.gitconfig" "$HOME/.gitconfig.pre-delta.bak"
    ok "backed up ~/.gitconfig -> ~/.gitconfig.pre-delta.bak"
  fi
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
