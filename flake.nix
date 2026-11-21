{
  description = "Asher's HTPC — declarative NixOS media center (Hyprland + quickshell, mpv pipeline, Stremio/IPTV/YouTube, Steam + Moonlight)";

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

    # Declarative flatpaks (plain NixOS can only enable flatpak, not choose
    # which apps are installed). Here for Fred TV, which isn't in nixpkgs.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Declarative partitioning: hosts/htpc/disko.nix formats the disk at
    # install time and provides fileSystems on every build.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nix-flatpak, disko, ... }@inputs:
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

      # home-manager side: the Stremio Enhanced plugins
      # (programs.stremio-enhanced.plugins). Pairs with
      # services.htpc.media.stremio.mpvHandoff for the handoff plugin.
      homeManagerModules.stremio-enhanced = import ./modules/home/stremio-enhanced.nix;

      # Packages this repo builds that nixpkgs doesn't have. Usable on any
      # machine: `nix build .#stremio-linux-shell-enhanced`, or
      # `nix run .#stremio-linux-shell-enhanced`. (Nothing here is unfree,
      # so plain legacyPackages is fine despite the note above.)
      packages.${system}.stremio-linux-shell-enhanced =
        nixpkgs.legacyPackages.${system}.callPackage ./pkgs/stremio-linux-shell-enhanced { };

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
            nix-flatpak.nixosModules.nix-flatpak
            disko.nixosModules.disko
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
