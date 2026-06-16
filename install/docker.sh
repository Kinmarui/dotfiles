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
echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"5"}}' | sudo tee /etc/docker/daemon.json >/dev/null
warn "log out and back in for docker group membership to take effect"
