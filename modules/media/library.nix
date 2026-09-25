{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.media.library;
  media = config.services.htpc.media;

  # Shared plumbing, not a feature of its own — so no enable option. It
  # switches itself on when any module that reads/writes the library is on.
  needed = media.arr.enable || media.jellyfin.server.enable || media.dvd.rip.enable;
in
{
  options.services.htpc.media.library = {
    dir = mkOption {
      type = types.str;
      default = "/srv/media";
      description = ''
        Root of the kept-copy media library. The Arr stack downloads into
        and organizes under it, DVD rips land in it, Jellyfin serves it.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Group shared by every service (and user) that touches the library.";
    };
  };

  config = mkIf needed {
    users.groups.${cfg.group} = { };

    # setgid (2775) so files created inside inherit the media group no matter
    # which service wrote them — Sonarr moving a file Transmission downloaded
    # that Jellyfin then reads is the normal path here.
    systemd.tmpfiles.rules = map (d: "d ${cfg.dir}${d} 2775 root ${cfg.group} -") [
      ""
      "/movies"
      "/tv"
      "/downloads"
      "/dvd-rips"
    ];
  };
}
