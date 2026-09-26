{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.stremio;

  # Receives stream URLs from the MpvHandoff stremio-enhanced plugin
  # (files/stremio-enhanced/) and plays them in mpv-htpc. One player at a
  # time: a new URL replaces whatever the listener launched before.
  handoffListener = pkgs.writers.writePython3Bin "stremio-mpv-handoff"
    { flakeIgnore = [ "E501" ]; } ''
    import subprocess
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from urllib.parse import urlparse, parse_qs

    MPV = "${config.services.htpc.media.mpv.package}/bin/mpv-htpc"
    player = None


    def stop_player():
        if player is not None and player.poll() is None:
            player.terminate()
            try:
                player.wait(timeout=3)
            except subprocess.TimeoutExpired:
                player.kill()


    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            global player
            req = urlparse(self.path)
            url = parse_qs(req.query).get("url", [""])[0]
            # Only play http(s) URLs. Anything else on this port, like a
            # web page probing localhost, gets a 400.
            if req.path != "/play" or urlparse(url).scheme not in ("http", "https"):
                self.send_response(400)
                self.end_headers()
                return
            stop_player()
            player = subprocess.Popen([MPV, "--", url])
            self.send_response(204)
            self.end_headers()

        def log_message(self, fmt, *args):
            print(fmt % args, flush=True)


    HTTPServer(("127.0.0.1", ${toString cfg.mpvHandoff.port}), Handler).serve_forever()
  '';
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

    mpvHandoff = {
      enable = mkEnableOption ''
        the handoff listener for stremio-enhanced's MpvHandoff plugin: a
        per-user service on 127.0.0.1 that plays the URLs the plugin sends
        in mpv-htpc (the plugin file itself is deployed by home-manager)
      '';

      port = mkOption {
        type = types.port;
        default = 7777;
        description = "Localhost port the listener binds. Must match LISTENER in the plugin.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = config.services.htpc.media.mpv.enable;
          message = "services.htpc.media.stremio requires services.htpc.media.mpv.enable = true (external-player handoff target).";
        }
      ];

      environment.systemPackages = [ cfg.package ];

      # Plain Stremio: point Settings -> Player -> External player at
      # /run/current-system/sw/bin/mpv-htpc by hand on first launch.
      # stremio-enhanced: use mpvHandoff below instead.
    }

    (mkIf cfg.mpvHandoff.enable {
      # A user service, not a system one: mpv has to open a window in the
      # logged-in user's Wayland session.
      systemd.user.services.stremio-mpv-handoff = {
        description = "Stremio -> mpv-htpc handoff listener";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${handoffListener}/bin/stremio-mpv-handoff";
          Restart = "on-failure";
        };
      };
    })
  ]);
}
