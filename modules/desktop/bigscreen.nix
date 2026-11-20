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

    # On Wayland, KDE Connect's remote input (phone as mouse/keyboard) goes
    # through the RemoteDesktop portal, which asks "allow remote control?"
    # every session. That needs a mouse. This pre-grants it in the portal
    # permission store's kde-authorized table, the same mechanism KDE uses for
    # krdp. Same trust caveat as autoAcceptPairing: paired devices can then
    # send input without asking.
    kdeconnect.allowRemoteInput = mkEnableOption "KDE Connect remote input without the per-session permission prompt";

    fullscreenApps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "moonlight" "open-tv" ];
      description = ''
        Case-insensitive regexes matched against window classes (Wayland
        app ids). Matching windows open fullscreen through a KWin window
        rule, for apps that start windowed and have no fullscreen setting
        of their own. Find an app's class with KWin's "Detect window
        properties" in System Settings -> Window Rules.
      '';
    };
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
        # SDDM reuses the last session picked (/var/lib/sddm/state.conf)
        # over DefaultSession below. One login to plain Plasma, deliberate or
        # not, and every later login starts Plasma without Bigscreen's
        # environment (PLASMA_PLATFORM=mediacenter): plain plasmashell plus a
        # Bigscreen shell fighting over the same D-Bus name, black screen
        # (2026-11-20). Always start the declared session instead.
        settings.Users.RememberLastSession = false;
      };

      services.displayManager.defaultSession = "plasma-bigscreen-wayland";
      services.displayManager.sessionPackages = [ pkgs.kdePackages.plasma-bigscreen ];

      services.pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
    }

    (mkIf cfg.kdeconnect.allowRemoteInput {
      # One-shot write to the portal permission store, which persists in
      # ~/.local/share/flatpak/db. Re-running every login just keeps it set.
      # SetPermission(table, create, id, app, permissions)
      systemd.user.services.kdeconnect-allow-remote-input = {
        description = "Pre-authorize KDE Connect remote input (RemoteDesktop portal)";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = concatStringsSep " " [
            "${pkgs.systemd}/bin/busctl --user call"
            "org.freedesktop.impl.portal.PermissionStore"
            "/org/freedesktop/impl/portal/PermissionStore"
            "org.freedesktop.impl.portal.PermissionStore"
            "SetPermission sbssas kde-authorized true remote-desktop org.kde.kdeconnect.daemon 1 yes"
          ];
        };
      };
    })

    (mkIf (cfg.fullscreenApps != [ ]) {
      # System-wide KWin rules: KConfig cascades /etc/xdg under the user's
      # ~/.config, so this applies as long as the user hasn't made their own
      # rules list (a user kwinrulesrc [General] section would override it).
      # wmclassmatch=3 is regex (partial match), fullscreenrule=3 is "apply
      # initially", so a window can still leave fullscreen afterwards.
      environment.etc."xdg/kwinrulesrc".text =
        let
          name = i: "htpc-fullscreen-${toString i}";
        in
        ''
          [General]
          count=${toString (length cfg.fullscreenApps)}
          rules=${concatStringsSep "," (imap1 (i: _: name i) cfg.fullscreenApps)}
        ''
        + concatStrings (imap1 (i: re: ''

          [${name i}]
          Description=Fullscreen: ${re}
          wmclass=(?i)${re}
          wmclassmatch=3
          fullscreen=true
          fullscreenrule=3
        '') cfg.fullscreenApps);
    })

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
