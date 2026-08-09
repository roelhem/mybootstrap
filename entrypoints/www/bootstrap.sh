#!/bin/sh
# Public bootstrap entrypoint for provisioning new macOS/Linux machines with my personal
# configuration.
#
# This script:
#   1. Checks that it is running on a supported OS (macOS or Linux).
#   2. Installs Nix if it isn't already present, using the official installer's unattended flags.
#   3. Hands the rest of the provisioning over to this flake's `init` app.
#
# Invoked as:
#   curl https://mmrh.nl/bootstrap.sh | sh

set -eu

MYBOOTSTRAP_FLAKE='github:roelhem/mybootstrap'

step() {
    printf '\033[36m==> %s\033[0m\n' "$1"
}

fail() {
    printf '\033[31mBootstrap failed: %s\033[0m\n' "$1" >&2
    exit 1
}

# STEP 1: fail fast on unsupported platforms instead of failing deep inside the Nix install.
assert_system_supported() {
    step 'Checking system requirements...'
    case "$(uname -s)" in
    Darwin | Linux) ;;
    *) fail "Unsupported OS: $(uname -s). This script only supports macOS and Linux." ;;
    esac
}

# STEP 2: install Nix if it isn't already, using the official installer's unattended flags.
install_nix() {
    if command -v nix >/dev/null 2>&1; then
        step 'Nix is already installed.'
        return
    fi

    step 'Installing Nix...'
    curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh -s -- --daemon --yes

    # The installer only wires `nix` into PATH via new shells (by editing /etc/zshrc,
    # /etc/bashrc, etc, which are sourced by *interactive* shells) - it cannot reach back into
    # this already-running one. Source its own profile script to pick that up right now, since
    # step 3 needs `nix` immediately rather than in a freshly opened shell.
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        # shellcheck disable=SC1091
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # Belt and suspenders: that profile script no-ops under some conditions (e.g. $HOME unset).
    # Make sure the canonical bin dir is on PATH regardless of whether it did anything.
    case ":$PATH:" in
    *:/nix/var/nix/profiles/default/bin:*) ;;
    *) export PATH="/nix/var/nix/profiles/default/bin:$PATH" ;;
    esac

    if ! command -v nix >/dev/null 2>&1; then
        fail 'Nix was installed but is still not on PATH.'
    fi
}

# STEP 3: hand off the rest of the provisioning to the flake's own init action.
run_init() {
    step "Handing off to ${MYBOOTSTRAP_FLAKE}#install..."
    nix run --extra-experimental-features 'nix-command flakes' "${MYBOOTSTRAP_FLAKE}#install" -- "$@"
}

main() {
    assert_system_supported
    install_nix
    run_init "$@"
    step 'Done.'
}

main "$@"
