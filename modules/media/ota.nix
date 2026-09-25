{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.ota;
  mpv = config.services.htpc.media.mpv;
  port = config.services.tvheadend.httpPort;

  otaTv = pkgs.writeShellScriptBin "ota-tv" ''
    exec ${mpv.package}/bin/mpv-htpc "http://localhost:${toString port}/playlist/channels.m3u" "$@"
  '';
in
{
  options.services.htpc.media.ota = {
    enable = mkEnableOption ''
      over-the-air TV via an HDHomeRun network tuner + Tvheadend, with an
      `ota-tv` launcher that plays the channel list through mpv-htpc
    '';
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = mpv.enable;
      message = "services.htpc.media.ota requires services.htpc.media.mpv.enable = true.";
    }];

    services.tvheadend.enable = true;

    # hdhomerun_config, for finding the tuner and checking signal
    environment.systemPackages = [ otaTv pkgs.libhdhomerun ];

    # First-run setup is in Tvheadend's web UI (:${port}): add the HDHomeRun
    # as a network, scan muxes, map services to channels, and allow
    # anonymous streaming from localhost so `ota-tv` doesn't need a login.
    #
    # With the ProtonVPN killswitch on, the tuner must be inside
    # services.htpc.network.protonvpn.lanSubnets. HDHomeRun discovery also
    # uses UDP broadcast (255.255.255.255:65001), which lanSubnets doesn't
    # cover — if auto-discovery fails, add the tuner by IP instead.
  };
}
