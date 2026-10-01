# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.
#
# Makes sure the current user has passwordless ed25519 and RSA SSH keys, generating missing ones.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1"
}

fail() {
    printf '\033[31mensure-ssh-key failed: %s\033[0m\n' "$1" >&2
    exit 1
}

ssh_dir="$HOME/.ssh"

# Usage: ensure_key <type> [extra ssh-keygen args...]
ensure_key() {
    local type="$1"
    shift
    local key="$ssh_dir/id_$type"

    if [ -e "$key" ]; then
        # Deriving the public key with an empty passphrase only succeeds if the key has none.
        if ! ssh-keygen -y -P '' -f "$key" >/dev/null 2>&1; then
            fail "$key exists but is password protected (or unreadable); remove its password or the key"
        fi
        step "SSH key $key already exists."
        return
    fi

    step "Generating SSH key $key..."
    ssh-keygen -q -t "$type" "$@" -N '' -C "$(id -un)@$(hostname -s)" -f "$key"
}

mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"

ensure_key ed25519
ensure_key rsa -b 4096
