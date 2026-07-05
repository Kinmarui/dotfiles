# zellij + zjstatus notes / gotchas

Hard-won lessons configuring these layouts (zellij 0.44.3, zjstatus v0.18.1).
Read this before editing the layouts or debugging the status bar.

## musl release breaks session resurrection (btime) — build glibc in containers
The official zellij Linux release is **musl-static**, and Rust's `std` can't read
a file's creation time (btime) on musl — `Metadata::created()` returns
*"creation time is not available on this platform currently"* on **any** host.
zellij needs btime for session **resurrection**, so with the musl binary the log
spams `Failed to read created stamp of resurrection file` and sessions drop to
`EXITED` instead of resurrecting. This is NOT a Proxmox/LXC/filesystem problem —
coreutils `stat` reads btime fine here (ext4 + kernel `statx` work); it's purely
the musl binary. zellij ships **no** glibc Linux release, and Ubuntu 24.04
doesn't package zellij, so the only glibc build that runs on our glibc (2.39) is
a from-source `cargo install`. `install/zellij.sh` does this automatically inside
a container (see `ZELLIJ_GLIBC`). Verify the fix: `ldd $(which zellij)` shows
`libc.so.6` (glibc) and the resurrection error is gone from the log.

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

## Status bar blank on a fresh install — permission grant can't be given interactively
On zellij 0.44.x, plugins loaded from a **layout** (like our zjstatus bar) call
`request_permission()` before they're attached to a tab, so zellij **can never
show the permission dialog** for them (upstream bug **#4982**). Result: the bar
loads permission-less and renders blank *forever* — the log shows
`permission 'ReadApplicationState' is not allowed - Event ... denied`, not just a
missing-file error. You can't grant it by "arrowing to the bar and pressing y";
that path is dead for background/layout plugins. (An *interactively* launched
plugin — `zellij action launch-plugin` — does get a dialog, since it attaches to
a tab immediately; that's the only way to make zellij write the file itself.)

Fix: seed the grant into `<cache>/permissions.kdl` (default
`~/.cache/zellij/permissions.kdl`). `install/zellij.sh` does this, appending our
node if absent (never clobbers — zellij rewrites the file when other plugins are
granted/denied).

**The cache KEY is the trap.** It must equal `plugin.location.to_string()` as
zellij computes it. For a file plugin that is `RunPluginLocation::File`'s
`Display` impl = the **bare, shell-expanded path** — i.e.
`/home/you/.config/zellij/plugins/zjstatus.wasm`. **No `file:` prefix, `~`
expanded.** Do NOT use `file:...` or `file:~/...` — zellij reads the file fine
but matches nothing and grants zero permissions (silent). Misleading: the
plugin's *cache directory* IS named `file:<path>` (that uses a different
`display()` method), and upstream workaround snippets show `file:~/...` — both
are wrong for the permission key on 0.44.x. Verify by tailing the log: no
`is not allowed` lines = the key matched.

The cache is read at **plugin load**, so an already-running session must be
restarted to pick up a newly-seeded grant (new sessions just work).

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

## Don't set `layout_dir` to a `~` path — omit it
zellij does NOT expand a leading `~` in `layout_dir`, and `install/zellij.sh`
**symlinks** config.kdl (doesn't render it), so a `layout_dir "~/.config/zellij/layouts"`
makes zellij look in a literal `~` directory and fail:
`IoError: The layout was not found, File: compact-extra-info`.
Fix: **omit `layout_dir` entirely** — zellij defaults to `~/.config/zellij/layouts`
and resolves it natively. (An absolute path also works but isn't portable.)
