{ writeShellApplication }:

writeShellApplication {
  name = "ensure-xcode-installed";

  text = builtins.readFile ./ensure-xcode-installed.bash;
}
