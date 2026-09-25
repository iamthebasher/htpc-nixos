# Project context (auto-read by Claude Code at session start)

This is Asher's ground-up rewrite of his HTPC's NixOS config — the old one
is out of date and messy. Goal: reproducible enough to publish on GitHub
for others to use as a template or flake input. This file exists so a new
session doesn't have to be re-briefed from scratch; see README.md for
structural/how-to details, this file for *why* things are the way they are.

## Status as of 2026-09-25

Scaffold written and pushed to `github.com/iamthebasher/htpc-nixos`. The
allowUnfree fix (below) and `.gitignore` were added 2026-09-25 but have
**not yet been verified with `nix flake check`**. Nothing has been
build-tested on real hardware yet. No content-source modules exist yet
beyond Stremio.

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
with near-zero setup cost. AIOStreams module itself isn't written yet.

**VPN: replacing the flatpak Proton VPN app with declarative WireGuard +
nftables**, for two reasons. (1) The flatpak app's killswitch toggle isn't
reproducible — wouldn't survive a fresh install from this flake. (2) It was
also causing a real chicken-and-egg bug: dead CMOS battery → clock resets
near-epoch on cold boot → fails TLS validation for the VPN handshake →
killswitch blocks NTP → clock never gets fixed. `modules/system/fake-hwclock.nix`
saves/restores the clock across reboots to break that loop (no killswitch
exception needed). `modules/network/protonvpn.nix` has the wg-quick
interface + deny-by-default nftables killswitch. **Not yet enabled** —
needs real credentials from ProtonVPN's WireGuard config export, supplied
via a gitignored `hosts/htpc/local.nix` (same pattern as the Stremio addon
URL — keeps the published repo credential-free). Neither module has been
tested against real hardware/network yet. See the open issue below about
flakes not seeing gitignored files.

**Reuse model: this repo supports two consumption patterns, deliberately.**
`flake.nix` exports both `nixosModules.default` (the reusable, hardware/host
-agnostic module bundle) and `nixosConfigurations.htpc` (this specific
machine). Someone can fork/clone the whole repo, or add it as a flake input
to their own flake and just import `nixosModules.default`. This is why
every module is gated behind its own `services.htpc.*.enable` option rather
than being unconditionally imported — cheap to import, inert unless
switched on.

**stremio-enhanced is not officially packaged for Nix anywhere.** Confirmed
the old HTPC config pulls it from a third-party flake repo, not nixpkgs.
Not yet decided whether to port that third-party input or drop back to
plain `stremio` (already in nixpkgs).

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
done on 2026-09-23 but never reached the repo; it was re-applied on
2026-09-25 and still needs a `nix flake check` to confirm it.) **More bugs
are likely still in here, particularly in `modules/network/protonvpn.nix`'s
nftables ruleset, which is the most syntax-sensitive file in the repo and
the worst place to have a silent mistake.**

## What's still open (also in README.md, kept here for the same list twice
## since this file is what a fresh session reads first)

- **Gitignored `local.nix` is invisible to the flake.** Flakes in a git repo
  only copy tracked files into the store, so `builtins.pathExists ./local.nix`
  in `hosts/htpc/default.nix` is always false. The VPN and Stremio addon
  overrides would be skipped without any error. Needs a different approach
  (sops-nix/agenix, or a path outside the repo) before the VPN is enabled.
- Run `nix flake check` to verify the 2026-09-25 allowUnfree fix
- IPTV (Fred TV), YouTube frontend, DVD rip/play, OTA antenna — no modules yet
- Arr stack + Jellyfin for the "keep a copy" half of content strategy
- AIOStreams module + the dual-Stremio-account setup
- ProtonVPN real credentials + first real test of the killswitch module
- stremio-enhanced: port the third-party input, or drop it for plain stremio
- secrets management (sops-nix/agenix) — currently a placeholder root-only
  file for the VPN private key
- `hosts/htpc/hardware-configuration.nix` is still a placeholder — needs
  `nixos-generate-config` run on the real HTPC
- Real mpv shader/HDR config not yet ported into `files/mpv/`
- Nothing has been rebuilt/booted on the actual HTPC yet

## Working conventions established so far

- nixos-unstable (needed for Plasma 6.7)
- home-manager as a NixOS module (one `nixos-rebuild`, not a separate
  `home-manager switch`)
- `hardware-configuration.nix` stays manually generated, not disko
- Every module: `services.htpc.<area>.<feature>.enable`, off by default
- Personal credentials/URLs never committed — gitignored `hosts/htpc/local.nix`
  (but see the open issue above: the flake can't currently see it)
- Asher runs all `nix` commands himself; Claude edits files only
- Eventually Balthasar (desktop) and Melchior (planned inference server)
  get the same multi-flake treatment as this repo, once this one's proven out
