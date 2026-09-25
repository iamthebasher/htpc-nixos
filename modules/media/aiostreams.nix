{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.aiostreams;
  stateDir = "/var/lib/aiostreams";
in
{
  options.services.htpc.media.aiostreams = {
    enable = mkEnableOption ''
      a self-hosted AIOStreams instance (Stremio addon aggregator) running
      on this machine, reachable by the local Stremio client at
      http://localhost:<port>
    '';

    image = mkOption {
      type = types.str;
      default = "ghcr.io/viren070/aiostreams:latest";
      description = ''
        Container image. Not packaged in nixpkgs, so this runs as an OCI
        container. TODO: pin to a release tag (or a digest) instead of
        :latest once it's running — :latest isn't reproducible.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port AIOStreams listens on.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/aiostreams-env";
      description = ''
        Optional extra KEY=value env file (e.g. a sops secret) for settings
        that shouldn't be committed — debrid/indexer API keys, ADDON_PASSWORD.
        SECRET_KEY is generated automatically on first start and doesn't
        need to go here.
      '';
    };
  };

  config = mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.aiostreams = {
      image = cfg.image;
      environment = {
        PORT = toString cfg.port;
        BASE_URL = "http://localhost:${toString cfg.port}";
      };
      environmentFiles = [ "${stateDir}/secret.env" ]
        ++ optional (cfg.environmentFile != null) cfg.environmentFile;
      volumes = [ "${stateDir}/data:/app/data" ];
      # Host networking, not a published port: with the ProtonVPN killswitch
      # on, traffic over podman's bridge interface would be dropped (only lo
      # and the tunnel are allowed). On the host network, localhost works for
      # Stremio and the container's outbound scraping goes through the VPN
      # like everything else.
      extraOptions = [ "--network=host" ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${stateDir}/data 0700 root root -"
    ];

    # AIOStreams needs a stable 64-hex-char SECRET_KEY (it encrypts stored
    # user configs with it — changing it invalidates them). Generate once,
    # keep forever, never commit.
    systemd.services.podman-aiostreams.preStart = mkBefore ''
      if [ ! -s ${stateDir}/secret.env ]; then
        umask 077
        echo "SECRET_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${stateDir}/secret.env
      fi
    '';

    # The Stremio side is manual, by design: log the HTPC's Stremio client
    # into a dedicated account (not the one your phone/laptop use), open
    # http://localhost:${port}, build a config, and install the resulting
    # manifest URL into that account only. That keeps this LAN/localhost-only
    # addon from syncing to devices that can't reach it.
  };
}
