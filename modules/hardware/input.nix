{ config, lib, pkgs, ... }:

with lib;

# Input-device compatibility work: remotes, dongles, controllers, keyboards.
# Step one is just *recording* what the hardware is: which devices show up,
# with which IDs and capabilities. That's the raw material for per-device
# fixes later (hwdb keymaps via services.udev.extraHwdb, udev rules), which
# will live in this module behind their own options.
#
# Deliberately NOT logged: key presses. A system-wide key log would also
# capture everything typed on a keyboard, passwords included. Button codes
# are captured on demand instead, with `sudo libinput debug-events` or
# `sudo evtest` (both installed by tools.enable).

let
  cfg = config.services.htpc.hardware.input;

  # One-shot snapshot of every input device, for pasting into an issue or a
  # chat when adding support for a new remote. Doesn't need root.
  inputReport = pkgs.writeShellApplication {
    name = "input-report";
    runtimeInputs = [ pkgs.usbutils pkgs.systemd pkgs.coreutils ];
    text = ''
      echo "### input-report $(date -Is) kernel $(uname -r)"
      echo
      echo "### lsusb"
      lsusb
      echo
      echo "### /proc/bus/input/devices"
      cat /proc/bus/input/devices
      for dev in /dev/input/event*; do
        echo "### udevadm info $dev"
        udevadm info --query=property --name="$dev"
        echo
      done
    '';
  };
in
{
  options.services.htpc.hardware.input = {
    logging.enable = mkEnableOption ''
      a persistent log of input-device hotplug events (udev add/remove/change
      for input, hid, hidraw, usb and bluetooth). Read it with
      `journalctl -u input-udev-log`. Records device identity only, never
      key presses
    '';

    tools.enable = mkEnableOption ''
      input debugging tools: evtest, libinput (debug-events), usbutils, and
      `input-report`, which snapshots all current input devices
    '';
  };

  config = mkMerge [
    (mkIf cfg.logging.enable {
      # udevadm monitor in a service rather than a RUN+= udev rule: udev
      # rules must stay fast and can't hold a process open, while this
      # streams every event, with all its properties, into the journal
      # (rotated by journald, persistent across reboots on NixOS).
      systemd.services.input-udev-log = {
        description = "Log input-device udev events";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-udevd.service" ];
        serviceConfig = {
          # stdbuf: line-buffer so each event reaches the journal as it happens
          ExecStart = concatStringsSep " " [
            "${pkgs.coreutils}/bin/stdbuf -oL"
            "${pkgs.systemd}/bin/udevadm monitor --udev --property"
            "--subsystem-match=input"
            "--subsystem-match=hid"
            "--subsystem-match=hidraw"
            "--subsystem-match=usb"
            "--subsystem-match=bluetooth"
          ];
          Restart = "always";
          RestartSec = 5;
          DynamicUser = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };
    })

    (mkIf cfg.tools.enable {
      environment.systemPackages = [
        pkgs.evtest
        pkgs.libinput
        pkgs.usbutils
        inputReport
      ];
    })
  ];
}
