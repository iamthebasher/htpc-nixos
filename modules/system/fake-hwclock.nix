{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.system.fakeHwclock;
  stateFile = "/var/lib/fake-hwclock/time";
in
{
  options.services.htpc.system.fakeHwclock = {
    enable = mkEnableOption ''
      save/restore system clock across reboots on hardware with a dead or
      missing RTC battery. Fixes the boot-time chicken-and-egg problem where
      a wildly wrong clock (e.g. reset toward epoch) fails TLS validation
      for the VPN handshake, which in turn blocks NTP from ever correcting
      it under an always-on killswitch.
    '';
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d /var/lib/fake-hwclock 0755 root root -" ];

    # Runs at every shutdown/reboot via the ExecStop trick: a service that's
    # "started" (no-op) at boot and whose ExecStop fires when systemd stops
    # it during shutdown, which is the standard way to hook shutdown on
    # NixOS without fighting shutdown.target ordering directly.
    systemd.services.fake-hwclock-save = {
      description = "Save system clock for fake-hwclock";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${pkgs.bash}/bin/bash -c 'date -u +%s > ${stateFile}'";
      };
    };

    # Periodic save too, so a power loss (not a clean shutdown) doesn't lose
    # more than this interval's worth of accuracy.
    systemd.timers.fake-hwclock-periodic-save = {
      description = "Periodically save system clock for fake-hwclock";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };
    systemd.services.fake-hwclock-periodic-save = {
      description = "Save system clock for fake-hwclock (periodic)";
      serviceConfig.Type = "oneshot";
      script = "date -u +%s > ${stateFile}";
    };

    # Restore early at boot, before anything that cares about the clock
    # being sane (TLS-using services, the VPN handshake, timesyncd itself).
    # Only ever moves the clock forward, never backward, so a legitimately
    # NTP-corrected clock from a previous boot is never regressed.
    systemd.services.fake-hwclock-restore = {
      description = "Restore system clock from fake-hwclock save file";
      before = [ "systemd-timesyncd.service" "time-sync.target" "network-pre.target" ];
      wantedBy = [ "sysinit.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ -f ${stateFile} ]; then
          saved=$(cat ${stateFile})
          current=$(date +%s)
          if [ "$saved" -gt "$current" ]; then
            ${pkgs.coreutils}/bin/date -s "@$saved"
          fi
        fi
      '';
    };
  };
}
