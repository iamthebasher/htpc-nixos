{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/hardware/nvidia.nix
    ../../modules/desktop/bigscreen.nix
    ../../modules/media/mpv.nix
    ../../modules/media/stremio.nix
    ../../modules/media/gaming.nix
    ../../modules/system/fake-hwclock.nix
    ../../modules/network/protonvpn.nix

    ../../home/default.nix
  ]
  # Local, gitignored override — real VPN credentials (privateKeyFile,
  # peerPublicKey, endpoint, interfaceAddress from ProtonVPN's WireGuard
  # config export) and services.htpc.network.protonvpn.enable = true live
  # there, not in this published file. Same pattern as stremio.addonUrl.
  ++ lib.optional (builtins.pathExists ./local.nix) ./local.nix;

  # --- this machine's feature toggles ---
  services.htpc = {
    hardware.nvidia.enable = true;

    desktop.bigscreen.enable = true;

    media = {
      mpv.enable = true;
      stremio.enable = true;
      # stremio.addonUrl set in a local, untracked override — see README.
    };

    gaming = {
      steam.enable = true;
      moonlight.enable = true;
    };

    system.fakeHwclock.enable = true;

    # network.protonvpn.enable left off here — flipped on in hosts/htpc/local.nix
    # once real WireGuard credentials exist. See README / modules/network/protonvpn.nix.
  };

  # nvidia drivers, steam, etc. Must be set as a module option — see the
  # comment in flake.nix's let block for why it can't live there.
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "htpc";
  time.timeZone = "America/New_York"; # adjust if this ever isn't true

  # Match whatever the real hardware-configuration.nix's generated boot
  # loader stanza actually is (systemd-boot vs. grub) once installed.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  networking.networkmanager.enable = true;

  users.users.htpc = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "video" "audio" ];
    # set a password with `passwd` post-install, or hash one in here via
    # hashedPasswordFile pointed at a sops/agenix secret once that's wired up
  };

  system.stateVersion = "26.05"; # set to whatever release you actually install from — do not change after first rebuild
}
