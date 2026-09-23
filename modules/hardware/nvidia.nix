{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.hardware.nvidia;
in
{
  options.services.htpc.hardware.nvidia = {
    enable = mkEnableOption "NVIDIA GPU drivers and Wayland tuning for the HTPC (RTX 3070)";

    open = mkOption {
      type = types.bool;
      default = false;
      description = "Use the open-source NVIDIA kernel modules instead of proprietary.";
    };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true; # Steam/Proton need this
    };

    hardware.nvidia = {
      modesetting.enable = true; # required for Wayland
      powerManagement.enable = true;
      open = cfg.open;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # HDR / VRR on a couch setup benefit from the newer kernel + explicit sync path
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];
  };
}
