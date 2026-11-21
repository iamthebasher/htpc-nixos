# The HTPC's disk layout, declared (disko). Used two ways:
#  - at install time, disko partitions/formats/mounts the disk from this file
#    (WIPES IT; see README "Reinstall"),
#  - on every build, it generates fileSystems."/" and "/boot", so
#    hardware-configuration.nix has no filesystem entries
#    (`nixos-generate-config --no-filesystems`).
#
# GPT + UEFI: a FAT32 ESP at /boot (Limine needs FAT; it can't read ext4)
# and ext4 for everything else. No swap partition, same as the old install;
# zram (compressed swap in RAM, default.nix) covers memory spikes.
{
  disko.devices.disk.main = {
    type = "disk";
    # Check with `lsblk` in the installer. A /dev/disk/by-id/nvme-... path
    # is safer if a second NVMe drive is ever added.
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G"; # room for many generations' kernels + initrds
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ]; # boot entries not world-readable
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
