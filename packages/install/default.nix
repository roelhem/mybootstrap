{
  writeShellApplication,
  nix,
  nh,
  ensure-xcode-installed,
  with-home-network,
  clone-config-repos,
}:

writeShellApplication {
  name = "install";
  runtimeInputs = [
    # Bring our own `nix` for `nh`, rather than relying on the host's install being on PATH.
    nix
    nh
    ensure-xcode-installed
    with-home-network
    clone-config-repos
  ];

  text = builtins.readFile ./install.bash;
}
