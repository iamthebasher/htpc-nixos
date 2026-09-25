# sops-nix secrets for this host, plus the modules that can't run without
# them. Imported from ./default.nix once secrets/htpc.yaml exists.
#
# Secrets are decrypted at activation into /run/secrets/<name> (tmpfs, never
# the Nix store). Modules only ever get the *path* — see README "Secrets setup".
{ config, lib, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/htpc.yaml;

    # This machine's own age key, generated once on the HTPC with
    #   sudo mkdir -p /var/lib/sops-nix
    #   sudo age-keygen -o /var/lib/sops-nix/key.txt
    # Its public half goes in .sops.yaml. Not derived from the SSH host key
    # because this box doesn't run sshd.
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      protonvpn-private-key = { }; # root-only by default, which wg-quick wants

      iptv-playlist-url = {
        owner = "htpc"; # read by the `iptv` launcher, which runs as the user
      };
    };
  };

  services.htpc.network.protonvpn = {
    enable = true;
    privateKeyFile = config.sops.secrets.protonvpn-private-key.path;

    # From ProtonVPN's WireGuard config export. Not secret (the private key
    # is the only secret part), so these are plain values — fill them in.
    interfaceAddress = "10.2.0.2/32";
    peerPublicKey = "REPLACE-ME";
    endpoint = "REPLACE-ME:51820"; # must be an IP, not a hostname

    # the home LAN — adjust to the real subnet
    lanSubnets = [ "192.168.1.0/24" ];
  };

  services.htpc.media.iptv = {
    enable = true;
    playlistUrlFile = config.sops.secrets.iptv-playlist-url.path;
  };
}
