{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.gaming;
in
{
  options.services.htpc.gaming = {
    steam.enable = mkEnableOption "Steam, with gamescope session and 32-bit graphics support";
    moonlight.enable = mkEnableOption "Moonlight client for streaming from Balthasar";
  };

  config = mkMerge [
    (mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
        remotePlay.openFirewall = true;
      };
      hardware.graphics.enable32Bit = lib.mkDefault true;
    })

    (mkIf cfg.moonlight.enable {
      environment.systemPackages = [ pkgs.moonlight-qt ];
    })
  ];
}
