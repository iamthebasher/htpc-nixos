# htpc-nixos

Declarative NixOS config for a media-center PC: Plasma Bigscreen shell,
a single shared mpv playback wrapper feeding every content source, and
Steam/Moonlight for native sessions. Written to be reused — enable only the
pieces you want via `services.htpc.*` options.

## Status: scaffold, not yet installed anywhere

This is a from-scratch rewrite, written host-first as if for a fresh
install. Nothing here has been built or booted yet. Before using it on real
hardware:

1. Boot the NixOS installer (or your current install) on the target machine
   and run:
   ```
   sudo nixos-generate-config --show-hardware-config > hosts/htpc/hardware-configuration.nix
   ```
   This replaces the placeholder in that file — it's the one file in this
   repo that's inherently machine-specific and can't be written ahead of
   time (disk UUIDs, detected kernel modules).
2. Adjust `hosts/htpc/default.nix`: timezone, hostname if different,
   `system.stateVersion` to match whatever release you actually install
   from (never change it after the first rebuild).
3. Port real mpv config into `files/mpv/` — see `files/mpv/README.md`.
4. `sudo nixos-rebuild switch --flake .#htpc`

## Layout

```
flake.nix                          inputs + nixosModules.default + nixosConfigurations.htpc
hosts/htpc/
  default.nix                      host glue — imports modules, sets services.htpc.* toggles
  hardware-configuration.nix       PLACEHOLDER, regenerate on target hardware
modules/
  hardware/nvidia.nix              services.htpc.hardware.nvidia.enable
  desktop/bigscreen.nix            services.htpc.desktop.bigscreen.enable
  media/mpv.nix                    services.htpc.media.mpv.enable — the shared wrapper
  media/stremio.nix                services.htpc.media.stremio.enable
  media/gaming.nix                 services.htpc.gaming.{steam,moonlight}.enable
  system/fake-hwclock.nix          services.htpc.system.fakeHwclock.enable — clock save/restore for dead-RTC hardware
  network/protonvpn.nix            services.htpc.network.protonvpn.enable — declarative WireGuard + nftables killswitch
home/default.nix                   home-manager module (imported as a NixOS module, one rebuild does both)
files/mpv/                         mpv config dir referenced by modules/media/mpv.nix
```

## VPN setup (ProtonVPN via WireGuard, replacing the flatpak app)

The flatpak Proton VPN app's killswitch toggle isn't reproducible — a fresh
install from this flake wouldn't have it on until you open the app and flip
it by hand. `modules/network/protonvpn.nix` replaces it with a native
`wg-quick` interface plus a deny-by-default nftables killswitch, both
declared in Nix.

It also fixes the actual chicken-and-egg bug that motivated the switch:
with a dead CMOS battery, the clock resets toward epoch on cold boot, which
fails TLS validation for the WireGuard handshake, which — under an
always-on killswitch — blocks the NTP traffic that would've fixed the clock.
`modules/system/fake-hwclock.nix` breaks that loop by saving the clock on
shutdown (and every 5 min, for unclean shutdowns) and restoring it early at
boot, before the VPN handshake or timesyncd run — no killswitch exception
needed, no dependency on the RTC hardware being healthy. Replacing the CMOS
battery is still worth doing, but this means you're not blocked on it.

To actually turn the VPN module on:

1. Get a WireGuard config from ProtonVPN's account dashboard (config
   generator, not the app) — from it, you need `PrivateKey`, the peer's
   `PublicKey`, `Endpoint`, and your `Address`.
2. Save the private key to its own file, outside the repo (or behind
   sops-nix/agenix once that's set up), e.g. `/etc/nixos-secrets/protonvpn-key`.
3. Create `hosts/htpc/local.nix` (gitignored, auto-imported if present):
   ```nix
   { ... }:
   {
     services.htpc.network.protonvpn = {
       enable = true;
       interfaceAddress = "10.2.0.2/32";       # from the config export
       privateKeyFile = "/etc/nixos-secrets/protonvpn-key";
       peerPublicKey = "...";                   # from the config export
       endpoint = "146.70.xxx.xxx:51820";       # from the config export
     };
   }
   ```
4. `sudo nixos-rebuild switch --flake .#htpc`

The killswitch only allows: loopback, established/related connections, DHCP,
the initial handshake to the VPN endpoint itself, and anything over the
`protonvpn` interface. No blanket NTP exception — `fake-hwclock` is what
removes the need for one. If it's ever insufficient on its own, add a
narrow `udp dport 123 ip daddr <server> accept` line to the ruleset rather
than opening NTP broadly.

Every module under `modules/` is off by default and gated behind its own
`services.htpc.*.enable` — that's deliberate, so someone cloning this repo
turns on only what they want instead of inheriting the whole stack.

## Using this repo without forking it

Two ways to consume this, pick one:

- **Fork/clone** — copy the whole repo, add your own `hosts/<name>/`
  directory, leave `modules/` untouched. Pull from upstream later for fixes
  and new modules; as long as you never edit files under `modules/`
  yourself, that stays a clean `git pull` with no merge conflicts.
- **Flake input** — add this repo as a dependency of your own flake instead
  of cloning it:
  ```nix
  inputs.htpc-nixos.url = "github:yourname/htpc-nixos";
  # then, in your own nixosSystem's modules list:
  modules = [ inputs.htpc-nixos.nixosModules.default ./hosts/yourhost ... ];
  ```
  and set whichever `services.htpc.*.enable` flags you want from your own
  host file — same as `hosts/htpc/default.nix` does below, just from
  outside this repo. Updating is `nix flake update htpc-nixos`, with zero
  risk of merge conflicts since you never touch this repo's files directly.
  This is the cleaner option if you're building your own flake from scratch
  and just want the media-center pieces.

Known wrinkle either way: `home/default.nix` currently hardcodes the
`htpc` username (`home-manager.users.htpc = ...`). If your user is named
differently, that needs adjusting — hasn't been made configurable yet.

## Not yet built out

Per the running brainstorm, these are still open and don't have modules yet:
- DVD rip/play (makemkv/handbrake -> NAS)
- IPTV (Fred TV) playlist + mpv handoff
- YouTube frontend (FreeTube vs. self-hosted Invidious/Piped) with SponsorBlock
- OTA antenna tuner (HDHomeRun + Tvheadend, likely) -> mpv handoff
- Arr stack + Jellyfin for the "want a kept copy" half of the content strategy
- Self-hosted AIOStreams instance — intentionally lives on separate home-server
  infra, not in this repo, so this stays credential-free and publishable
- Confirm the old config's `stremio-enhanced` usage (no official Nix packaging
  exists upstream — check whether it's a custom flake input or was ever
  actually declarative) and decide whether to port it or drop back to plain
  `stremio`
- secrets management (sops-nix/agenix) — needed properly once the VPN private
  key and any future credentials move off ad-hoc root-only files

## Design notes

- **nixos-unstable**, pinned via flake input — needed for Plasma 6.7/Bigscreen.
- **home-manager as a NixOS module** — one `nixos-rebuild switch`, no separate
  `home-manager switch` to remember.
- **hardware-configuration.nix stays manual** (not disko) — conventional
  install flow, generated once per machine.
- Every content-source module should hand off to
  `${config.services.htpc.media.mpv.package}/bin/mpv-htpc` rather than raw
  `mpv`, so shader/HDR/interpolation config only lives in one place
  (`files/mpv/`).
