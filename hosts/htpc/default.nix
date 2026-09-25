{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules
    ../../home/default.nix

    # Uncomment once secrets/htpc.yaml exists (see README "Secrets setup").
    # It declares the sops secrets and turns on the modules that need them
    # (ProtonVPN, IPTV). Kept out until then because sops-nix refuses to
    # build if a declared secrets file is missing.
    # ./secrets.nix
  ];

  # --- this machine's feature toggles ---
  services.htpc = {
    hardware.nvidia.enable = true;

    desktop.bigscreen.enable = true;

    media = {
      mpv.enable = true;
      stremio = {
        enable = true;
        package = inputs.custom-packages.packages.${pkgs.stdenv.hostPlatform.system}.stremio-enhanced;
      };
      aiostreams.enable = true;

      arr = {
        enable = true;
        bazarr.enable = true;
      };
      jellyfin = {
        server.enable = true;
        client.enable = true;
      };

      youtube.enable = true;
      dvd = {
        play.enable = true;
        rip.enable = true;
      };
      ota.enable = true; # assumes an HDHomeRun on the LAN — turn off if there isn't one yet

      # iptv.enable (the `iptv` mpv launcher) is set in ./secrets.nix — it
      # needs the playlist URL secret. Fred TV, the main IPTV app, is below.
    };

    gaming = {
      steam.enable = true;
      moonlight.enable = true;
    };

    system.fakeHwclock.enable = true;

    # network.protonvpn.enable is set in ./secrets.nix — it needs the private key secret
  };

  # Fred TV (Open TV) for IPTV — flathub only, not in nixpkgs. Installed
  # declaratively by nix-flatpak; the playlist is added in-app.
  # Caveat: the flatpak bundles its own mpv inside the sandbox, so it does
  # NOT go through mpv-htpc / files/mpv shaders. TODO: check whether Fred
  # TV's mpv settings can reach the host mpv-htpc (flatpak-spawn --host),
  # or accept that IPTV is the one source outside the shared pipeline.
  services.flatpak = {
    enable = true;
    packages = [ "dev.fredol.open-tv" ];
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
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "cdrom" # DVD playback/ripping
      config.services.htpc.media.library.group # read/manage the media library
    ];
    # set a password with `passwd` post-install, or hash one in here via
    # hashedPasswordFile pointed at a sops secret
  };

  # for editing secrets/htpc.yaml on the box itself (`sops secrets/htpc.yaml`)
  environment.systemPackages = [ pkgs.sops pkgs.age ];

  system.stateVersion = "26.05"; # set to whatever release you actually install from — do not change after first rebuild
}
