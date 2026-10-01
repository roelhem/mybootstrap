# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH, and sets $nix_config_secret_file to the encrypted
# secrets/bootstrap-nix-config.age.
#
# Prints nix configuration lines with secrets (a read-only `access-tokens = github.com=...`) to
# stdout, by decrypting $nix_config_secret_file with the bootstrap identity from
# ensure-bootstrap-identity. If that fails, offers to log in with the gh cli instead. All other
# output goes to stderr, so callers can capture stdout.

# shellcheck disable=SC2154 # nix_config_secret_file is set by runtimeEnv in ./default.nix.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1" >&2
}

warn() {
    printf '\033[33m%s\033[0m\n' "$1" >&2
}

fail() {
    printf '\033[31mget-nix-config-secrets failed: %s\033[0m\n' "$1" >&2
    exit 1
}

if identity_file=$(ensure-bootstrap-identity); then
    step 'Decrypting nix config secrets with the bootstrap identity...'
    if age -d -i "$identity_file" "$nix_config_secret_file"; then
        exit 0
    fi
    warn 'Could not decrypt the nix config secrets with the bootstrap identity.'
else
    warn 'Could not get the bootstrap identity.'
fi

# Fall back to the token of a (possibly interactive) gh login, but only if asked to.
if ! gum confirm 'Log in with the gh cli instead?' >&2; then
    fail 'no nix config secrets available'
fi
# gh writes its prompts to stdout, so send those to stderr to keep them visible and out of the
# captured output.
if gh auth status --hostname github.com >/dev/null 2>&1; then
    step 'Already logged in to GitHub.'
else
    step 'Logging in to GitHub...'
    gh auth login --hostname github.com --git-protocol https >&2
fi
github_token=$(gh auth token --hostname github.com)
printf 'access-tokens = github.com=%s\n' "$github_token"
