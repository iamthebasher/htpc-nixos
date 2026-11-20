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
    hardware.input = {
      logging.enable = true; # journalctl -u input-udev-log
      tools.enable = true; # evtest, libinput, input-report
      remotes.mx3Pro.enable = true;
    };

    desktop.bigscreen = {
      enable = true;
      kdeconnect.autoAcceptPairing = true; # no mouse-only pairing dialog; trusted LAN only
      kdeconnect.allowRemoteInput = true; # no "allow remote control?" prompt each login
      # both start windowed otherwise. Fred TV is the dev.fredol.open-tv flatpak
      fullscreenApps = [ "moonlight" "open-tv" ];
    };

    media = {
      mpv.enable = true;
      stremio = {
        enable = true;
        # Stremio Enhanced on the native GTK/WebKit shell, built from source
        # in this repo (replaced the Electron AppImage 2026-11-19; upstream is
        # moving to this one). Plugins deployed and enabled in home/default.nix
        package = pkgs.callPackage ../../pkgs/stremio-linux-shell-enhanced { };
        mpvHandoff.enable = true;
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
        # off 2026-11-19: nixpkgs' makemkv-oss 2.0.0 fails with a hash mismatch
        # (upstream re-uploaded the tarball). Turn back on once nixpkgs fixes it
        rip.enable = false;
      };
      ota.enable = false; # no tuner yet — flip on once an HDHomeRun is on the LAN

      # iptv.enable (the `iptv` mpv launcher) is set in ./secrets.nix — it
      # needs the playlist URL secret. Fred TV, the main IPTV app, is below.
    };

    gaming = {
      steam.enable = true;
      moonlight.enable = true;
      heroic.enable = true;
      lutris.enable = true;
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
  # sub-font in files/mpv/mpv.conf
  fonts.packages = [ pkgs.roboto ];

  services.flatpak = {
    enable = true;
    packages = [ "dev.fredol.open-tv" ];
  };

  # nvidia drivers, steam, etc. Must be set as a module option — see the
  # comment in flake.nix's let block for why it can't live there.
  nixpkgs.config.allowUnfree = true;

  # `nix shell`, `nix flake ...` etc. on the box itself (nixos-rebuild --flake
  # enables these for its own run only)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "htpc";
  time.timeZone = "America/New_York"; # adjust if this ever isn't true

  # The HTPC boots in legacy BIOS mode (no UEFI), so GRUB installed to the
  # disk's MBR. Copied from the original /etc/nixos/configuration.nix.
  # systemd-boot is not an option here: it needs UEFI.
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    useOSProber = true;
  };

  networking.networkmanager.enable = true;

  # Straight into Bigscreen at boot, no password at the TV. Declared here so
  # the session is the declared defaultSession (plasma-bigscreen-wayland).
  # Auto-login set up through System Settings instead writes its own
  # session choice to /etc/sddm.conf.d, which is how the box ended up
  # auto-logging into plain Plasma with a black screen (2026-11-20).
  services.displayManager.autoLogin = {
    enable = true;
    user = "htpc";
  };

  users.users.htpc = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # sudo — without it there's no way to rebuild after switching
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

  # pull this repo on the box itself (`git pull && nixos-rebuild switch`)
  programs.git.enable = true;

  programs.firefox.enable = true;
  programs.neovim.enable = true;

  system.stateVersion = "25.11"; # from the HTPC's original install — never change it
}
