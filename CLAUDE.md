# Project context (auto-read by Claude Code at session start)

This is Asher's ground-up rewrite of his HTPC's NixOS config — the old one
is out of date and messy. Goal: reproducible enough to publish on GitHub
for others to use as a template or flake input. This file exists so a new
session doesn't have to be re-briefed from scratch; see README.md for
structural/how-to details, this file for *why* things are the way they are.

## Status as of 2026-09-29

First real boot on the HTPC happened 2026-09-29 via `nixos-rebuild boot`.
Working: the desktop, mpv-htpc with shaders loading, and the Stremio → mpv
handoff (the new listener). Plasma Bigscreen's homescreen failed to load
because the QML module org.kdeconnect was missing. The fix
(`programs.kdeconnect.enable` in bigscreen.nix) is committed but untested.
The HTPC boots legacy BIOS with GRUB on /dev/nvme0n1, and its
system.stateVersion is 25.11, matching the original install. The ProtonVPN
module is still off: `./secrets.nix` has not been imported yet.

2026-11-18 (all untested): CRT shader turned off via `CRT_ENABLED = false`
in auto_upscaler.lua. Heroic and Lutris were added (`gaming.{heroic,lutris}`),
since Epic has no Linux client. KDE Connect now auto-accepts pairing
(`bigscreen.kdeconnect.autoAcceptPairing`, a busctl polling user service), so
no dialog needs a mouse. Any LAN device can now pair, which was accepted for a
home network.

2026-11-19: the MX3 Pro remote turned up (its dongle had gone missing in a
motherboard swap). Added `modules/hardware/input.nix`
(`hardware.input.{logging,tools}`): it logs udev hotplug events to the
journal (`journalctl -u input-udev-log`) and installs evtest, libinput and
`input-report`. Key presses are deliberately not logged, since a keyboard
log would capture passwords. Button codes are captured on demand instead.
Per-device keymaps (hwdb) go in this module once the codes are known.

The real `hosts/htpc/hardware-configuration.nix` was committed 2026-11-19
(root ext4 by-uuid 3c149b35-..., no /boot or swap). It used to exist only
uncommitted in the HTPC's clone, so the first `github:` build used the
placeholder and failed to boot. Regenerate and commit it if the disks change.

2026-11-19 HTPC feedback: Stremio Web v5.1 broke stremio-enhanced 1.2.0 (no
Enhanced settings section, themes gone). 1.2.1 was packaged locally, then
replaced the same day by the native shell (see the Stremio Enhanced entry
below). The
Movies button (KEY_CONFIG) was a Plasma quick-settings shortcut, so it is
remapped to KEY_FAVORITES via hwdb. Moonlight and Fred TV get a KWin
fullscreen rule (`bigscreen.fullscreenApps`). KDE Connect remote input is
pre-authorized in the portal's kde-authorized table. All untested on the HTPC.
YouTube on the HTPC is "still shocking", details pending. VacuumTube
(YouTube TV UI) isn't in nixpkgs.
The MX3 Pro was mapped the same day, on the desktop rather than the HTPC. It
already sends standard remote keycodes, so there is no hwdb remap. Its player
bindings are in `files/mpv/input.conf`, and `remotes.mx3Pro` only stops USB
autosuspend for its receiver. The red/green/yellow/blue buttons send nothing
(re-tested), likely IR-learning keys like TV. Bigscreen's handling of Back and Home has not been checked on
the HTPC yet.

