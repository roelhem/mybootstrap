# Derivation containing exactly the files that get published on https://mmrh.nl.
#
# Consumed by other repositories (e.g. the private nginx virtual host config) as this flake's
# `entrypoints` package, typically served as the `root` of a location block. See
# ./nginx/bootstrap-scripts.conf for the matching nginx snippet, or just use the
# `entrypoints-nginx-configuration` package below, which already has that snippet's
# @bootstrapScriptsRoot@ placeholder substituted with this derivation's store path.
{ stdenvNoCC, runCommand }:

let

  entrypointsPublicDir = stdenvNoCC.mkDerivation {
    pname = "mybootstrap-entrypoints-public";
    version = "0-unstable";

    src = ./www;

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  entrypoints-nginx-configuration = runCommand "mybootstrap-entrypoints-nginx.conf" { } ''
    sed 's|@bootstrapScriptsRoot@|${entrypointsPublicDir}|g' ${./nginx/bootstrap-scripts.conf} > $out
  '';

in

entrypoints-nginx-configuration.overrideAttrs (attrs: {
  passthru = (attrs.passthru or { }) // {
    inherit entrypointsPublicDir;
  };
})
