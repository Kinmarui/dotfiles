#!/usr/bin/env bash
# btop — resource monitor. Adapted from omakub install/terminal/app-btop.sh
# (theme copy dropped; btop ships its own themes).
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd btop && { ok "btop already installed"; return 0; }
pkg_install btop
