# Every services.htpc.* module. Imported by both flake.nix's
# nixosModules.default (for external consumers) and hosts/htpc/default.nix,
# so adding a module here is the only step needed to expose it in both.
# Everything is off by default — importing this is inert on its own.
{
  imports = [
    ./hardware/nvidia.nix
    ./desktop/bigscreen.nix

    ./media/mpv.nix
    ./media/library.nix
    ./media/stremio.nix
    ./media/aiostreams.nix
    ./media/arr.nix
    ./media/jellyfin.nix
    ./media/iptv.nix
    ./media/youtube.nix
    ./media/dvd.nix
    ./media/ota.nix
    ./media/gaming.nix

    ./system/fake-hwclock.nix
    ./network/protonvpn.nix
  ];
}
