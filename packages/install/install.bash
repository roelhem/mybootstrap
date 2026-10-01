# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.

# This runs as root (via sudo), so the user to install the configuration for is the one that
# invoked sudo, not $USER.
target_user="${SUDO_USER:-}"
if [ -z "$target_user" ] || [ "$target_user" = root ]; then
    printf '\033[31minstall failed: run this via sudo from the target (non-root) user.\033[0m\n' >&2
    exit 1
fi

# sudo resets the environment, so pass PATH (for the bundled nix and gh) and NIX_CONFIG through
# explicitly whenever a command runs as the target user.
as_target_user() {
    sudo -u "$target_user" -H env PATH="$PATH" NIX_CONFIG="${NIX_CONFIG:-}" "$@"
}

# Log in to GitHub as the target user (so gh's credentials end up in their home), skipping the
# interactive login if they already are.
if as_target_user gh auth status --hostname github.com >/dev/null 2>&1; then
    printf '\033[36m==> %s\033[0m\n' 'Already logged in to GitHub.'
else
    printf '\033[36m==> %s\033[0m\n' 'Logging in to GitHub...'
    as_target_user gh auth login --hostname github.com --git-protocol https
fi
github_token=$(as_target_user gh auth token --hostname github.com)

# A fresh Nix install doesn't enable flakes yet, which `nh` (and the flakes it builds) rely on,
# and the GitHub token lets nix fetch private repositories. Append rather than overwrite, to
# keep any NIX_CONFIG the caller already set.
export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}experimental-features = nix-command flakes
access-tokens = github.com=$github_token"

ensure-xcode-installed
# nh refuses to run as root and calls sudo itself when needed, so drop back to the target user.
# `--refresh` bypasses nix's (1 hour) flake cache, so the latest pushed myconf is always used.
as_target_user nh darwin switch 'github:roelhem/myconf#default' -- --refresh
