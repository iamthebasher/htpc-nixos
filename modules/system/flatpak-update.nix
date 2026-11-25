{ config, lib, pkgs, ... }:

with lib;

# Keeps system flatpaks up to date: a oneshot `htpc-flatpak-update` service
# on a timer, plus a polkit rule so whoever is at the TV can start it
# without a password. That's what the quickshell UI's Settings > Update
# apps does (files/quickshell/Updates.qml).
#
# Plain NixOS flatpak only, so it doesn't need nix-flatpak. With
# nix-flatpak, leave its own update options (update.auto, update.onActivation)
# off: this replaces them.
#
#   systemctl start htpc-flatpak-update      update now
#   journalctl -u htpc-flatpak-update        what it did
#   systemctl list-timers htpc-flatpak-update

let
  cfg = config.services.htpc.system.flatpakUpdate;
  unit = "htpc-flatpak-update";
in
{
  options.services.htpc.system.flatpakUpdate = {
    enable = mkEnableOption "automatic flatpak updates on a timer, which the local user can also start";

    onCalendar = mkOption {
      type = types.str;
      default = "*-*-* 00/6:00:00";
      example = "daily";
      description = ''
        When to update (systemd OnCalendar). Every 6 hours by default. Runs
        missed while the machine was off happen at the next boot.
      '';
    };

    removeUnused = mkOption {
      type = types.bool;
      default = true;
      description = "Also remove runtimes no installed app needs any more.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = config.services.flatpak.enable;
      message = "services.htpc.system.flatpakUpdate needs services.flatpak.enable.";
    }];

    systemd.services.${unit} = {
      description = "Update flatpak apps";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      # in the background, so it doesn't stutter playback
      serviceConfig = {
        Type = "oneshot";
        Nice = 15;
        IOSchedulingClass = "idle";
      };
      # Running apps keep their old version until they're restarted.
      script = ''
        flatpak update --system --noninteractive --assumeyes
      '' + optionalString cfg.removeUnused ''
        flatpak uninstall --system --unused --noninteractive --assumeyes
      '';
    };

    systemd.timers.${unit} = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;          # catch up after the machine was off
        RandomizedDelaySec = "10min";
      };
    };

    # Starting this one unit (not stopping it, not any other unit) is allowed
    # for a local, active session: the user at the TV, not SSH logins.
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "${unit}.service" &&
            action.lookup("verb") == "start" &&
            subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
