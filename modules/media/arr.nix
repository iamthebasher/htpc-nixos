{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.arr;
  lib' = config.services.htpc.media.library;
in
{
  options.services.htpc.media.arr = {
    enable = mkEnableOption ''
      the Arr stack (Sonarr, Radarr, Prowlarr + Transmission) for the
      "keep a copy" half of the content strategy
    '';

    bazarr.enable = mkEnableOption "Bazarr for subtitles";
  };

  # Web UIs once running (configure indexers/download client/root folders
  # there — the Arr apps keep that state in their own databases, not in Nix):
  #   Sonarr  :8989   root folder ${library}/tv
  #   Radarr  :7878   root folder ${library}/movies
  #   Prowlarr:9696
  #   Bazarr  :6767
  #   Transmission RPC :9091
  #
  # No per-service VPN plumbing: with services.htpc.network.protonvpn on,
  # the whole machine's traffic is already forced through the tunnel.
  config = mkIf cfg.enable (mkMerge [
    {
      services.sonarr.enable = true;
      services.radarr.enable = true;
      services.prowlarr.enable = true;

      services.transmission = {
        enable = true;
        settings = {
          download-dir = "${lib'.dir}/downloads";
          incomplete-dir-enabled = false;
          umask = 2; # 002 — group-writable, so Sonarr/Radarr can move finished files
          rpc-bind-address = "127.0.0.1";
        };
      };

      users.users.sonarr.extraGroups = [ lib'.group ];
      users.users.radarr.extraGroups = [ lib'.group ];
      users.users.transmission.extraGroups = [ lib'.group ];
    }

    (mkIf cfg.bazarr.enable {
      services.bazarr.enable = true;
      users.users.bazarr.extraGroups = [ lib'.group ];
    })
  ]);
}
