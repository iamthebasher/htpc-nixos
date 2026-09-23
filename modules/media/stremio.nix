{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.stremio;
in
{
  options.services.htpc.media.stremio = {
    enable = mkEnableOption "Stremio client, configured to hand off playback to mpv-htpc";

    addonUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://homelab.local:11470/manifest.json";
      description = ''
        Manifest URL of a self-hosted AIOStreams instance (or any other addon
        endpoint). Left null by default so this repo carries no personal
        infra details — set it in your own host config, not here.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.htpc.media.mpv.enable;
        message = "services.htpc.media.stremio requires services.htpc.media.mpv.enable = true (external-player handoff target).";
      }
    ];

    environment.systemPackages = [ pkgs.stremio ];

    # Stremio's "external player" setting must be pointed at mpv-htpc by hand
    # in-app (Settings -> Player -> External player command) the first time
    # it's launched — there's no config-file toggle nixpkgs exposes for this
    # yet. Point it at: ${config.services.htpc.media.mpv.package}/bin/mpv-htpc
  };
}
