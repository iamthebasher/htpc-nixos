{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.ota;
  mpv = config.services.htpc.media.mpv;

  # HDHomeRun tuners serve their own channel list over HTTP, so no backend
  # is needed just to watch. Without a fixed address, find the tuner by
  # broadcast discovery at launch.
  discover = "$(${pkgs.libhdhomerun}/bin/hdhomerun_config discover | ${pkgs.gawk}/bin/awk '/found at/ { print $NF; exit }')";

  otaTv = pkgs.writeShellScriptBin "ota-tv" ''
    addr=${if cfg.tunerAddress != null then escapeShellArg cfg.tunerAddress else "\"${discover}\""}
    if [ -z "$addr" ]; then
      echo "ota-tv: no HDHomeRun found — set services.htpc.media.ota.tunerAddress" >&2
      exit 1
    fi
    exec ${mpv.package}/bin/mpv-htpc "http://$addr/lineup.m3u" "$@"
  '';
in
{
  options.services.htpc.media.ota = {
    enable = mkEnableOption ''
      over-the-air TV from an HDHomeRun network tuner, with an `ota-tv`
      launcher that plays the tuner's channel lineup through mpv-htpc
    '';

    tunerAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "192.168.1.50";
      description = ''
        IP or hostname of the HDHomeRun. If null, `ota-tv` discovers it by
        UDP broadcast on each launch — which the ProtonVPN killswitch blocks
        (broadcast isn't covered by lanSubnets), so set this when the VPN is on.
      '';
    };
  };

  # Guide data and DVR: Jellyfin's built-in Live TV (Dashboard -> Live TV ->
  # add Tuner Device: HDHomeRun), when services.htpc.media.jellyfin.server is
  # on. (Tvheadend was the original plan, but nixpkgs removed it.)
  config = mkIf cfg.enable {
    assertions = [{
      assertion = mpv.enable;
      message = "services.htpc.media.ota requires services.htpc.media.mpv.enable = true.";
    }];

    # hdhomerun_config, for finding the tuner and checking signal
    environment.systemPackages = [ otaTv pkgs.libhdhomerun ];
  };
}
