# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.

# This runs as root (via sudo), so the user that should own the config repos is the one that
# invoked sudo, not $USER.
target_user="${SUDO_USER:-}"
if [ -z "$target_user" ] || [ "$target_user" = root ]; then
    printf '\033[31minstall failed: run this via sudo from the target (non-root) user.\033[0m\n' >&2
    exit 1
fi
target_home=$(eval echo "~$target_user")

ensure-xcode-installed
# `su` doesn't keep this script's PATH, so pass the full store path of the command.
with-home-network su "$target_user" -c "$(command -v clone-config-repos)"
nh darwin switch "$target_home/workspace/roelhem/myconf#default"
