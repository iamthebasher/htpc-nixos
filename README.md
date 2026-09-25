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
   from (never change it after the first rebuild), and turn off any
   `services.htpc.*` toggles for hardware you don't have (e.g. `ota`).
3. Port real mpv config into `files/mpv/` — see `files/mpv/README.md`.
4. Set up secrets — see [Secrets setup](#secrets-setup-sops-nix).
5. `sudo nixos-rebuild switch --flake .#htpc`

## Layout

```
flake.nix                          inputs + nixosModules.default + nixosConfigurations.htpc
.sops.yaml                         which age keys can decrypt which secrets file
secrets/htpc.yaml                  encrypted secrets (create it — see Secrets setup)
hosts/htpc/
  default.nix                      host glue — imports modules, sets services.htpc.* toggles
  secrets.nix                      sops secrets + the modules that need them (VPN, IPTV)
  hardware-configuration.nix       PLACEHOLDER, regenerate on target hardware
modules/
  default.nix                      the full module list (used by the host and nixosModules.default)
  hardware/nvidia.nix              services.htpc.hardware.nvidia.enable
  desktop/bigscreen.nix            services.htpc.desktop.bigscreen.enable
  media/mpv.nix                    services.htpc.media.mpv.enable — the shared wrapper
  media/library.nix                services.htpc.media.library.{dir,group} — shared /srv/media + group
  media/stremio.nix                services.htpc.media.stremio.enable
  media/aiostreams.nix             services.htpc.media.aiostreams.enable — self-hosted addon (container)
  media/arr.nix                    services.htpc.media.arr.enable — Sonarr/Radarr/Prowlarr/Transmission (+Bazarr)
  media/jellyfin.nix               services.htpc.media.jellyfin.{server,client}.enable
  media/iptv.nix                   services.htpc.media.iptv.enable — M3U playlist -> mpv-htpc
  media/youtube.nix                services.htpc.media.youtube.enable — FreeTube + SponsorBlock
  media/dvd.nix                    services.htpc.media.dvd.{play,rip}.enable
  media/ota.nix                    services.htpc.media.ota.enable — HDHomeRun lineup -> mpv-htpc
  media/gaming.nix                 services.htpc.gaming.{steam,moonlight}.enable
  system/fake-hwclock.nix          services.htpc.system.fakeHwclock.enable — clock save/restore for dead-RTC hardware
  network/protonvpn.nix            services.htpc.network.protonvpn.enable — declarative WireGuard + nftables killswitch
home/default.nix                   home-manager module (imported as a NixOS module, one rebuild does both)
files/mpv/                         mpv config dir referenced by modules/media/mpv.nix
```

## Secrets setup (sops-nix)

Secrets are committed to the repo *encrypted* (`secrets/htpc.yaml`) and
decrypted at activation into `/run/secrets/<name>`. Modules only ever
receive the file path, never the value, so nothing secret lands in the Nix
store. Anything a module needs as a plain string at evaluation time (like
the VPN endpoint IP) can't be a sops secret — those are ordinary values in
`hosts/htpc/secrets.nix`.

One-time setup:

1. **Your personal age key** (on whatever machine you edit secrets from):
   ```
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   Put the printed public key (`age1...`) in `.sops.yaml` as `asher`.
2. **The HTPC's key** (on the HTPC):
   ```
   sudo mkdir -p /var/lib/sops-nix
   sudo age-keygen -o /var/lib/sops-nix/key.txt
   ```
   Put its public key in `.sops.yaml` as `htpc`.
3. **Create the secrets file** — `sops secrets/htpc.yaml` opens an editor;
   write plain YAML and sops encrypts on save:
   ```yaml
   protonvpn-private-key: <PrivateKey from ProtonVPN's WireGuard export>
   iptv-playlist-url: <full M3U URL from your IPTV provider>
   ```
4. Fill in the `REPLACE-ME` values in `hosts/htpc/secrets.nix`, uncomment
   `./secrets.nix` in `hosts/htpc/default.nix`, and `git add` the new
   files (flakes only see files git tracks).

Keep backups of both private keys. Losing both means re-creating every secret.

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

To turn it on:

1. Get a WireGuard config from ProtonVPN's account dashboard (config
   generator, not the app). You need `PrivateKey`, the peer's `PublicKey`,
   `Endpoint` (must be an IP), and your `Address`.
2. Put `PrivateKey` in `secrets/htpc.yaml` as `protonvpn-private-key` (see
   Secrets setup) and the other three in `hosts/htpc/secrets.nix`.
3. Set `lanSubnets` in `hosts/htpc/secrets.nix` to your real home subnet.
4. `sudo nixos-rebuild switch --flake .#htpc`

The killswitch only allows: loopback, established/related connections, DHCP,
the initial handshake to the VPN endpoint itself, `lanSubnets`, and anything
over the `protonvpn` interface. `lanSubnets` is what lets Moonlight reach
Balthasar, other devices reach Jellyfin, and this box reach the HDHomeRun —
without it, the killswitch blocks the LAN too. No blanket NTP exception —
`fake-hwclock` is what removes the need for one. If it's ever insufficient
on its own, add a narrow `udp dport 123 ip daddr <server> accept` line to
the ruleset rather than opening NTP broadly. IPv4 only for now.

Every module under `modules/` is off by default and gated behind its own
`services.htpc.*.enable` — that's deliberate, so someone cloning this repo
turns on only what they want instead of inheriting the whole stack.

## First-run manual steps

Some apps keep their settings in their own state, not in files Nix can
declare. Each module has a comment with details; the short list:

- **Stremio**: log in with the HTPC-only account; set External player to
  `/run/current-system/sw/bin/mpv-htpc`; install the AIOStreams manifest
  from `http://localhost:3000`.
- **FreeTube**: Settings → External Player → mpv, custom executable `mpv-htpc`.
- **jellyfin-mpv-shim**: `mpv_ext: true`, `mpv_ext_path` → `mpv-htpc` in its `conf.json`.
- **Arr stack**: connect Prowlarr → Sonarr/Radarr, add Transmission as the
  download client, set root folders under `/srv/media`.
- **OTA TV**: `ota-tv` works as soon as the tuner has scanned channels. For
  guide/DVR, add the HDHomeRun in Jellyfin (Dashboard → Live TV). With the
  VPN on, set `services.htpc.media.ota.tunerAddress` — discovery is broadcast
  and the killswitch blocks it.
- **MakeMKV**: enter the beta key (Help → Register).

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
  host file — same as `hosts/htpc/default.nix` does, just from outside this
  repo. Updating is `nix flake update htpc-nixos`, with zero risk of merge
  conflicts since you never touch this repo's files directly. The modules
  don't depend on sops-nix — secret options just take file paths, so use
  whatever secrets tool you like.

Known wrinkle either way: `home/default.nix` currently hardcodes the
`htpc` username (`home-manager.users.htpc = ...`), as does
`hosts/htpc/secrets.nix` (IPTV secret owner). If your user is named
differently, adjust those — hasn't been made configurable yet.

## Still open

- Everything above is roughed in, not tested — first real build/boot pending
- stremio-enhanced (from the `custom-packages` flake input) → mpv handoff:
  port the old setup's custom plugin, pointed at `mpv-htpc`
- Real mpv config (per-resolution/colourspace shader profiles) → `files/mpv/`
- AIOStreams image is `:latest` — pin a release once it's running
- IPTV: Fred TV is a flatpak with its own sandboxed mpv, so it bypasses
  `mpv-htpc`. See if it can be pointed at the host's `mpv-htpc`
- Jellyfin: jellyfin-mpv-shim is cast-only; decide whether a couch-browsable
  client is wanted too
- DVD: rips land in `/srv/media/dvd-rips` and are moved by hand — automate later?

## Design notes

- **nixos-unstable**, pinned via flake input — needed for Plasma 6.7/Bigscreen.
- **home-manager as a NixOS module** — one `nixos-rebuild switch`, no separate
  `home-manager switch` to remember.
- **hardware-configuration.nix stays manual** (not disko) — conventional
  install flow, generated once per machine.
- Every content-source module should hand off to
  `${config.services.htpc.media.mpv.package}/bin/mpv-htpc` rather than raw
  `mpv`, so shader/HDR/interpolation config only lives in one place
  (`files/mpv/`). mpv plugins go in `services.htpc.media.mpv.scripts`.
