# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH, and sets $identity_secret_file to the encrypted
# secrets/bootstrap-identity.age.
#
# Makes sure the bootstrap identity exists, decrypting it from $identity_secret_file with the
# local key files or a FIDO2 key if needed, and prints its path to stdout. The identity is kept
# in a directory that is cleared on reboot. All other output goes to stderr, so callers can
# capture stdout.

# shellcheck disable=SC2154 # identity_secret_file is set by runtimeEnv in ./default.nix.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1" >&2
}

warn() {
    printf '\033[33m%s\033[0m\n' "$1" >&2
}

fail() {
    printf '\033[31mensure-bootstrap-identity failed: %s\033[0m\n' "$1" >&2
    exit 1
}

# Linux keeps $XDG_RUNTIME_DIR on a tmpfs, and macOS clears /tmp on boot, so the identity never
# survives a reboot.
identity_dir="${XDG_RUNTIME_DIR:-/tmp}/mybootstrap-$(id -u)"
identity_file="$identity_dir/bootstrap-identity"

# Decrypts the given file to stdout with the local identity files that exist, or else with a
# FIDO2 key whose credential is embedded in the recipient (which asks for its PIN).
decrypt_with_personal_keys() {
    local file="$1"
    local identity_args=()
    for identity in "$HOME/.ssh/id_ed25519" "$HOME/.config/age/rskey-fido2_hmac_touch"; do
        if [ -f "$identity" ]; then
            identity_args+=(-i "$identity")
        fi
    done

    if [ "${#identity_args[@]}" -gt 0 ]; then
        step "Decrypting $(basename "$file") with local identity files..."
        if age -d "${identity_args[@]}" "$file"; then
            return 0
        fi
        warn 'Could not decrypt with local identity files.'
    fi

    step "Decrypting $(basename "$file") with a FIDO2 key (needs its PIN)..."
    if age -d -j fido2-hmac "$file"; then
        return 0
    fi
    warn 'Could not decrypt with a FIDO2 key.'
    return 1
}

# Makes sure $identity_file exists, decrypting it if needed. Writes to a temporary file first, so
# a failed decryption never leaves a partial identity behind.
ensure_identity() {
    if [ -s "$identity_file" ]; then
        step "Using bootstrap identity $identity_file."
        return 0
    fi

    if [ ! -d "$identity_dir" ]; then
        mkdir -m 700 "$identity_dir"
    fi
    # Refuse a directory someone else (pre)created, as it would expose the identity.
    if [ -L "$identity_dir" ] || [ ! -O "$identity_dir" ]; then
        fail "$identity_dir is not a directory owned by $(id -un)"
    fi
    chmod 700 "$identity_dir"

    local tmp_file
    tmp_file=$(umask 077 && mktemp "$identity_dir/bootstrap-identity.XXXXXX")
    if decrypt_with_personal_keys "$identity_secret_file" >"$tmp_file" && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$identity_file"
        return 0
    fi
    rm -f "$tmp_file"
    return 1
}

if ! ensure_identity; then
    fail 'could not decrypt the bootstrap identity'
fi
printf '%s\n' "$identity_file"
