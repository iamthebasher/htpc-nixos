{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.stremio;

  # Receives stream URLs from the Stremio Enhanced handoff plugins
  # (files/stremio-enhanced/MpvHandoff*.plugin.js) and plays them in
  # mpvHandoff.player (mpv-htpc by default).
  # GET /play?url= starts a stream; GET /status reports whether mpv is open. One player at a
  # time: a new URL replaces whatever the listener launched before.
  handoffListener = pkgs.writers.writePython3Bin "stremio-mpv-handoff"
    { flakeIgnore = [ "E501" ]; } ''
    import json
    import subprocess
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from urllib.parse import urlparse, parse_qs

    MPV = "${cfg.mpvHandoff.player}"
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
            # Polled by the plugins once a second during playback, so they
            # can leave Stremio's player screen when mpv closes. CORS so the
            # page can read the reply; all it reveals is whether mpv is open.
            if req.path == "/status":
                body = json.dumps({"playing": player is not None and player.poll() is None}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
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
            if self.path.startswith("/status"):
                return  # once a second during playback; would flood the journal
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
        Stremio build to install. The HTPC host uses Stremio Enhanced on the
        native shell (pkgs/stremio-linux-shell-enhanced in this repo, not in
        nixpkgs); the default keeps this module usable with plain nixpkgs.
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
        the handoff listener for the Stremio Enhanced MpvHandoff plugins: a
        per-user service on 127.0.0.1 that plays the URLs the plugin sends
        in mpv-htpc (the plugin file itself is deployed by home-manager)
      '';

      player = mkOption {
        type = types.str;
        default = "${config.services.htpc.media.mpv.package}/bin/mpv-htpc";
        defaultText = literalExpression ''"''${config.services.htpc.media.mpv.package}/bin/mpv-htpc"'';
        example = literalExpression ''"''${pkgs.mpv}/bin/mpv"'';
        description = ''
          Player the listener runs with the stream URL. The default is this
          repo's mpv-htpc (needs services.htpc.media.mpv.enable). On a
          machine without it, point this at a plain mpv, which then uses
          that user's own ~/.config/mpv.
        '';
      };

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
          # only the default handoff player is mpv-htpc
          assertion = (cfg.mpvHandoff.enable && hasSuffix "/bin/mpv-htpc" cfg.mpvHandoff.player)
            -> config.services.htpc.media.mpv.enable;
          message = "services.htpc.media.stremio.mpvHandoff plays in mpv-htpc by default, which needs services.htpc.media.mpv.enable = true. Or set mpvHandoff.player to another mpv.";
        }
      ];

      environment.systemPackages = [ cfg.package ];

      # Plain Stremio: point Settings -> Player -> External player at
      # /run/current-system/sw/bin/mpv-htpc by hand on first launch.
      # Stremio Enhanced: use mpvHandoff below and its plugin instead.
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
