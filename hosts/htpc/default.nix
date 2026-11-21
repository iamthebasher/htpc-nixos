{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix # partitions + fileSystems (GPT, ESP, ext4 root)
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

    # Hyprland, straight from boot: getty auto-logs in `htpc` on tty1, the
    # login shell starts Hyprland (no display manager, same as Balthasar)
    desktop.hyprland = {
      enable = true;
      autologin.user = "htpc";
      monitor = {
        output = "HDMI-A-1"; # the LG TV; check with `hyprctl monitors`
        # its fastest 4K mode; "preferred" picked 60 Hz. Tested live 2026-11-21
        mode = "3840x2160@119.88";
        bitdepth = 10;
      };
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

  # Limine on UEFI (2026-11-20, with the disko reinstall; was GRUB on
  # BIOS/MBR). The ESP is /boot (disko.nix). The menu shows the last
  # generations so a bad build can be picked around. The old GRUB menu
  # skipped its timeout, so it's explicit here.
  boot.loader.limine = {
    enable = true;
    efiSupport = true;
    maxGenerations = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  zramSwap.enable = true; # compressed swap in RAM; no swap partition (disko.nix)

  networking.networkmanager.enable = true;

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

  # SSH from Balthasar, for working on the box without walking to the TV
  # (logs, hyprctl, quickshell prototyping). Key-only: no passwords, no
  # root login. Once secrets.nix turns the killswitch on, lanSubnets is
  # what still lets it in.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  users.users.htpc.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4qCurqLwND1LFHEN4m/Mc3aImyW5DAziGSICCjfzUl balthasar"
  ];

  # for editing secrets/htpc.yaml on the box itself (`sops secrets/htpc.yaml`)
  environment.systemPackages = [ pkgs.sops pkgs.age ];

  # pull this repo on the box itself (`git pull && nixos-rebuild switch`)
  programs.git.enable = true;

  programs.firefox.enable = true;
  programs.neovim.enable = true;

  system.stateVersion = "25.11"; # from the HTPC's original install — never change it
}
