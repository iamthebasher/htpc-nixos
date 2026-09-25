{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.htpc.network.protonvpn;

  # endpoint is "IPv4:port" — nftables needs a literal IP (no hostnames:
  # there's no DNS before the tunnel is up anyway)
  endpointIp = elemAt (splitString ":" cfg.endpoint) 0;
  endpointPort = elemAt (splitString ":" cfg.endpoint) 1;
  lanSet = concatStringsSep ", " cfg.lanSubnets;
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
        sops-nix), or at minimum a root-only file outside the repo.
      '';
    };

    peerPublicKey = mkOption {
      type = types.str;
      description = "Server public key from the ProtonVPN WireGuard config export.";
    };

    endpoint = mkOption {
      type = types.str;
      example = "146.70.xxx.xxx:51820";
      description = "Server endpoint (host:port) from the ProtonVPN WireGuard config export.";
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
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.privateKeyFile != null;
        message = "services.htpc.network.protonvpn.privateKeyFile must point at a real secret (e.g. a sops-nix secret path), never a key committed to the repo.";
      }
    ];

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
    # purpose: pair this with services.htpc.system.fakeHwclock.enable so the
    # clock is close enough for the handshake to succeed without one. If
    # that's ever not enough, add a narrow `udp dport 123 ip daddr <server>
    # accept` line rather than opening NTP broadly.
    networking.firewall.enable = false;
    networking.nftables.enable = true;
    networking.nftables.ruleset = ''
      table inet killswitch {
        chain output {
          type filter hook output priority 0; policy drop;

          oifname "lo" accept
          ct state established,related accept

          # allow the initial WireGuard handshake to the VPN server
          ip daddr ${endpointIp} udp dport ${endpointPort} accept

          udp dport { 67, 68 } accept  # DHCP
          ${optionalString (cfg.lanSubnets != [ ]) "ip daddr { ${lanSet} } accept  # LAN"}

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
      }
    '';
  };
}
