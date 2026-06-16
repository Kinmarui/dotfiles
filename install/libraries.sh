#!/usr/bin/env bash
# Build toolchain + common dev headers. Adapted from omakub install/terminal/libraries.sh.
[ "${CONFIG_ONLY:-0}" = "1" ] && return 0
[ "$PKG" = "apt" ] || { warn "libraries.sh targets apt/Ubuntu only — skipping"; return 0; }

pkg_install \
  build-essential pkg-config autoconf bison clang rustc pipx \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libncurses-dev libffi-dev libgdbm-dev libjemalloc2 \
  libvips imagemagick libmagickwand-dev mupdf mupdf-tools \
  redis-tools sqlite3 libsqlite3-0 libmysqlclient-dev libpq-dev postgresql-client postgresql-client-common
