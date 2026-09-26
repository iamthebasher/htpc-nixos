# mpv config (files/mpv)

This directory is `--config-dir` for the shared `mpv-htpc` wrapper built by
`modules/media/mpv.nix`. Every content source (Stremio, IPTV, YouTube, OTA,
DVD playback, Jellyfin) hands off to the *same* mpv invocation, so this
directory is the single place shader/HDR/interpolation config lives.

Ported from the old HTPC's `~/.config/mpv` on 2026-09-26.

## How it works

- `mpv.conf` — global defaults plus one profile per
  `{youtube_,}{upscale,anime}_{480,720,1080,native}{,_crt}` combination.
- `scripts/auto_upscaler.lua` picks the profile on every file load: by
  resolution tier (height for 4:3, width for widescreen), SDR vs HDR (from
  the transfer tag), 4:3 → CRT shader (`gavtroy`), YouTube → `youtube_*`.
  `a` toggles anime (ArtCNN + CfL) vs live-action. It also switches KDE's
  HDR/WCG off for CRT content and back on at exit via `kscreen-doctor`
  (`DISPLAY_OUTPUT = "HDMI-A-1"` — check with `kscreen-doctor -o` on the HTPC).
- `scripts/modernx.lua` + `fonts/` — ModernX on-screen controller (`osc=no`
  in mpv.conf disables the stock one).
- SponsorBlock comes from nixpkgs (`pkgs.mpvScripts.sponsorblock`, added by
  `modules/media/youtube.nix`), not vendored here. Its options are in
  `script-opts/sponsorblock.conf`.
- Interpolation is mpv's built-in (`interpolation=yes`, `tscale=oversample`).
  The old setup's custom mpv build with HopperRender, and SVP before that,
  were both already disabled and aren't ported.

## Changing things

This directory is copied into the Nix store, which is read-only. Tweaks
mean edit here → rebuild, not editing `~/.config/mpv` live. To experiment
without rebuilding, run `mpv --config-dir=/path/to/a/writable/copy`.

## Known issues (found while porting, not fixed)

- The `upscale_480` comment mentions `FSR_EASU.glsl`/`FSR_RCAS.glsl`, which
  don't exist here — only the combined `FSR.glsl`.
- Fixed while porting: the anime profiles referenced `CFL_Prediction_Lite.glsl`
  but the file is `CfL_Prediction_Lite.glsl` (case-sensitive), so that
  shader never loaded before.
- Fixed while porting: `cscale=KrigBilateral` / `cscale=CFL_Predictive`
  were invalid (`cscale` only takes built-in scalers), so mpv ignored them
  and used its default chroma scaling. KrigBilateral is now appended to
  each non-anime profile's `glsl-shaders`. The anime profiles already
  loaded CfL there, so their `cscale` lines were just removed. Both are
  heavier on the GPU than before, so watch for dropped frames at 4K.
- SponsorBlock stores a user ID file next to its script. From the read-only
  Nix store it may fail to write — check it skips segments on first test.
- `shaders/` is third-party. Each file carries its own license header
  (MIT/LGPL etc.). Six unused shaders with no license text were dropped
  rather than redistributed: adaptive-sharpen, filmgrain, noise_static_*.
