{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.stremio;
in
{
  options.services.htpc.media.stremio = {
    enable = mkEnableOption "Stremio client, configured to hand off playback to mpv-htpc";

    package = mkOption {
      type = types.package;
      default = pkgs.stremio;
      defaultText = literalExpression "pkgs.stremio";
      description = ''
        Stremio build to install. The HTPC host swaps in stremio-enhanced
        from a third-party flake (it isn't in nixpkgs); this module stays
        free of that input so it's reusable with plain nixpkgs.
      '';
    };

    addonUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://localhost:3000/stremio/<uuid>/<config>/manifest.json";
      description = ''
        Manifest URL of a self-hosted AIOStreams instance (or any other addon
        endpoint). Informational only for now — nothing reads it yet, since
        Stremio addons are installed per-account in-app, not via config
        files. AIOStreams manifest URLs embed a per-user config token, so
        don't commit a real one.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.htpc.media.mpv.enable;
        message = "services.htpc.media.stremio requires services.htpc.media.mpv.enable = true (external-player handoff target).";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # Plain Stremio: point Settings -> Player -> External player at
    # /run/current-system/sw/bin/mpv-htpc by hand on first launch.
    # stremio-enhanced: TODO — the old setup hands playback to mpv via a
    # custom plugin; port it here (and point it at mpv-htpc) once available.
  };
}
