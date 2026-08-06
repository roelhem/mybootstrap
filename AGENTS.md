# My Configuration Bootstrap

This is the public part of my bootstrap script for provisioning new systems. The goal for it is to
be a minimal, but complete way to: (Order depends on OS)

- Install `nix`.
- Install `tailscale` and login at my home network.
- Access the private parts of my nix-configurations.
- Hand over the rest of the bootstrapping to the private configuration.

## Planned Project Structure

- [nix/](./nix/) Contains all the nix modules, configurations and other plumbing that need to be public.
- [entrypoints/](./entrypoints/) Script files that will be published on my public website (at [mmrh.nl](https://mmrh.nl)).
- [packages/](./packages/) Other code needed for the bootstrap to work. Each package has its own
  as `packages/<package-name>/default.nix` file and is published under `packages` in [flake.nix](./flake.nix) using
  `pkgs.callPackage ./packages/<package-name> {}`.
- [flake.nix](./flake.nix) Main entrypoint for scripts that is used AFTER nix is installed successfully.
- [Justfile](./Justfile) Commands frequently used during maintenance of this repository. These commands will only be
  called from already provisioned machines.
- [README.org](./README.org) Small documentation to remind me how to activate this script.
