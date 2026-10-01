{
  writeShellApplication,
  nix,
  nh,
  gh,
  jq,
  gum,
}:

let
  ensure-xcode-installed = writeShellApplication {
    name = "ensure-xcode-installed";
    text = builtins.readFile ./ensure-xcode-installed.bash;
  };

  choose-darwin-configuration = writeShellApplication {
    name = "choose-darwin-configuration";
    runtimeInputs = [
      nix
      jq
      gum
    ];
    text = builtins.readFile ./choose-darwin-configuration.bash;
  };
in
writeShellApplication {
  name = "install";
  runtimeInputs = [
    # Bring our own `nix` for `nh`, rather than relying on the host's install being on PATH.
    nix
    nh
    gh
    ensure-xcode-installed
    choose-darwin-configuration
  ];

  text = builtins.readFile ./install.bash;
}
