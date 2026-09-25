{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.youtube;
  mpv = config.services.htpc.media.mpv;
in
{
  options.services.htpc.media.youtube = {
    enable = mkEnableOption "FreeTube as the YouTube frontend, handing playback to mpv-htpc";

    sponsorblock = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Add the SponsorBlock mpv script to mpv-htpc. FreeTube has its own
        SponsorBlock, but it only applies to FreeTube's built-in player —
        once playback is handed to mpv, mpv has to skip segments itself.
      '';
    };
  };

  # FreeTube over self-hosted Invidious/Piped: nothing to host or keep
  # alive, and no Google account needed. Revisit if FreeTube's
  # scraping breaks for long stretches.
  config = mkIf cfg.enable {
    assertions = [{
      assertion = mpv.enable;
      message = "services.htpc.media.youtube requires services.htpc.media.mpv.enable = true.";
    }];

    environment.systemPackages = [ pkgs.freetube ];

    services.htpc.media.mpv.scripts = mkIf cfg.sponsorblock [ pkgs.mpvScripts.sponsorblock ];

    # FreeTube's external player is set by hand the first time:
    # Settings -> External Player -> Player: mpv,
    # Custom executable: /run/current-system/sw/bin/mpv-htpc
    # (mpv-htpc resolves YouTube URLs itself — nixpkgs' mpv ships yt-dlp.)
  };
}
