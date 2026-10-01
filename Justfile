import? 'local.just'

_default:
    @just --list

[group('Dependencies')]
update-flake *args:
    nix flake update {{ args }}

rekey:
    cd ./secrets && agenix -r
