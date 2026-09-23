{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.desktop.bigscreen;
in
{
  options.services.htpc.desktop.bigscreen = {
    enable = mkEnableOption "Plasma Bigscreen 10-foot session as the HTPC's shell";
  };

  # NOTE: as of Plasma 6.7 (stable since June 2026, currently 6.7.4), Bigscreen
  # is an official Plasma module but nixpkgs does not yet expose a one-line
  # services.desktopManager.plasma6-bigscreen.enable option (tracked upstream).
  # Until that lands, wire the session manually: install the package, register
  # it as an SDDM session, and set it default. Re-check nixpkgs before writing
  # this for real — if the option has landed, delete all of this in favor of it.
  config = mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    environment.systemPackages = [ pkgs.kdePackages.plasma-bigscreen ];

    xdg.portal.configPackages = [ pkgs.kdePackages.plasma-bigscreen ];

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    services.displayManager.defaultSession = "plasma-bigscreen-wayland";
    services.displayManager.sessionPackages = [ pkgs.kdePackages.plasma-bigscreen ];

    services.pipewire = {
      enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
  };
}
