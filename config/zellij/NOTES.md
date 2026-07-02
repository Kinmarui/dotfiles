# zellij + zjstatus notes / gotchas

Hard-won lessons configuring these layouts (zellij 0.44.3, zjstatus v0.18.1).
Read this before editing the layouts or debugging the status bar.

## Layout changes only apply to NEW sessions
zellij bakes the layout into a session at creation. Editing a layout file does
**not** change existing/resurrected sessions. Test with a fresh session:
`zellij -l compact-extra-info` (from a shell *not* already inside zellij).

## Live files must be symlinks to this repo
`~/.config/zellij/{config.kdl,layouts/*.kdl,plugins/*.sh}` should be symlinks
back here. They can silently become **real files** (a copy replaces the
symlink), after which repo edits never go live. Verify: `ls -l ~/.config/zellij/**`.

## Flicker = frame-control war
zellij `pane_frames` (default true) fighting zjstatus
`hide_frame_for_single_pane "true"` (toggles frames every redraw) causes a
flicker/shake. Fix: set `pane_frames true` explicitly in config.kdl and remove
`hide_frame_for_single_pane`. (Upstream: zjstatus #258.)

## Status bar blank on load until a keypress
On zellij 0.44.3, `command_*` (and datetime) widgets only refresh on events,
not on their interval — zellij dropped the incidental 1s refresh loop zjstatus
relied on. So stats/host are blank until the first key/mode/tab event.
Upstream bug zjstatus **#260**; fix is PR **#253** (merged to main, unreleased
as of 2026-06). Action: bump `zjstatus.wasm` past v0.23.0 once released.
Not fixable by config on a released build.

## Every swap layout needs its own status-bar pane
`swap_tiled_layout` / `swap_floating_layout` **replace the whole tab layout**,
including the bar. A swap layout with no bar pane (or a bare
`plugin location="...zjstatus.wasm"` with no config block) means the bar
disappears or renders empty when that layout activates (multiple panes,
floating windows). Each swap layout must carry the fully-configured bar.

## Don't share one zjstatus via a plugin alias when another bar uses the file directly
Defining a `zjstatus` alias in config.kdl `plugins{}` pointing at the same
`.wasm` that a layout references via `location="file:...zjstatus.wasm"` makes
the alias config **bleed into** the inline bar (zellij keys plugin config by
resolved location). Symptom: one layout renders another's config. Use inline
config per bar instead.

## zjstatus command_* paths are not shell-expanded
`command_*_command` values are run directly — `~` is NOT expanded. Use absolute
paths, or render `~/` → `$HOME/` at install time (see `install/zellij.sh`,
which renders layouts). `location="file:~/..."` *is* expanded by zellij.
