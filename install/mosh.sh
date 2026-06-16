#!/usr/bin/env bash
# mosh — roaming, latency-tolerant remote shell.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd mosh && { ok "mosh already installed"; return 0; }
pkg_install mosh
warn "mosh uses UDP 60000-61000 — open that range on the server firewall, e.g.:"
warn "  sudo ufw allow 60000:61000/udp"
