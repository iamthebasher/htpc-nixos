{
  description = "Asher's HTPC — declarative NixOS media center (Plasma Bigscreen, mpv pipeline, Stremio/IPTV/YouTube, Steam + Moonlight)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # nvidia drivers, steam, etc.
      };
    in
    {
      # The reusable half of this repo — every services.htpc.* option-gated
      # module, bundled into one importable unit. This is what someone else
      # consumes if they add this repo as a flake input to their OWN flake
      # instead of cloning it: `inputs.htpc-nixos.nixosModules.default` in
      # their `modules = [ ... ]` list, then they set services.htpc.*.enable
      # flags in their own host config — same as hosts/htpc/default.nix does
      # below, just from outside this repo. Nothing in here is specific to
      # this machine (no hostname, timezone, users, hardware-configuration).
      nixosModules.default = {
        imports = [
          ./modules/hardware/nvidia.nix
          ./modules/desktop/bigscreen.nix
          ./modules/media/mpv.nix
          ./modules/media/stremio.nix
          ./modules/media/gaming.nix
          ./modules/system/fake-hwclock.nix
          ./modules/network/protonvpn.nix
        ];
      };

      # The concrete half — this actual machine. Not meant to be imported by
      # anyone else; it's the "instance" that uses nixosModules.default above,
      # the same way an external consumer's own host file would.
      nixosConfigurations = {
        htpc = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/htpc/default.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };
    };
}
