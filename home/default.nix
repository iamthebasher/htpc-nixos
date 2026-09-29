{ config, lib, pkgs, inputs, ... }:

{
  home-manager.users.htpc = { pkgs, ... }: {
    home.stateVersion = "26.05"; # home-manager's own, independent of system.stateVersion: the release HM was first used with here. Never change it

    # Placeholder — this is where per-user dotfile-style config goes as it's
    # ported over: mpv keybind overrides that are user- rather than
    # system-scoped, shell config, etc. Kept intentionally thin for now;
    # most of this repo's actual behavior lives in the system modules so a
    # clone of this repo works for someone who isn't Asher.
    home.packages = [ ];

    # stremio-enhanced plugin: intercepts the stream URL Stremio's local
    # server (:11470) is about to play and sends it to the handoff listener
    # on 127.0.0.1:7777 (services.htpc.media.stremio.mpvHandoff), which
    # launches mpv-htpc. Also mutes/unloads Stremio's own hidden player so
    # its server stops transcoding. Plugins may need enabling once in
    # stremio-enhanced's settings.
    xdg.configFile."stremio-enhanced/plugins/MpvHandoff.plugin.js".source =
      ../files/stremio-enhanced/MpvHandoff.plugin.js;

    programs.home-manager.enable = true;
  };
}
