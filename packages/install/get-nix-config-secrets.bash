# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH, and sets $secrets_file to the encrypted secrets/bootstrap-nix-config.age.
#
# Prints nix configuration lines with secrets (a read-only `access-tokens = github.com=...`) to
# stdout. Tries, in order: decrypting $secrets_file with the local key files, decrypting it with
# a FIDO2 key (needs its PIN), and finally logging in with the gh cli. All other output goes to
# stderr, so callers can capture stdout.

# shellcheck disable=SC2154 # secrets_file is set by runtimeEnv in ./default.nix.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1" >&2
}

warn() {
    printf '\033[33m%s\033[0m\n' "$1" >&2
}

# 1. Local identity files, using only those that exist.
identity_args=()
for identity in "$HOME/.ssh/id_ed25519" "$HOME/.config/age/rskey-fido2_hmac_touch"; do
    if [ -f "$identity" ]; then
        identity_args+=(-i "$identity")
    fi
done

if [ "${#identity_args[@]}" -gt 0 ]; then
    step 'Decrypting nix config secrets with local identity files...'
    if age -d "${identity_args[@]}" "$secrets_file"; then
        exit 0
    fi
    warn 'Could not decrypt with local identity files.'
fi

# 2. A FIDO2 key whose credential is embedded in the recipient, which asks for its PIN.
step 'Decrypting nix config secrets with a FIDO2 key (needs its PIN)...'
if age -d -j fido2-hmac "$secrets_file"; then
    exit 0
fi
warn 'Could not decrypt with a FIDO2 key.'

# 3. Fall back to the token of a (possibly interactive) gh login. gh writes its prompts to
# stdout, so send those to stderr to keep them visible and out of the captured output.
if gh auth status --hostname github.com >/dev/null 2>&1; then
    step 'Already logged in to GitHub.'
else
    step 'Logging in to GitHub...'
    gh auth login --hostname github.com --git-protocol https >&2
fi
github_token=$(gh auth token --hostname github.com)
printf 'access-tokens = github.com=%s\n' "$github_token"
