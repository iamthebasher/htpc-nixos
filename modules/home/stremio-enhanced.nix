# home-manager module: deploys this repo's Stremio Enhanced plugins and
# switches them on. Used by home/default.nix (the HTPC) and exported as
# homeManagerModules.stremio-enhanced for other machines.
#
# Plugins (files/stremio-enhanced/):
# - MpvHandoffShell: catches Stremio's play command to the built-in player
#   and sends the stream to the handoff listener on 127.0.0.1:7777
#   (services.htpc.media.stremio.mpvHandoff), which runs mpv. Backs out of
#   Stremio's player screen when mpv closes.
# - RemoteKeys: remote Back/Search/List/Home while browsing Stremio.
# - MpvHandoff: the older handoff plugin, for the Electron build.
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.stremio-enhanced;
  file = name: "${name}.plugin.js";
in
{
  options.programs.stremio-enhanced.plugins = lib.mkOption {
    type = lib.types.listOf (lib.types.enum [ "MpvHandoffShell" "RemoteKeys" "MpvHandoff" ]);
    default = [ ];
    example = [ "MpvHandoffShell" "RemoteKeys" ];
    description = "Plugins from this repo to install into ~/.config/stremio-enhanced/plugins and enable.";
  };

  config = lib.mkIf (cfg.plugins != [ ]) {
    xdg.configFile = lib.listToAttrs (map
      (name: lib.nameValuePair "stremio-enhanced/plugins/${file name}" {
        source = ../../files/stremio-enhanced/${file name};
      })
      cfg.plugins);

    # New plugins start disabled, and switching them on in Stremio's settings
    # needs a mouse. settings.json can't be a home-manager file because the
    # app writes to it (theme, marketplace plugins), so set just these keys
    # on every activation and leave the rest alone.
    home.activation.stremioEnablePlugins =
      let
        enabled = builtins.toJSON (lib.genAttrs (map file cfg.plugins) (_: true));
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        f="$HOME/.config/stremio-enhanced/settings.json"
        run mkdir -p "$(dirname "$f")"
        [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
        if new=$(${pkgs.jq}/bin/jq --argjson on ${lib.escapeShellArg enabled} '
            .enabledPlugins = ((.enabledPlugins // {}) + $on)
            | .activeTheme = (.activeTheme // null)' "$f"); then
          run sh -c 'printf "%s\n" "$2" > "$1"' _ "$f" "$new"
        else
          warnEcho "stremio: $f isn't valid JSON, plugins not enabled"
        fi
      '';
  };
}
