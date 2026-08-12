# Dev workstation (XPS) — Windows 11 + WSL2

This machine is the WSL2 dev box. Nothing here applies to the Ubuntu servers.

## WSL2

- Work in the Linux filesystem (`~`). `/mnt/c` is an order of magnitude slower
  for git/builds and risks CRLF line endings — never clone or build there.
- Clipboard: `clip.exe` copies to Windows; `powershell.exe -NoProfile -c
  Get-Clipboard` pastes. Open a file/URL on Windows: `explorer.exe` or `wslview`.
- Ports bound in WSL are reachable from Windows at `localhost`, but NOT from
  the LAN without Windows-side `netsh portproxy` + firewall rules (matters for
  dev servers and inbound mosh).
- Windows exes run from bash; convert path arguments with `wslpath -w` when
  passing WSL paths to them.

## Connecting to servers

- Azure VMs sit behind deny-by-default NSGs: `dmosh <host>` / `azzh <host>`
  first repoint this machine's personal NSG allow rules at the current public
  IP, then connect via mosh / `az ssh vm`. Host aliases live in `DMOSH_HOSTS`
  (private overlay). mosh needs UDP 60000-61000 inbound on the server.
