# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.
#
# Usage: choose-darwin-configuration <flakeref>
#
# Lists the darwinConfigurations of <flakeref>, lets the user pick one interactively and prints
# the chosen name to stdout (all prompting happens on the terminal, so it can be captured).

step() {
    printf '\033[36m==> %s\033[0m\n' "$1" >&2
}

fail() {
    printf '\033[31mchoose-darwin-configuration failed: %s\033[0m\n' "$1" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    printf 'usage: choose-darwin-configuration <flakeref>\n' >&2
    exit 1
fi
flake="$1"

step "Looking up darwin configurations in $flake..."
configurations=()
while IFS= read -r name; do
    configurations+=("$name")
done < <(
    nix eval --refresh --json "$flake#darwinConfigurations" --apply builtins.attrNames |
        jq -r '.[]'
)

if [ "${#configurations[@]}" -eq 0 ]; then
    fail "$flake has no darwinConfigurations"
fi

# Start on the configuration named after this machine, when there is one.
hostname=$(scutil --get LocalHostName 2>/dev/null || true)

# Read the choice from the terminal rather than stdin, which is the script itself when
# bootstrapping via `curl ... | sh`.
chosen=$(
    gum choose \
        --header 'Choose the darwin configuration to activate:' \
        --select-if-one \
        --selected "$hostname" \
        "${configurations[@]}" </dev/tty
) || fail 'no configuration chosen'

if [ -z "$chosen" ]; then
    fail 'no configuration chosen'
fi
printf '%s\n' "$chosen"
