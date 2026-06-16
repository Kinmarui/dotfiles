#!/usr/bin/env bash
# Docker CE engine + compose plugin. Adapted from omakub install/terminal/docker.sh.
# Privileged: adds you to the docker group and writes /etc/docker/daemon.json.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
has_cmd docker && { ok "docker already installed"; return 0; }

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  [ -f /etc/apt/keyrings/docker.asc ] && sudo rm /etc/apt/keyrings/docker.asc
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo wget -qO /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${OS_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi
APT_UPDATED=0
pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

sudo usermod -aG docker "${USER}"

# Limit container log size. Merge into any existing daemon.json (don't clobber a
# host that already has tuned daemon settings).
desired='{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"}}'
if [ -f /etc/docker/daemon.json ]; then
  sudo cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
  if has_cmd jq; then
    merged="$(sudo cat /etc/docker/daemon.json | jq --argjson d "$desired" '. * $d')"
    printf '%s\n' "$merged" | sudo tee /etc/docker/daemon.json >/dev/null
    ok "merged log-size limits into existing /etc/docker/daemon.json (backed up)"
    warn "restart docker for daemon.json changes to apply: sudo systemctl restart docker"
  else
    warn "/etc/docker/daemon.json exists and jq is missing — NOT modifying it."
    warn "merge these settings manually, then restart docker: $desired"
  fi
else
  echo "$desired" | sudo tee /etc/docker/daemon.json >/dev/null
  ok "wrote /etc/docker/daemon.json with log-size limits"
fi
warn "log out and back in for docker group membership to take effect"
