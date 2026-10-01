{
  writeShellApplication,
  nix,
  nh,
  gh,
  ensure-xcode-installed,
}:

writeShellApplication {
  name = "install";
  runtimeInputs = [
    # Bring our own `nix` for `nh`, rather than relying on the host's install being on PATH.
    nix
    nh
    gh
    ensure-xcode-installed
  ];

  text = builtins.readFile ./install.bash;
}
