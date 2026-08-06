{
  description = "Entry points for provisioning new machines with my personal configuration.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
            pkgs,
            lib,
            ...
          }:
          {
            packages.entrypoints = pkgs.callPackage ./entrypoints { };

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
              packages = with pkgs; [ just ];
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
