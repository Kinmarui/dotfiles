# Working on this repo

See README.md for the layout and how `bootstrap.sh` works. Conventions that
matter when changing things:

## Conventions

- Installers (`install/<app>.sh`) are **idempotent**: guard binary installs
  with `has_cmd`, gate the install (not config) side with
  `[ "${CONFIG_ONLY:-0}" != "1" ]`. Config application always runs.
- Source helpers from `lib/common.sh`: `link`/`render` for config, `pkg_install`
  for packages, `$SUDO` (never bare `sudo` — it's empty when root), `ok`/`warn`/`err`
  for output, `config_dir <app>` to resolve config.
- `config_dir` returns the **private overlay's** `config/<app>/` wholesale when
  it exists (`~/dotfiles-private`); an overlay app dir must ship every file the
  installer links. Secrets and machine-specific values go in the overlay, never here.
- A new tool = `install/<name>.sh` + `manifest.conf` entry + optional `config/<name>/`.
- Re-apply configs without reinstalling: `./bootstrap.sh --config-only [app...]`.
- Targets Ubuntu 22.04/24.04 and Debian 12/13 (apt); macOS/brew is secondary.

## zellij config editing

- **Read `config/zellij/NOTES.md` first** — the gotchas there are hard-won
  (musl vs glibc session resurrection, zjstatus permission bugs, frame flicker).
- Layouts are baked into a session at creation: edits only affect **new**
  sessions — test with `zellij -l <layout>` from outside zellij.
- `~/.config/zellij/**` must stay **symlinks** into this repo; they can
  silently become real files (then repo edits never go live). Verify with
  `ls -l ~/.config/zellij/**`.

## Agent context files (`config/claude/`)

- `AGENTS.md` → linked to `~/.claude/CLAUDE.md` on every node (host
  environment, loads in every session).
- `dev-machine.md` → linked to `~/.claude/rules/dev-machine.md` only on the
  XPS dev workstation (WSL2 notes, server-connect helpers).
- This file (repo root) loads only for sessions working in the repo.
