{ config, lib, ... }:

with lib;

let
  cfg = config.services.htpc.network.tailscale;
in
{
  options.services.htpc.network.tailscale = {
    enable = mkEnableOption ''
      Tailscale, so the box is reachable from the tailnet (SSH from
      Balthasar, Moonlight to Balthasar from anywhere). Log in once with
      `sudo tailscale up`. When the ProtonVPN killswitch is on, it lets
      tailscale0 through in both directions (see protonvpn.nix)
    '';
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      # Keep resolv.conf alone: MagicDNS is off on purpose across the
      # tailnet (Balthasar blocks it), and the VPN owns DNS once it's on.
      # Reach peers by their 100.x address instead.
      extraSetFlags = [ "--accept-dns=false" ];
    };
  };
}
