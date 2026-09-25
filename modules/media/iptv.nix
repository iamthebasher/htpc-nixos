{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.iptv;
  mpv = config.services.htpc.media.mpv;

  # Reads the playlist URL at runtime rather than baking it into the store —
  # IPTV provider URLs usually embed a username/password.
  iptv = pkgs.writeShellScriptBin "iptv" ''
    exec ${mpv.package}/bin/mpv-htpc "$(cat ${escapeShellArg cfg.playlistUrlFile})" "$@"
  '';
in
{
  options.services.htpc.media.iptv = {
    enable = mkEnableOption "an `iptv` launcher that plays an M3U playlist through mpv-htpc";

    playlistUrlFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/iptv-playlist-url";
      description = ''
        Path to a file containing only the M3U playlist URL. Should be a sops
        secret readable by the HTPC user — see hosts/htpc/secrets.nix.
      '';
    };
  };

  # NOTE: Fred TV (the old setup's IPTV app) is Apple-only, so there's no
  # direct port. mpv playing the M3U works but channel switching is just
  # playlist next/prev. TODO: decide whether that's enough or whether a
  # guide-style Linux client (e.g. Hypnotix) is worth adding on top.
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = mpv.enable;
        message = "services.htpc.media.iptv requires services.htpc.media.mpv.enable = true.";
      }
      {
        assertion = cfg.playlistUrlFile != null;
        message = "services.htpc.media.iptv.playlistUrlFile must be set (point it at a sops secret).";
      }
    ];

    environment.systemPackages = [ iptv ];
  };
}
