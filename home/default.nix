{ config, lib, pkgs, inputs, ... }:

{
  home-manager.users.htpc = { pkgs, ... }: {
    home.stateVersion = "26.05"; # match system.stateVersion in hosts/htpc/default.nix

    # Placeholder — this is where per-user dotfile-style config goes as it's
    # ported over: mpv keybind overrides that are user- rather than
    # system-scoped, shell config, etc. Kept intentionally thin for now;
    # most of this repo's actual behavior lives in the system modules so a
    # clone of this repo works for someone who isn't Asher.
    home.packages = [ ];

    programs.home-manager.enable = true;
  };
}
