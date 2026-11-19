{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.desktop.bigscreen;

  # Accepts every pending KDE Connect pairing request over D-Bus. Polls
  # instead of listening for signals: the daemon can restart and device
  # objects come and go, and a 2s loop over busctl survives all of that
  # without any reconnect logic.
  kdeconnectAutoAccept = pkgs.writeShellApplication {
    name = "kdeconnect-autoaccept";
    runtimeInputs = [ pkgs.systemd pkgs.jq pkgs.coreutils ];
    text = ''
      svc=org.kde.kdeconnect
      while true; do
        # all known devices (reachable or not, paired or not); fails quietly
        # while kdeconnectd isn't up yet
        if ids=$(busctl --user --json=short call "$svc" /modules/kdeconnect \
              org.kde.kdeconnect.daemon devices bb false false 2>/dev/null \
            | jq -r '.data[0][]'); then
          for id in $ids; do
            path="/modules/kdeconnect/devices/$id"
            requested=$(busctl --user get-property "$svc" "$path" \
              org.kde.kdeconnect.device isPairRequestedByPeer 2>/dev/null || true)
            if [ "$requested" = "b true" ]; then
              echo "accepting pairing request from $id"
              busctl --user call "$svc" "$path" org.kde.kdeconnect.device acceptPairing || true
            fi
          done
        fi
        sleep 2
      done
    '';
  };
in
{
  options.services.htpc.desktop.bigscreen = {
    enable = mkEnableOption "Plasma Bigscreen 10-foot session as the HTPC's shell";

    # KDE Connect has no built-in auto-accept, so normally every pairing
    # request pops a dialog that needs a mouse. This accepts them over D-Bus.
    # SECURITY: any device on the LAN can then pair, and a paired device can
    # send mouse/keyboard input and run the commands configured in KDE
    # Connect. Fine on a trusted home network; turn it off on shared Wi-Fi.
    # Pairing is remembered, so this can also be switched off again once the
    # devices you want are paired.
    kdeconnect.autoAcceptPairing = mkEnableOption "accepting every KDE Connect pairing request automatically (no confirmation dialog)";
  };

  # NOTE: as of Plasma 6.7 (stable since June 2026, currently 6.7.4), Bigscreen
  # is an official Plasma module but nixpkgs does not yet expose a one-line
  # services.desktopManager.plasma6-bigscreen.enable option (tracked upstream).
  # Until that lands, wire the session manually: install the package, register
  # it as an SDDM session, and set it default. Re-check nixpkgs before writing
  # this for real — if the option has landed, delete all of this in favor of it.
  config = mkIf cfg.enable (mkMerge [
    {
      services.desktopManager.plasma6.enable = true;

      environment.systemPackages = [ pkgs.kdePackages.plasma-bigscreen ];

      # The Bigscreen homescreen's header imports a KDE Connect indicator
      # (QML module org.kdeconnect), but the nixpkgs package doesn't depend on
      # it — without this the homescreen fails to load entirely ("type
      # homescreen unavailable"). Also makes a phone usable as a remote.
      # TODO: report upstream to nixpkgs so plasma-bigscreen pulls it in.
      programs.kdeconnect.enable = true;

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
    }

    (mkIf cfg.kdeconnect.autoAcceptPairing {
      systemd.user.services.kdeconnect-autoaccept = {
        description = "Auto-accept KDE Connect pairing requests";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${kdeconnectAutoAccept}/bin/kdeconnect-autoaccept";
          Restart = "on-failure";
        };
      };
    })
  ]);
}
