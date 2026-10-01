# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.

# Runs as the user to install the configuration for; commands that need root call sudo
# themselves (nh does so for activation).
if [ "$(id -u)" -eq 0 ]; then
    printf '\033[31minstall failed: do not run this as root, it calls sudo when needed.\033[0m\n' >&2
    exit 1
fi

# Log in to GitHub, skipping the interactive login if already logged in.
if gh auth status --hostname github.com >/dev/null 2>&1; then
    printf '\033[36m==> %s\033[0m\n' 'Already logged in to GitHub.'
else
    printf '\033[36m==> %s\033[0m\n' 'Logging in to GitHub...'
    gh auth login --hostname github.com --git-protocol https
fi
github_token=$(gh auth token --hostname github.com)

# A fresh Nix install doesn't enable flakes yet, which `nh` (and the flakes it builds) rely on,
# and the GitHub token lets nix fetch private repositories. Append rather than overwrite, to
# keep any NIX_CONFIG the caller already set.
export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}experimental-features = nix-command flakes
access-tokens = github.com=$github_token"

ensure-ssh-key
ensure-xcode-installed

myconf_flake='github:roelhem/myconf'
configuration=$(choose-darwin-configuration "$myconf_flake")
printf '\033[36m==> %s\033[0m\n' "Activating $myconf_flake#$configuration..."
# `--refresh` bypasses nix's (1 hour) flake cache, so the latest pushed myconf is always used.
nh darwin switch "$myconf_flake#$configuration" -- --refresh
