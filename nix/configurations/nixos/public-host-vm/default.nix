# Minimal NixOS configuration that hosts the public bootstrap scripts via the
# `mybootstrap.public-host` module. Only used to test that module in a local QEMU VM,
# not meant to be deployed anywhere.
{ ... }:

{
  imports = [ ../../../modules/nixos/public-host ];

  mybootstrap.public-host.enable = true;

  # The public-host module doesn't open the firewall itself, so do it here
  # for this test VM only.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  networking.hostName = "public-host-vm";

  # Run headless: no GUI window, output goes to the serial console.
  virtualisation.graphics = false;

  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 16080;
      guest.port = 80;
    }
    {
      from = "host";
      host.port = 16443;
      guest.port = 443;
    }
  ];

  system.stateVersion = "26.05";
}
