# mpv config (files/mpv)

This directory is `--config-dir` for the shared `mpv-htpc` wrapper built by
`modules/media/mpv.nix`. Every content source (Stremio, IPTV, YouTube, OTA,
DVD playback) hands off to the *same* mpv invocation, so this directory is
the single place shader/HDR/interpolation config lives.

## To port over from the old install

Drop these in here, preserving structure:

- `mpv.conf` — base playback settings, HDR handling
- `input.conf` — remote/gamepad-friendly keybinds if any were added
- `shaders/` — CRT shader (`gavtroy.glsl`), any upscaling shaders
- `scripts/` — `auto_upscaler.lua` and anything else in `~/.config/mpv/scripts`
  on the old system

## Known open item

Lossless Scaling is being evaluated as a possible replacement for the
SVP-based interpolation setup — see the `htpc-pipeline` notes. If that
swap happens, it changes what belongs in `mpv.conf` vs. an external
frame-generation layer sitting in front of mpv entirely, so hold off
finalizing this directory's interpolation settings until that's decided.
