# Project context (auto-read by Claude Code at session start)

This is Asher's ground-up rewrite of his HTPC's NixOS config — the old one
is out of date and messy. Goal: reproducible enough to publish on GitHub
for others to use as a template or flake input. This file exists so a new
session doesn't have to be re-briefed from scratch; see README.md for
structural/how-to details, this file for *why* things are the way they are.

## Status as of 2026-09-25

Scaffold pushed to `github.com/iamthebasher/htpc-nixos`. The allowUnfree fix
(below) passed `nix flake check` on 2026-09-25 (evaluation only, nothing
built). Later that day, sops-nix and rough drafts of every remaining
content module were added (AIOStreams, Arr, Jellyfin, IPTV, YouTube, DVD,
OTA). **Those haven't been through `nix flake check` yet** and nothing has
been built or tested on real hardware. Hardware- and device-specific details
(subnets, tuner, endpoint IPs) are placeholders, to be fixed once the config
is on the HTPC.

Asher runs all `nix` commands (`nix flake check`, `nixos-rebuild`, etc.)
himself — edit files, then hand off for verification.

## Key decisions and the reasoning behind them

**Architecture is a strict pipeline**: Nix system config/drivers → Plasma
Bigscreen (compositor+launcher) → content-source apps → one shared mpv
wrapper → Steam/Moonlight. The single most important structural decision:
every content source hands off to `mpv-htpc` (built in
`modules/media/mpv.nix`) instead of configuring mpv integration separately
per app. This means shader/HDR/interpolation config lives in exactly one
place instead of drifting out of sync across 5 different apps.

**Plasma Bigscreen was chosen over eww+compositor+wallpaper-engine.**
Original plan was a from-scratch compositor with eww as a launcher over a
wallpaper engine. Switched to Plasma Bigscreen because the HTPC already
runs KDE (for the existing mpv/SVP pipeline), and Bigscreen is now a
first-class, stable Plasma module (shipped stable with Plasma 6.7, June
2026, currently 6.7.4) rather than the dormant/beta project it used to be.
Tradeoff noted: nixpkgs doesn't yet expose a one-line
`services.desktopManager.plasma6-bigscreen.enable` option, so
`modules/desktop/bigscreen.nix` wires the SDDM session manually — worth
rechecking nixpkgs periodically in case that's landed.

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

**stremio-enhanced comes from a third-party flake.** It isn't packaged in
nixpkgs. Decided 2026-09-25: port the old config's source,
`github:Rishabh5321/custom-packages-flake` (the `custom-packages` input,
following our nixpkgs, with no binary cache). `stremio.nix` has a `package`
option that defaults to plain `pkgs.stremio`. Only the host swaps in
stremio-enhanced, so the module doesn't depend on the input. The old setup
also has a custom Stremio plugin that hands stremio-enhanced playback to
mpv. Asher will supply it; port it and point it at mpv-htpc.

**Fred TV is a flatpak** (`dev.fredol.open-tv`, Fredolx's Open TV). It isn't
in nixpkgs, so it's installed with nix-flatpak, declared in
`hosts/htpc/default.nix`. It can't go in `iptv.nix`, because the flatpak
options only exist when nix-flatpak is imported and the reusable modules
must work without it. Known gap: the flatpak bundles its own sandboxed mpv,
so it bypasses mpv-htpc. The `iptv` launcher is the fallback that goes
through mpv-htpc.

**Asher has his own mpv config** to supply. It has per-resolution and
per-colourspace shader profiles, and it goes in `files/mpv/`.

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
  FreeTube, jellyfin-mpv-shim, the Arr stack, Tvheadend, and MakeMKV
  (README "First-run manual steps")
- Pin the AIOStreams container image (currently `:latest`)
- stremio-enhanced → mpv handoff plugin (waiting on Asher to supply the old one)
- Asher's real mpv config (waiting on Asher to supply it)
- Fred TV flatpak bypasses mpv-htpc. Check whether it can call the host's mpv
- Jellyfin plugins for Stremio: Asher mentioned these. What they should be
  used for hasn't been pinned down yet
- Jellyfin: jellyfin-mpv-shim is cast-only. Is a couch-browsable client wanted?
- `hosts/htpc/hardware-configuration.nix` is still a placeholder — needs
  `nixos-generate-config` run on the real HTPC
- Nothing has been rebuilt/booted on the actual HTPC yet

## Working conventions established so far

- nixos-unstable (needed for Plasma 6.7)
- home-manager as a NixOS module (one `nixos-rebuild`, not a separate
  `home-manager switch`)
- `hardware-configuration.nix` stays manually generated, not disko
- Every module: `services.htpc.<area>.<feature>.enable`, off by default
- Personal credentials and URLs are never committed in plaintext. They go in
  sops (`secrets/htpc.yaml`, encrypted), and modules take secret *file paths*
- New modules get added to `modules/default.nix`. Content sources hand off
  to mpv-htpc; mpv plugins go in `services.htpc.media.mpv.scripts`
- Asher runs all `nix` commands himself; Claude edits files only
- Eventually Balthasar (desktop) and Melchior (planned inference server)
  get the same multi-flake treatment as this repo, once this one's proven out
