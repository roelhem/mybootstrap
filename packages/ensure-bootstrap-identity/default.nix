{
  writeShellApplication,
  age,
  age-plugin-fido2-hmac,
}:

writeShellApplication {
  name = "ensure-bootstrap-identity";
  runtimeInputs = [
    age
    age-plugin-fido2-hmac
  ];
  runtimeEnv.identity_secret_file = "${../../secrets/bootstrap-identity.age}";

  text = builtins.readFile ./ensure-bootstrap-identity.bash;
}
