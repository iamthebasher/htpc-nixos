{ config, lib, pkgs, inputs, ... }:

{
  # lib here is home-manager's (has lib.hm), not the NixOS one from above
  home-manager.users.htpc = { pkgs, lib, ... }: {
    home.stateVersion = "25.11"; # home-manager's own, independent of system.stateVersion: the release HM was first used with here. Never change it

    # Placeholder — this is where per-user dotfile-style config goes as it's
    # ported over: mpv keybind overrides that are user- rather than
    # system-scoped, shell config, etc. Kept intentionally thin for now;
    # most of this repo's actual behavior lives in the system modules so a
    # clone of this repo works for someone who isn't Asher.
    home.packages = [ ];

    # Stremio Enhanced plugins, deployed and switched on
    # (modules/home/stremio-enhanced.nix): mpv handoff with auto-back, and
    # the remote's Back/Search/List/Home
    imports = [ ../modules/home/stremio-enhanced.nix ];
    programs.stremio-enhanced.plugins = [ "MpvHandoffShell" "RemoteKeys" ];

    programs.home-manager.enable = true;
  };
}
