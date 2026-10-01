{
  writeShellApplication,
  nix,
  nh,
  gh,
  jq,
  gum,
  openssh,
  age,
  age-plugin-fido2-hmac,
}:

let
  ensure-xcode-installed = writeShellApplication {
    name = "ensure-xcode-installed";
    text = builtins.readFile ./ensure-xcode-installed.bash;
  };

  ensure-ssh-key = writeShellApplication {
    name = "ensure-ssh-key";
    runtimeInputs = [ openssh ];
    text = builtins.readFile ./ensure-ssh-key.bash;
  };

  get-nix-config-secrets = writeShellApplication {
    name = "get-nix-config-secrets";
    runtimeInputs = [
      age
      age-plugin-fido2-hmac
      gh
    ];
    runtimeEnv.secrets_file = "${../../secrets/bootstrap-nix-config.age}";
    text = builtins.readFile ./get-nix-config-secrets.bash;
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
    get-nix-config-secrets
    ensure-ssh-key
    ensure-xcode-installed
    choose-darwin-configuration
  ];

  text = builtins.readFile ./install.bash;
}
