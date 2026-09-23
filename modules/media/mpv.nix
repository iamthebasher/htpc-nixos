{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.mpv;

  # The single, shared mpv entrypoint every content-source module should call
  # instead of raw `mpv`. This is the architectural point of this module:
  # shaders/HDR/interpolation config lives in exactly one place, so every
  # source (Stremio, IPTV, YouTube, OTA, DVD playback) stays in sync for free.
  mpvHtpc = pkgs.writeShellScriptBin "mpv-htpc" ''
    exec ${pkgs.mpv}/bin/mpv \
      --config-dir=${cfg.configDir} \
      ${escapeShellArgs cfg.extraFlags} \
      "$@"
  '';
in
{
  options.services.htpc.media.mpv = {
    enable = mkEnableOption "the shared mpv-htpc playback wrapper (shaders, HDR, interpolation)";

    configDir = mkOption {
      type = types.path;
      default = ../../files/mpv;
      description = ''
        Path to the mpv config directory (mpv.conf, input.conf, shaders/,
        scripts/) used by every source module's handoff. Point this at the
        existing shader/HDR config being ported over from the old install —
        see files/mpv/README.md.
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--hwdec=nvdec" "--fullscreen" ];
      description = "Extra flags appended to every mpv-htpc invocation.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ mpvHtpc pkgs.mpv ];
  };

  # Exposed so other modules (stremio.nix, iptv.nix, etc.) can reference the
  # built wrapper directly, e.g. "${config.services.htpc.media.mpv.package}/bin/mpv-htpc"
  options.services.htpc.media.mpv.package = mkOption {
    type = types.package;
    readOnly = true;
    default = mpvHtpc;
    description = "The built mpv-htpc wrapper package.";
  };
}
