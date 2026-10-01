{
  description = "Entry points for provisioning new machines with my personal configuration.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-parts,
      systems,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, config, ... }: {

        imports = [ ];

        systems = import systems;

        flake = {

          nixosModules.public-host = ./nix/modules/nixos/public-host;

          nixosConfigurations.public-host-vm = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
              ./nix/configurations/nixos/public-host-vm
            ];
          };
        };

        perSystem =
          {
            self',
            inputs',
            pkgs,
            lib,
            ...
          }:
          {
            packages.entrypoints = pkgs.callPackage ./entrypoints { };

            packages.with-home-network = pkgs.callPackage ./packages/with-home-network { };
            packages.ensure-bootstrap-identity = pkgs.callPackage ./packages/ensure-bootstrap-identity { };
            packages.install = pkgs.callPackage ./packages/install {
              inherit (self'.packages) ensure-bootstrap-identity;
            };

            apps.install = {
              type = "app";
              program = "${self'.packages.install}/bin/install";
              meta.description = "Install script entrypoint";
            };

            apps.ensure-identity = {
              type = "app";
              program = lib.getExe self'.packages.ensure-bootstrap-identity;
              meta.description = "Decrypt the bootstrap identity (if needed) and print its path";
            };

            apps.public-host-vm =
              let
                # Re-evaluate the VM with its QEMU launcher script built for *this*
                # perSystem's host platform (e.g. darwin), while the guest itself
                # stays x86_64-linux. Without this, the launcher is a Linux ELF
                # binary that can't be executed on non-Linux hosts.
                vm = self.nixosConfigurations.public-host-vm.extendModules {
                  modules = [ { virtualisation.host.pkgs = pkgs; } ];
                };
              in
              {
                type = "app";
                program = lib.getExe vm.config.system.build.vm;
                meta.description = "Run the public-host-vm NixOS test VM in QEMU (headless)";
              };

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                just
                inputs'.agenix.packages.default
              ];
            };
          };
      }
    );

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://roelhem.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "roelhem.cachix.org-1:6UktCbfTJhgub82/RuVYKw6645qrrEwDGJMjhBQYYCA="
    ];

    allow-import-from-derivation = "true";
  };
}
