# Environment context for coding agents

This host was bootstrapped by [Kinmarui/dotfiles](https://github.com/Kinmarui/dotfiles),
cloned at `~/dotfiles` (optional private overlay at `~/dotfiles-private`).
Ubuntu/Debian, CLI-only. Repo conventions and config-editing tips live in the
repo's own AGENTS.md and load automatically when working there.

## Prefer the installed tools

- `rg` over `grep -r`, `fd` over `find`, `eza` over `ls`, `bat` for previews,
  `fzf` for interactive picking, `jq` for JSON, `zoxide` for directory jumps,
  `ncdu` for disk usage.
- Debian/Ubuntu apt installs `bat`/`fd` as `batcat`/`fdfind`. Interactive
  aliases fix the names, but scripts should probe for both.
- Language runtimes (node, python, …) are managed by `mise`, not apt — check
  `mise ls`, add with `mise use`. Don't apt-install node/python.
- GitHub: use `gh`. Git diffs page through `delta`; `lazygit` is installed.
- Editor: `nvim`. Monitor: `btop`.

## zellij (terminal multiplexer)

- Interactive work runs inside `zellij` — custom config, layouts, and a
  zjstatus bar, all symlinked from `~/dotfiles` into `~/.config/zellij`.
  Session resurrection is relied on.

## Shell aliases (bash, interactive only — scripts should call real binaries)

- `cd` is zoxide's `z` (frecency jump); `ls`/`lt` are eza listings/trees.
- `g`=git, `n`=nvim, `ff`=fzf+bat preview, `lzg`/`lzd`=lazygit/lazydocker,
  `gcm`/`gcam`/`gcad`=git commit shortcuts, `compress`/`decompress` (tar.gz).
