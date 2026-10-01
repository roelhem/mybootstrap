{
  writeShellApplication,
  tailscale,
  curl,
}:

writeShellApplication {
  name = "with-home-network";
  runtimeInputs = [
    tailscale
    curl
  ];

  text = builtins.readFile ./with-home-network.bash;
}
