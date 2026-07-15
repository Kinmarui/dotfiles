# dotfiles

Bootstrap a fresh Ubuntu or Debian machine — CLI tools + their configuration —
with one clone and one command:

```bash
# HTTPS (default) — this repo is public, so this works with no local SSH key
git clone https://github.com/Kinmarui/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap.sh
```

**Debian minimal ships neither `git` nor `sudo`.** On a fresh Debian install,
install both first (as root — `su -`), then clone:

```bash
apt update && apt install -y git sudo
usermod -aG sudo <youruser>     # then log out and back in for it to apply
```

(If you run the bootstrap *as root*, sudo isn't needed — it calls commands
directly. It's only required when bootstrapping as a normal user.)

If you'll also be editing this repo and pushing from the same host, clone over
SSH instead (needs a key added to GitHub, or `gh auth login` + `gh auth setup-git`
first — otherwise the clone itself fails on a host with no key configured):

```bash
git clone git@github.com:Kinmarui/dotfiles.git ~/dotfiles
```

Targets **Ubuntu 22.04 / 24.04 and Debian 13 (trixie)** (apt). A macOS/Homebrew
path exists for most tools but is secondary. CLI only — no desktop apps.

## How it works

`bootstrap.sh` reads `manifest.conf` (or app names you pass on the CLI), then
runs `install/<app>.sh` for each. Helpers live in `lib/common.sh` (logging,
OS/arch detection, `apt`/`brew` abstraction, symlink/render helpers).

```
bootstrap.sh        entry point
manifest.conf       which apps to install by default
lib/common.sh       shared shell helpers
install/<app>.sh    one installer per app (install + apply config)
config/<app>/       configuration this repo ships (e.g. zellij)
```

### Usage

```bash
./bootstrap.sh                 # install everything in manifest.conf
./bootstrap.sh zellij mosh     # install only these (ignores the manifest)
./bootstrap.sh --config-only   # re-apply configs, skip binary installs
./bootstrap.sh --list          # list available installers
```

Installers are **idempotent** — re-running skips what's already present.

### Adding an app

1. Drop `install/<name>.sh` (source helpers from `lib/common.sh`; guard installs
   with `has_cmd`; gate config-only re-runs with `[ "${CONFIG_ONLY:-0}" = 1 ]`).
2. If it ships config, put it in `config/<name>/` and apply it from the script.
3. Add `<name>` to `manifest.conf`.

## Shell enhancements

The `shell` app (`config/shell/`, adapted from omakub's bash defaults,
CLI-only) wires up aliases, functions, and runtime hooks that the other apps
install but don't activate on their own — before this, `~/.bashrc` never
called `mise activate`, `zoxide init`, or fzf's key-bindings, so those tools
sat installed but dormant.

- **Runtime hooks** — activates `mise`, `zoxide`, and fzf's
  key-bindings/completion in `~/.bashrc`.
- **Aliases** — `lzg`/`lzd` (lazygit/lazydocker), `g` (git), `n` (open the cwd,
  or given args, in Neovim), `cd` → zoxide's `z`, `ff` (fzf with a bat file
  preview), `ls`/`lt` via `eza`.
- **bat/fd naming fixups** — Debian/Ubuntu apt packages install these as
  `batcat`/`fdfind` (name clashes with other packages); the aliases resolve to
  whichever name is actually present.
- **Functions** — `compress`/`decompress` (tar.gz).

Config is symlinked into `~/.config/dotfiles/shell` (private overlay wins,
same as every other app — see below) and sourced from `~/.bashrc` via one
idempotent line added by `install/shell.sh`.

## Public + private overlay

This repo is **public** and contains nothing secret. Machine-specific config,
private/internal tools, and secrets live in a separate **private** repo cloned
to `~/dotfiles-private` (or `$DOTFILES_PRIVATE`). When present, the overlay wins:

- `dotfiles-private/install/<app>.sh` overrides this repo's installer
- `dotfiles-private/config/<app>/` overrides this repo's config
- `dotfiles-private/manifest.conf` is appended to this one

`bootstrap.sh` runs fine with no overlay (public-only).

## Re-running after omakub

If you also use [omakub](https://omakub.org), run it **first**, then this
bootstrap — omakub manages parts of `~/.config` (it will replace a symlinked
directory with a real one). This repo defends against that where it matters
(e.g. zellij themes are linked file-by-file so omakub's own theme files
coexist). After an omakub upgrade, re-assert config with `./bootstrap.sh
--config-only`.

## Credits

CLI installers under `install/` are adapted from
[omakub](https://github.com/basecamp/omakub) (MIT). See `NOTICE`.

## License

MIT — see `LICENSE`.
