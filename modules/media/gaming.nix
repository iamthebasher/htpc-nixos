{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.gaming;
  ml = cfg.moonlight;

  # Ends the stream from the remote: quits the running app on the host (the
  # same as Moonlight's Quit, so Sunshine runs its cleanup at once), then
  # closes Moonlight. Its process is ".moonlight-wrap" (the nixpkgs wrapper).
  moonlightExit = pkgs.writeShellScriptBin "moonlight-exit" ''
    timeout 15 ${pkgs.moonlight-qt}/bin/moonlight quit ${escapeShellArg ml.host}
    pkill -x .moonlight-wrap
  '';
in
{
  options.services.htpc.gaming = {
    steam.enable = mkEnableOption "Steam, with gamescope session and 32-bit graphics support";
    moonlight.enable = mkEnableOption "Moonlight client for streaming from Balthasar";
    moonlight.host = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "192.168.50.134";
      description = ''
        The streaming host, as Moonlight knows it (address or name). Set, it
        enables the exit button: holding `exitKey` quits the app on the
        host and closes Moonlight. Needed because Moonlight grabs every key
        while streaming, the remote's Home and Back included.
      '';
    };
    moonlight.exitKey = mkOption {
      type = types.str;
      default = "XF86HomePage";
      description = ''
        Hyprland key that, held, ends the stream (`moonlight-exit`). A short
        press still reaches the stream as normal. Bound with long_press and
        dont_inhibit, so it works while Moonlight holds the keyboard.
      '';
    };
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

    (mkIf (ml.enable && ml.host != null) {
      environment.systemPackages = [ moonlightExit ];
      services.htpc.desktop.hyprland.extraConfig = ''
        -- hold ${ml.exitKey}: end the Moonlight stream (gaming.moonlight.host)
        hl.bind(${builtins.toJSON ml.exitKey}, hl.dsp.exec_cmd("moonlight-exit"), { long_press = true, dont_inhibit = true })
      '';
    })

    (mkIf cfg.heroic.enable {
      environment.systemPackages = [ pkgs.heroic ];
    })

    (mkIf cfg.lutris.enable {
      environment.systemPackages = [ pkgs.lutris ];
    })
  ];
}
