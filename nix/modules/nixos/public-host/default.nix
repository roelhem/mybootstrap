# Module intended to be imported by the host that will serve the
# public bootstrap scripts.
{
  config,
  lib,
  pkgs,
  ...
}:

let

  inherit (lib) mkOption mkDefault types;

  cfg = config.mybootstrap.public-host;

in

{
  options.mybootstrap.public-host = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the public hosting of bootstrap scripts.

        This will only include some extra configuration to the
        nginx virtual host set by the domain option.
      '';
    };

    domain = mkOption {
      type = types.str;
      default = "mmrh.nl";
      description = ''
        Domain name of the public host. This is also used as
        the name for the nginx vhost.
      '';
    };

    nginxConfigPackage = mkOption {
      type = types.path;
      default = pkgs.callPackage ../../../../entrypoints { };
      description = ''
        Path to the nginx config file that configures how
        the public host should be served.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = mkDefault true;

    services.nginx.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        include ${cfg.nginxConfigPackage};
      '';
    };
  };
}
