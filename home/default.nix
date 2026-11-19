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

    # Stremio Enhanced plugins (pkgs/stremio-linux-shell-enhanced):
    # - MpvHandoffShell: catches Stremio's play command to the built-in
    #   player and sends the stream to the handoff listener on 127.0.0.1:7777
    #   (services.htpc.media.stremio.mpvHandoff), which runs mpv-htpc. Backs
    #   out of Stremio's player screen when mpv closes.
    # - RemoteKeys: remote Back/Search/List/Home while browsing Stremio.
    # (files/stremio-enhanced/MpvHandoff.plugin.js is the older plugin for
    # the Electron build, kept for anyone still on that.)
    xdg.configFile."stremio-enhanced/plugins/MpvHandoffShell.plugin.js".source =
      ../files/stremio-enhanced/MpvHandoffShell.plugin.js;
    xdg.configFile."stremio-enhanced/plugins/RemoteKeys.plugin.js".source =
      ../files/stremio-enhanced/RemoteKeys.plugin.js;

    # New plugins start disabled, and switching them on in Stremio's settings
    # needs a mouse. settings.json can't be a home-manager file because the
    # app writes to it (theme, marketplace plugins), so set just these keys
    # on every activation and leave the rest alone.
    home.activation.stremioEnablePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.config/stremio-enhanced/settings.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
      if new=$(${pkgs.jq}/bin/jq '
          .enabledPlugins = ((.enabledPlugins // {}) + {
            "MpvHandoffShell.plugin.js": true,
            "RemoteKeys.plugin.js": true
          })
          | .activeTheme = (.activeTheme // null)' "$f"); then
        run sh -c 'printf "%s\n" "$2" > "$1"' _ "$f" "$new"
      else
        warnEcho "stremio: $f isn't valid JSON, plugins not enabled"
      fi
    '';

    programs.home-manager.enable = true;
  };
}
