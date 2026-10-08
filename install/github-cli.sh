#!/usr/bin/env bash
# GitHub CLI (gh). Adapted from omakub install/terminal/app-github-cli.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

# Ubuntu 22.04 packages gh 2.4.0 (2022). `has_cmd gh` was enough to declare
# victory on that, so the official repo below — the whole point of this
# installer — was never added on a box that already had the distro build.
# Gate on the version instead: below GH_MIN we (re)point apt at cli.github.com
# and let it upgrade the distro package in place.
# Floor = what Ubuntu 24.04 ships (2.45.0). Debian does not package gh at all,
# so there `outdated` is true by absence and the repo is added as before.
GH_MIN="${GH_MIN:-2.45.0}"
if ! outdated gh "$GH_MIN"; then ok "gh $(tool_version gh) already installed"; return 0; fi
has_cmd gh && log "gh $(tool_version gh) is older than $GH_MIN — upgrading from cli.github.com"

if [ "$PKG" = "brew" ]; then pkg_install gh; return 0; fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  [ -f /usr/share/keyrings/githubcli-archive-keyring.gpg ] && $SUDO rm /usr/share/keyrings/githubcli-archive-keyring.gpg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
  $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi
APT_UPDATED=0; pkg_install gh
