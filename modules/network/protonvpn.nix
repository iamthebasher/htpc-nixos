{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.network.protonvpn;
  split = cfg.splitTunnel;

  # endpoint is "IPv4:port" — nftables needs a literal IP (no hostnames:
  # there's no DNS before the tunnel is up anyway)
  endpointIp = elemAt (splitString ":" cfg.endpoint) 0;
  endpointPort = elemAt (splitString ":" cfg.endpoint) 1;
  lanSet = concatStringsSep ", " cfg.lanSubnets;

  # wg-quick's own fwmark (Table = auto). Its policy routing sends every
  # packet WITHOUT this mark into the tunnel's table; packets WITH it use
  # the normal routing table. Marking bypass traffic with it is the whole
  # split tunnel.
  wgMark = "51820";
  gid = toString split.gid;
  # in-tunnel DNS stays in the tunnel even for bypass apps: it's only
  # reachable there, and resolv.conf points at it while the VPN is up
  dnsV4 = filter (a: !(hasInfix ":" a)) cfg.dns;

  novpn = pkgs.writeShellScriptBin "novpn" ''
    # novpn <command> [args...]: run a program outside the VPN.
    if [ $# -eq 0 ]; then
      echo "usage: novpn <command> [args...]" >&2
      exit 2
    fi
    exec /run/wrappers/bin/sg ${split.group} -c "exec $(printf '%q ' "$@")"
  '';
in
{
  options.services.htpc.network.protonvpn = {
    enable = mkEnableOption ''
      whole-system, always-on ProtonVPN via native WireGuard + a declarative
      nftables killswitch, replacing the flatpak GUI app's (non-reproducible)
      killswitch toggle.
    '';

    interfaceAddress = mkOption {
      type = types.str;
      example = "10.2.0.2/32";
      description = "This device's tunnel address, from ProtonVPN's WireGuard config export.";
    };

    privateKeyFile = mkOption {
      type = types.path;
      example = "/run/secrets/protonvpn-private-key";
      description = ''
        Path to a file containing ONLY the WireGuard private key from
        ProtonVPN's config export. Never commit the key itself — point this
        at a sops-nix/agenix secret (hosts/htpc/secrets.nix does this with
        sops-nix), or at minimum a root-only file outside the repo. Give it
        as a string ("/var/lib/..."), not a Nix path literal, or the key is
        copied into the world-readable Nix store.
      '';
    };

    peerPublicKey = mkOption {
      type = types.str;
      description = "Server public key from the ProtonVPN WireGuard config export.";
    };

    endpoint = mkOption {
      type = types.str;
      example = "146.70.xxx.xxx:51820";
      description = "Server endpoint (IPv4:port) from the ProtonVPN WireGuard config export.";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [ "10.2.0.1" ]; # ProtonVPN's in-tunnel resolver from their config export
      description = "DNS servers to use while the tunnel is up (prevents DNS leaks outside it).";
    };

    lanSubnets = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "192.168.1.0/24" ];
      description = ''
        IPv4 LAN ranges allowed in and out outside the tunnel. Without this,
        the killswitch blocks everything local too: Moonlight to Balthasar,
        phones reaching Jellyfin/Arr web UIs, the HDHomeRun tuner, Steam
        Remote Play. Keep it to your actual LAN — anything listed here
        bypasses the VPN.
      '';
    };

    splitTunnel = {
      enable = mkEnableOption ''
        per-app VPN bypass: programs started with `novpn <command>` use the
        normal connection instead of the tunnel, and the killswitch lets
        them through. Everything else stays in the VPN
      '';

      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "asher" ];
        description = ''
          Users allowed to use `novpn`. They're made members of the bypass
          group, which is what lets `sg` switch to it without a password.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "novpn";
        description = "Group whose processes bypass the VPN.";
      };

      gid = mkOption {
        type = types.int;
        default = 51820;
        description = "Fixed GID for the group, so the nftables rules can name it by number.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      networking.wg-quick.interfaces.protonvpn = {
        address = [ cfg.interfaceAddress ];
        dns = cfg.dns;
        privateKeyFile = cfg.privateKeyFile;
        autostart = true;

        peers = [{
          publicKey = cfg.peerPublicKey;
          endpoint = cfg.endpoint;
          allowedIPs = [ "0.0.0.0/0" "::/0" ];
        }];
      };

      # Killswitch: deny-by-default nftables replacing NixOS's normal
      # allow-by-default firewall. The one exception besides loopback/LAN
      # basics is the VPN endpoint itself, so wg-quick can bring the tunnel
      # up in the first place — everything else must go through the `protonvpn`
      # interface or it doesn't go anywhere. No blanket NTP exception here on
      # purpose: pair this with services.htpc.system.fakeHwclock.enable on a
      # machine with a dead CMOS battery so the clock is close enough for
      # the handshake to succeed without one. If that's ever not enough, add
      # a narrow `udp dport 123 ip daddr <server> accept` line rather than
      # opening NTP broadly.
      #
      # Its own table (networking.nftables.tables), not a whole ruleset:
      # a ruleset reload starts with "flush ruleset", which would also
      # delete the table wg-quick adds for the tunnel.
      networking.firewall.enable = false;
      networking.nftables.enable = true;
      networking.nftables.tables.killswitch = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority 0; policy drop;

            oifname "lo" accept
            ct state established,related accept

            # allow the initial WireGuard handshake to the VPN server
            ip daddr ${endpointIp} udp dport ${endpointPort} accept

            udp dport { 67, 68 } accept  # DHCP
            ${optionalString (cfg.lanSubnets != [ ]) "ip daddr { ${lanSet} } accept  # LAN"}
            ${optionalString split.enable "meta skgid ${gid} accept  # novpn apps"}

            oifname "protonvpn" accept
          }

          chain input {
            type filter hook input priority 0; policy drop;

            iifname "lo" accept
            ct state established,related accept

            udp sport { 67, 68 } accept  # DHCP
            ${optionalString (cfg.lanSubnets != [ ]) "ip saddr { ${lanSet} } accept  # LAN"}

            iifname "protonvpn" accept
          }
        '';
      };
    }

    (mkIf split.enable {
      users.groups.${split.group} = {
        gid = split.gid;
        members = split.users;
      };

      environment.systemPackages = [ novpn ];

      # How the bypass works, packet by packet:
      # - route_out: a packet from a process in the bypass group gets
      #   wg-quick's mark, and a "route" chain re-runs routing after a mark
      #   change, so it leaves by the normal interface instead of the tunnel.
      #   The connection is tagged too (ct mark).
      # - prerouting: replies on tagged connections get the mark back, so
      #   reverse-path filtering checks them against the normal table.
      # - nat: the app picked the tunnel's address as its source before the
      #   reroute, so rewrite it to the real interface's address. Only the
      #   first packet of a connection reaches a nat chain; that's enough.
      networking.nftables.tables.vpn-bypass = {
        family = "inet";
        content = ''
          chain route_out {
            type route hook output priority mangle; policy accept;
            ${optionalString (dnsV4 != [ ]) "meta skgid ${gid} ip daddr { ${concatStringsSep ", " dnsV4} } return"}
            meta skgid ${gid} meta mark set ${wgMark} ct mark set ${wgMark}
          }

          chain prerouting {
            type filter hook prerouting priority mangle; policy accept;
            ct mark ${wgMark} meta mark set ${wgMark}
          }

          chain nat {
            type nat hook postrouting priority srcnat; policy accept;
            meta skgid ${gid} oifname != { "protonvpn", "lo" } masquerade
          }
        '';
      };
    })
  ]);
}
