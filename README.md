# dotfiles

Bootstrap a fresh Ubuntu machine — CLI tools + their configuration — with one
clone and one command:

```bash
git clone git@github.com:Kinmarui/dotfiles.git ~/dotfiles
~/dotfiles/bootstrap.sh
```

Targets **Ubuntu 22.04 and 24.04** (apt). A macOS/Homebrew path exists for most
tools but is secondary. CLI only — no desktop apps.

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
