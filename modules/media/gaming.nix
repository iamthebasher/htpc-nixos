{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.gaming;
in
{
  options.services.htpc.gaming = {
    steam.enable = mkEnableOption "Steam, with gamescope session and 32-bit graphics support";
    moonlight.enable = mkEnableOption "Moonlight client for streaming from Balthasar";
    # Epic has no Linux client (none in nixpkgs either). Heroic is the
    # standard replacement: Epic, GOG and Amazon libraries through Wine/Proton.
    heroic.enable = mkEnableOption "Heroic Games Launcher (Epic/GOG/Amazon)";
    lutris.enable = mkEnableOption "Lutris, for everything else (other stores, emulators, one-off Wine installs)";
  };

  config = mkMerge [
    (mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
        remotePlay.openFirewall = true;
      };
    })

    (mkIf (cfg.steam.enable || cfg.heroic.enable || cfg.lutris.enable) {
      # 32-bit GL/Vulkan, needed by most Windows games under Wine/Proton
      hardware.graphics.enable32Bit = lib.mkDefault true;
    })

    (mkIf cfg.moonlight.enable {
      environment.systemPackages = [ pkgs.moonlight-qt ];
    })

    (mkIf cfg.heroic.enable {
      environment.systemPackages = [ pkgs.heroic ];
    })

    (mkIf cfg.lutris.enable {
      environment.systemPackages = [ pkgs.lutris ];
    })
  ];
}
