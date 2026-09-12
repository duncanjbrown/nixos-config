{
  description = "duncan's NixOS config (OrbStack VMs)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    base16-shell = {
      url = "github:chriskempson/base16-shell/588691ba71b47e75793ed9edfcfaa058326a6f41";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, base16-shell }:
    let
      system = "aarch64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # Fixed attribute name shared by all machines: the hostname comes from
      # OrbStack's machine-local /etc/nixos/incus.nix, not from the flake.
      nixosConfigurations.orb = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit unstable base16-shell; };
        modules = [
          ./orbstack.nix
          ./configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };
    };
}
