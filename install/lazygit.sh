#!/usr/bin/env bash
# lazygit — terminal UI for git. Adapted from omakub install/terminal/app-lazygit.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

if [ "$PKG" = "brew" ]; then
  has_cmd lazygit && { ok "lazygit already installed"; return 0; }
  pkg_install lazygit; return 0
fi

# This installer fetches lazygit from upstream rather than from a distro
# package, so "current" means the newest release — there is no distro floor to
# respect. Checking only `has_cmd` froze boxes on whatever was current the day
# they were set up (this one sat on 0.46.0 while upstream reached 0.65.1).
tag="$(latest_tag jesseduffield/lazygit)" || tag=""
ver="${tag#v}"
cur="$(tool_version lazygit 2>/dev/null || true)"
if [ -z "$ver" ]; then
  [ -n "$cur" ] && { warn "could not resolve the latest lazygit release — keeping $cur"; return 0; }
  err "could not resolve the latest lazygit release and none is installed"; return 1
fi
if [ -n "$cur" ] && ver_ge "$ver" "$cur"; then ok "lazygit $cur already current"; return 0; fi
log "installing lazygit $ver (have: ${cur:-none})"
arch="$(release_arch)"   # x86_64 | arm64
cd /tmp
curl -fsSLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_${arch}.tar.gz"
tar -xf lazygit.tar.gz lazygit
$SUDO install lazygit /usr/local/bin
rm -f lazygit.tar.gz lazygit
cd - >/dev/null
ok "lazygit ${cur:-none} -> $(tool_version lazygit)"
