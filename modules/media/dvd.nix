{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.dvd;
  mpv = config.services.htpc.media.mpv;

  dvdPlay = pkgs.writeShellScriptBin "dvd-play" ''
    exec ${mpv.package}/bin/mpv-htpc dvd:// "$@"
  '';
in
{
  options.services.htpc.media.dvd = {
    play.enable = mkEnableOption "a `dvd-play` launcher that plays discs straight through mpv-htpc";

    rip.enable = mkEnableOption ''
      MakeMKV + HandBrake for ripping discs into the library's dvd-rips
      folder (unfree: MakeMKV)
    '';
  };

  config = mkMerge [
    # Reading the optical drive needs the (built-in) "cdrom" group — the host
    # config adds the HTPC user to it.
    (mkIf cfg.play.enable {
      assertions = [{
        assertion = mpv.enable;
        message = "services.htpc.media.dvd.play requires services.htpc.media.mpv.enable = true.";
      }];
      environment.systemPackages = [ dvdPlay pkgs.libdvdcss ];
    })

    (mkIf cfg.rip.enable {
      environment.systemPackages = [ pkgs.makemkv pkgs.handbrake ];
      # MakeMKV talks to the drive through the SCSI generic interface
      boot.kernelModules = [ "sg" ];
      # MakeMKV's beta registration key expires every couple of months and is
      # entered in-app (Help -> Register) — nothing to declare here.
      # Rip output: ${library.dir}/dvd-rips, then move/rename into movies/ or
      # tv/ so Jellyfin picks it up.
    })
  ];
}
