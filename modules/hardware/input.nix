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

    # MX3 Pro air mouse (backlit keyboard on the back). Its receiver reports
    # as the generic "2.4G Composite Devic", USB 0406:2814, shared by many
    # cheap air remotes. Captured 2026-11-19 with libinput debug-events:
    #
    #   power KEY_POWER          home KEY_HOMEPAGE     vol+/- KEY_VOLUMEUP/DOWN
    #   skip back KEY_REWIND     back KEY_BACK         mute KEY_MUTE
    #   skip fwd KEY_FASTFORWARD arrows KEY_UP/...     pg up/dn KEY_PAGEUP/DOWN
    #   previous KEY_PREVIOUSSONG  ok KEY_ENTER        0-9 KEY_0..KEY_9
    #   next KEY_NEXTSONG        list KEY_COMPOSE      del KEY_BACKSPACE
    #   search KEY_SEARCH        movies KEY_CONFIG*    "!" KEY_MAIL
    #   play/pause KEY_PLAYPAUSE zoom +/- KEY_ZOOMIN/OUT  IE KEY_WWW
    #
    # Backlight, TV (IR-learning) and air-mouse toggle send nothing: handled
    # inside the remote, as do red/green/yellow/blue (re-tested). The
    # keyboard side sends ordinary keys. These are already the codes remote
    # software expects, so there's no hwdb remap; player behaviour for them
    # lives in files/mpv/input.conf. *Remapped to KEY_FAVORITES (see below).
    remotes.mx3Pro = {
      enable = mkEnableOption ''
        MX3 Pro air-mouse remote support: keeps its USB receiver from
        autosuspending, which delays or drops the first button press after
        the remote has been idle
      '';
      wakeFromSuspend = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Let the remote wake the machine from suspend. Off by default:
          with air-mouse mode on, just picking the remote up sends motion
          and would wake it.
        '';
      };
    };
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

    (mkIf cfg.remotes.mx3Pro.enable {
      # "Movies" button: KEY_CONFIG (XF86Tools) is a Plasma global shortcut
      # that opens quick settings, so mpv never saw it. Remapped to
      # KEY_FAVORITES, which nothing in Plasma binds; mpv gets it as
      # FAVORITES (files/mpv/input.conf). c0183 = HID consumer page usage
      # 0x183 ("AL Consumer Control Configuration"), which the kernel maps
      # to KEY_CONFIG.
      services.udev.extraHwdb = ''
        evdev:input:b0003v0406p2814*
         KEYBOARD_KEY_c0183=favorites
      '';

      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0406", ATTR{idProduct}=="2814", ATTR{power/control}="on", ATTR{power/wakeup}="${if cfg.remotes.mx3Pro.wakeFromSuspend then "enabled" else "disabled"}"
      '';
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
