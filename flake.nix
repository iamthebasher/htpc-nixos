{
  description = "Asher's HTPC — declarative NixOS media center (Plasma Bigscreen, mpv pipeline, Stremio/IPTV/YouTube, Steam + Moonlight)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secrets committed to the repo, decrypted at activation into
    # /run/secrets. See .sops.yaml and hosts/htpc/secrets.nix.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    let
      system = "x86_64-linux";
      # No `pkgs` binding here on purpose: lib.nixosSystem builds its own pkgs
      # from the module system's nixpkgs.config, so allowUnfree set on a pkgs
      # in this let block never reaches the system. It lives in
      # hosts/htpc/default.nix instead.
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
      # The module list itself lives in modules/default.nix so this and
      # hosts/htpc/default.nix import the exact same set.
      nixosModules.default = import ./modules;

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
            sops-nix.nixosModules.sops
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
