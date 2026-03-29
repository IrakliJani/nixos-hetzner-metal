{
  description = "nixos-hetzner-metal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    irakli-home.url = "github:IrakliJani/home-manager";
    irakli-home.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { nixpkgs, disko, home-manager, irakli-home, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.hetzner-fsn1-ij1 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit irakli-home; };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./hosts/hetzner-fsn1-ij1/disko.nix
          ./hosts/hetzner-fsn1-ij1/default.nix
        ];
      };
    };
}
