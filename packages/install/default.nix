{
  writeShellApplication,
  nh,
  ensure-xcode-installed,
  with-home-network,
  clone-config-repos,
}:

writeShellApplication {
  name = "install";
  runtimeInputs = [
    nh
    ensure-xcode-installed
    with-home-network
    clone-config-repos
  ];

  text = builtins.readFile ./install.bash;
}
