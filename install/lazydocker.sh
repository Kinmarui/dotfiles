#!/usr/bin/env bash
# lazydocker — terminal UI for docker. Adapted from omakub install/terminal/app-lazydocker.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0

if [ "$PKG" = "brew" ]; then
  has_cmd lazydocker && { ok "lazydocker already installed"; return 0; }
  pkg_install lazydocker; return 0
fi

# This installer fetches lazydocker from upstream rather than from a distro
# package, so "current" means the newest release — there is no distro floor to
# respect. Checking only `has_cmd` froze boxes on whatever was current the day
# they were set up (this one sat on 0.46.0 while upstream reached 0.65.1).
tag="$(latest_tag jesseduffield/lazydocker)" || tag=""
ver="${tag#v}"
cur="$(tool_version lazydocker 2>/dev/null || true)"
if [ -z "$ver" ]; then
  [ -n "$cur" ] && { warn "could not resolve the latest lazydocker release — keeping $cur"; return 0; }
  err "could not resolve the latest lazydocker release and none is installed"; return 1
fi
if [ -n "$cur" ] && ver_ge "$ver" "$cur"; then ok "lazydocker $cur already current"; return 0; fi
log "installing lazydocker $ver (have: ${cur:-none})"
arch="$(release_arch)"
cd /tmp
curl -fsSLo lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${ver}_Linux_${arch}.tar.gz"
tar -xf lazydocker.tar.gz lazydocker
$SUDO install lazydocker /usr/local/bin
rm -f lazydocker.tar.gz lazydocker
cd - >/dev/null
ok "lazydocker ${cur:-none} -> $(tool_version lazydocker)"