2026-11-20, the clean-slate renovation (written, untested, needs a reinstall):
KDE, KWin, SDDM, Bigscreen and KDE Connect are gone. `modules/desktop/hyprland.nix`
(`services.htpc.desktop.hyprland`) replaces bigscreen.nix: getty autologin
on tty1 plus `exec start-hyprland -- -c /etc/htpc/hyprland.lua` from the
login shell, copied from Balthasar. The config is Hyprland's Lua format
(0.57): static `files/hyprland/hyprland.lua` plus a generated tail (monitor,
fullscreenApps window rules, autostart, extraConfig). The static file plus a
sample tail passed `Hyprland --verify-config` (Balthasar's 0.57.0), which
does reject unknown keys and rule fields. Bootloader is Limine on UEFI. The
disk is declared in `hosts/htpc/disko.nix` (GPT, 1G vfat ESP at /boot, ext4
root), so hardware-configuration.nix has no fileSystems. Limine can't read
ext4, which is what forced repartitioning. Nothing on the old disk was worth
keeping. fuzzel on the remote's Home key is a stopgap launcher until
quickshell. The mpv HDR toggle (`MANAGE_DISPLAY_HDR`) is off until it's
rewritten without kscreen-doctor. nvidia.nix gained the Hyprland-wiki
session variables and nvidia-vaapi-driver. The `disko` flake input still
needs `nix flake lock`. Next up: scripting and prototyping the quickshell UI.

Asher runs all `nix` commands (`nix flake check`, `nixos-rebuild`, etc.)
himself — edit files, then hand off for verification.

## Key decisions and the reasoning behind them

**Architecture is a strict pipeline**: Nix system config/drivers → Hyprland
(compositor) + quickshell (TV UI, planned) → content-source apps → one
shared mpv wrapper → Steam/Moonlight. The single most important structural decision:
every content source hands off to `mpv-htpc` (built in
`modules/media/mpv.nix`) instead of configuring mpv integration separately
per app. This means shader/HDR/interpolation config lives in exactly one
place instead of drifting out of sync across 5 different apps.

**Hyprland + quickshell replaced Plasma Bigscreen (2026-11-20).** Bigscreen
was picked in September because the box already ran KDE. It went to a black
screen after the 2026-11-19 commits (two shells fighting over
org.kde.plasmashell under SDDM), the rollback generation was black too, and
the root cause was never found. Asher wants freedom from KDE quirks
breaking features, so it's back to roughly the original plan: a barebones
compositor (Hyprland, matching Balthasar) with a quickshell UI modelled on
Bigscreen and other TV UIs, plus small scripts. No display manager on
purpose. Dropped with KDE: KDE Connect (phone remote, to be redesigned in
the quickshell phase), the KWin fullscreen rules (now Hyprland window
rules via `fullscreenApps`), and the portal pre-authorization. No HDMI-CEC
(would need a USB adapter, not wanted). FreeTube is to be swapped for
VacuumTube (flatpak) later.

**Content strategy is hybrid, weighted toward Stremio.** Debrid/TorBox died
as a viable option (TorBox rewrote its ToS in July 2026 to start collecting
IP/device/geolocation data — conflicts with Asher's privacy stack).
Decision: Stremio for one-off/won't-rewatch content via a **self-hosted
AIOStreams instance** (not ElfHosted managed, not the rate-limited public
one — full control, no rate limits); an Arr stack + Jellyfin for anything
he wants a permanent copy of (not yet built).

**AIOStreams will run on the HTPC itself**, not a separate home
server/NAS (neither exists yet — Melchior is still just planned). Tradeoff
accepted: it's only reachable when the HTPC is on. To avoid Stremio's
account-wide addon sync polluting his phone/laptop with unreachable
LAN-only sources, the plan is a **separate, dedicated Stremio account for
the HTPC** with only the self-hosted addon installed — phone/laptop use a
different account with either the plain TorBox/AllDebrid addon or the
public ElfHosted instance. This was chosen over setting up Tailscale
specifically to solve the sync-pollution problem, since it's a full fix
with near-zero setup cost. `modules/media/aiostreams.nix` runs it as a
podman container (not in nixpkgs) on **host networking**. That choice is
deliberate: with the killswitch on, traffic over podman's bridge interface
would be dropped. It generates its own SECRET_KEY on first start into
/var/lib/aiostreams, so it doesn't need sops.

**VPN: replacing the flatpak Proton VPN app with declarative WireGuard +
nftables**, for two reasons. (1) The flatpak app's killswitch toggle isn't
reproducible — wouldn't survive a fresh install from this flake. (2) It was
also causing a real chicken-and-egg bug: dead CMOS battery → clock resets
near-epoch on cold boot → fails TLS validation for the VPN handshake →
killswitch blocks NTP → clock never gets fixed. `modules/system/fake-hwclock.nix`
saves/restores the clock across reboots to break that loop (no killswitch
exception needed). `modules/network/protonvpn.nix` has the wg-quick
interface + deny-by-default nftables killswitch, plus a `lanSubnets`
option. Without it the killswitch would also block Moonlight→Balthasar,
LAN clients reaching Jellyfin, and the HDHomeRun. The VPN is enabled from
`hosts/htpc/secrets.nix`, which isn't imported until `secrets/htpc.yaml`
exists. Neither module has been tested against real hardware or network yet.
2026-11-20: `splitTunnel` added. `novpn <cmd>` runs a program as group
`novpn` (via `sg`). nftables gives that group's packets wg-quick's fwmark
(51820), so they route outside the tunnel. It also masquerades them and
lets them through the killswitch. The killswitch moved from
`networking.nftables.ruleset`, whose reload flushes every table including
wg-quick's own, to `networking.nftables.tables`.

**Secrets: sops-nix, not a gitignored local.nix.** The original plan was
a gitignored `hosts/htpc/local.nix`. That can't work: flakes only copy
git-tracked files into the store, so a gitignored file is invisible and
`pathExists` would silently skip it, leaving the VPN off with no error.
Replaced 2026-09-25 with sops-nix, using an age key at
`/var/lib/sops-nix/key.txt` rather than one derived from the SSH host key,
because the box doesn't run sshd. sops secrets are runtime *files*, so
modules only take secret *paths*. Values needed at evaluation time (VPN
endpoint IP, peer public key) aren't secret and sit as plain values in
secrets.nix. `modules/` doesn't depend on sops-nix, so flake-input users
can bring their own secrets tool.

**Every source goes through mpv-htpc, including plugins.**
`services.htpc.media.mpv.scripts` lets modules add mpv scripts (youtube.nix
adds SponsorBlock) instead of wrapping a second mpv. The IPTV, OTA and DVD
modules each ship a small launcher script (`iptv`, `ota-tv`, `dvd-play`)
that calls mpv-htpc. Apps with an external-player setting (Stremio,
FreeTube, jellyfin-mpv-shim) have to be pointed at mpv-htpc by hand on
first run, because their settings live in app state rather than in
declarable files.

**Reuse model: this repo supports two consumption patterns, deliberately.**
`flake.nix` exports both `nixosModules.default` (the reusable, hardware/host
-agnostic module bundle) and `nixosConfigurations.htpc` (this specific
machine). Someone can fork/clone the whole repo, or add it as a flake input
to their own flake and just import `nixosModules.default`. Both that
output and the host import `modules/default.nix`, so there's a single
module list to maintain. This is why
every module is gated behind its own `services.htpc.*.enable` option rather
than being unconditionally imported — cheap to import, inert unless
switched on.

**Stremio Enhanced runs on the native shell, built from source in
`pkgs/stremio-linux-shell-enhanced`** (switched 2026-11-19). REVENGE977 is
moving from the Electron stremio-enhanced to his fork of Stremio's Rust
stremio-linux-shell (GTK4 + WebKitGTK + libmpv), whose only release artifact
is a "Devel" flatpak bundle, so it's built here. The custom-packages flake
input (Electron AppImage) was dropped. Packaging lessons: WebKitGTK needs
`glib-networking` or every https request fails ("Load failed"), while the
UI still loads over plain http from the streaming server's proxy. Its mpv
config default is patched away from ~/.config/mpv/mpv.conf, because
force-window there aborts the embedded libmpv at startup. Its build.rs
npx call is replaced by nixpkgs esbuild. The wrapper is a shell wrapper
(dontWrapGApps + wrapProgramShell) because it needs --run. Plugins live in
`files/stremio-enhanced/`: MpvHandoffShell catches Stremio's IPC
`mpv-command loadfile` (webkit.messageHandlers.ipc), sends it to the
:7777 listener, skips Stremio's second :11470 copy of a direct link, and
backs out of the player when the listener's /status says mpv closed.
RemoteKeys maps Back/Search/List/Home (BrowserBack, BrowserSearch,
ContextMenu, BrowserHome in WebKit). New plugins start disabled, so a
home-manager activation step sets them on in settings.json with jq. The
shell only forwards console lines tagged `[Plugin]`/`[Enhanced]` to its
terminal, which is how the plugins log. `stremio.nix` keeps a `package`
option defaulting to plain `pkgs.stremio`. The plugins are deployed by a
home-manager module (`modules/home/stremio-enhanced.nix`, exported as
`homeManagerModules.stremio-enhanced`), and `mpvHandoff.player` picks the
player (mpv-htpc by default). Balthasar, the desktop, consumes this flake
(2026-11-20) for Stremio, handing off to plain mpv, and for the ProtonVPN
module. Its config is its own /etc/nixos flake, not in git. That makes
Balthasar the first real test of protonvpn.nix.

**Fred TV is a flatpak** (`dev.fredol.open-tv`, Fredolx's Open TV). It isn't
in nixpkgs, so it's installed with nix-flatpak, declared in
`hosts/htpc/default.nix`. It can't go in `iptv.nix`, because the flatpak
options only exist when nix-flatpak is imported and the reusable modules
must work without it. Known gap: the flatpak bundles its own sandboxed mpv,
so it bypasses mpv-htpc. The `iptv` launcher is the fallback that goes
through mpv-htpc.

**Asher's mpv config was ported 2026-09-26** from `~/projects/htpcref` (a
copy of the old HTPC's files). `auto_upscaler.lua` picks a profile by
resolution tier, HDR vs SDR, and 4:3 (4:3 gets the CRT shader). It used to
toggle KDE HDR via `kscreen-doctor`, now off (`MANAGE_DISPLAY_HDR = false`)
until a Hyprland version is written. The old custom mpv build (HopperRender
interpolation) was already disabled there, so it's dropped in favour of
nixpkgs mpv and mpv's built-in interpolation. See `files/mpv/README.md`.

## allowUnfree bug (found 2026-09-23 via `nix flake check`, fix committed 2026-09-25)

`nixpkgs.config.allowUnfree` was set on a `pkgs` variable in `flake.nix`'s
own `let` block — but `lib.nixosSystem` builds its own internal `pkgs` from
the *module system's* `nixpkgs.config` option, not from anything bound in
that outer `let`. The allowance never reached the actual system, so
`nixos-rebuild`/`nix flake check` refused to evaluate `nvidia-x11` (unfree
license). Fix: `nixpkgs.config.allowUnfree = true;` moved into
`hosts/htpc/default.nix` as a proper NixOS module option, and the dead
`pkgs` binding removed from `flake.nix` so it can't mislead anyone into
thinking it's doing something again. (The fix was originally described as
done on 2026-09-23 but never reached the repo. It was re-applied on
2026-09-25 and passed `nix flake check` that day.) **More bugs
are likely still in here, particularly in `modules/network/protonvpn.nix`'s
nftables ruleset, which is the most syntax-sensitive file in the repo and
the worst place to have a silent mistake.**

## What's still open (also in README.md, kept here for the same list twice
## since this file is what a fresh session reads first)

- `nix flake lock` (to add the sops-nix input) and then `nix flake check`
  on the 2026-09-25 module rough-in
- sops setup: generate the age keys, fill in `.sops.yaml`, create
  `secrets/htpc.yaml`, fill in the REPLACE-ME values in
  `hosts/htpc/secrets.nix`, and uncomment its import (README "Secrets setup")
- ProtonVPN real credentials + first real test of the killswitch module,
  including `lanSubnets`
- First-run in-app setup for Stremio (dedicated account + AIOStreams),
  FreeTube, jellyfin-mpv-shim, the Arr stack, Jellyfin Live TV, and MakeMKV
  (README "First-run manual steps")
- MakeMKV: `dvd.rip` turned off 2026-11-19 because nixpkgs' makemkv-oss 2.0.0
  fails with a hash mismatch. Turn it back on in hosts/htpc/default.nix once
  nixpkgs fixes it
- Reinstall with disko + Limine (README "Reinstall"): `nix flake lock` for
  the disko input first, then the first real boot of the Hyprland session.
  Check Limine's 5s menu actually waits (the old GRUB menu skipped its
  timeout; a wireless receiver sending a key was the suspect)
- Quickshell TV UI (launcher, overlays) to replace the fuzzel stopgap, and
  a phone-remote replacement for KDE Connect
- Rewrite the mpv HDR toggle for Hyprland (`MANAGE_DISPLAY_HDR` is off)
- Pin the AIOStreams container image (currently `:latest`)
- Stremio on the HTPC: first run of the native shell (login, AIOStreams,
  handoff to mpv-htpc with shaders, RemoteKeys getting Back/Home; Home is
  currently bound to fuzzel in Hyprland). All of it worked on the desktop 2026-11-19
- Chroma shaders now actually load (KrigBilateral live-action, CfL anime).
  They were silently ignored before, so watch for dropped frames at 4K on the 3070
- Fred TV flatpak bypasses mpv-htpc. Check whether it can call the host's mpv
- Low priority: a Jellyfin plugin that exposes the Jellyfin library inside
  Stremio (e.g. Jellio). Installed from Jellyfin's web UI, so the Nix side is small
- OTA: disabled, no tuner owned yet. Undecided between an HDHomeRun (about
  $80 used to $170. Network tuner that can sit upstairs by the router; works
  as-is with `ota-tv` and Jellyfin Live TV) and a USB tuner (about $30–40.
  Needs a TV backend run as a container, since nixpkgs removed Tvheadend).
  Picture quality is identical either way. If USB wins, ota.nix needs rework
- Jellyfin: jellyfin-mpv-shim is cast-only. Is a couch-browsable client wanted?

## Working conventions established so far

- nixos-unstable
- home-manager as a NixOS module (one `nixos-rebuild`, not a separate
  `home-manager switch`)
- Disk layout in `hosts/htpc/disko.nix` (reversed the old "no disko" rule
  2026-11-20); `hardware-configuration.nix` is generated with
  `--no-filesystems`
- Desktop config is Nix-generated (/etc/htpc/hyprland.lua), never
  ~/.config/hypr. Check Lua changes with `Hyprland --verify-config -c <file>`
- Every module: `services.htpc.<area>.<feature>.enable`, off by default
- Personal credentials and URLs are never committed in plaintext. They go in
  sops (`secrets/htpc.yaml`, encrypted), and modules take secret *file paths*
- New modules get added to `modules/default.nix`. Content sources hand off
  to mpv-htpc; mpv plugins go in `services.htpc.media.mpv.scripts`
- Asher runs all `nix` commands himself; Claude edits files only
- Eventually Balthasar (desktop) and Melchior (planned inference server)
  get the same multi-flake treatment as this repo, once this one's proven out
