{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.jellyfin;
  mpv = config.services.htpc.media.mpv;
in
{
  options.services.htpc.media.jellyfin = {
    server.enable = mkEnableOption "Jellyfin server for the kept-copy library (web UI on :8096)";

    client.enable = mkEnableOption ''
      jellyfin-mpv-shim, which plays Jellyfin content through mpv-htpc so
      the same shader/HDR config applies as every other source
    '';
  };

  config = mkMerge [
    (mkIf cfg.server.enable {
      services.jellyfin.enable = true;

      # library read access + GPU transcoding (NVENC/NVDEC via the nvidia module)
      users.users.jellyfin.extraGroups = [
        config.services.htpc.media.library.group
        "video"
        "render"
      ];
    })

    (mkIf cfg.client.enable {
      assertions = [{
        assertion = mpv.enable;
        message = "services.htpc.media.jellyfin.client requires services.htpc.media.mpv.enable = true (external-player handoff target).";
      }];

      environment.systemPackages = [ pkgs.jellyfin-mpv-shim ];

      # jellyfin-mpv-shim is a cast target (pick "play on HTPC" from the
      # Jellyfin web UI or phone app), not a 10-foot browsing UI. To route it
      # through mpv-htpc, set in ~/.config/jellyfin-mpv-shim/conf.json:
      #   "mpv_ext": true,
      #   "mpv_ext_path": "/run/current-system/sw/bin/mpv-htpc"
      # TODO: decide whether a couch-browsable client (Jellyfin Media
      # Player) is wanted too, and whether it can be pointed at mpv-htpc.
    })
  ];
}
