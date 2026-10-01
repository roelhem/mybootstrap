{
  writeShellApplication,
  git,
  coreutils,
  curl,
}:

writeShellApplication {
  name = "clone-config-repos";
  runtimeInputs = [
    git
    coreutils
    curl
  ];

  text = builtins.readFile ./clone-config-repos.bash;
}
