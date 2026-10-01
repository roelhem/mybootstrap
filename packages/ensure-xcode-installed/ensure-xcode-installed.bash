# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1"
}

fail() {
    printf '\033[31mensure-xcode-installed failed: %s\033[0m\n' "$1" >&2
    exit 1
}

# Only macOS ships Xcode; nothing to do on other platforms.
is_macos() {
    [ "$(uname -s)" = 'Darwin' ]
}

# Emacs (native-comp, package builds, git, etc) only needs the Command Line Tools, not the
# full Xcode.app - so that's all we check for/install, to avoid an interactive App Store
# sign-in. Check the CLT's own git binary directly rather than `xcode-select -p`, since the
# latter keeps pointing at a valid-looking path even after a stale/incomplete CLT install.
already_installed() {
    [ -e '/Library/Developer/CommandLineTools/usr/bin/git' ]
}

install_command_line_tools() {
    step 'Installing Xcode Command Line Tools...'

    # This placeholder file is what makes `softwareupdate -l` list the Command Line Tools
    # package as installable, instead of only offering it via the interactive
    # `xcode-select --install` GUI popup.
    clt_placeholder='/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress'
    touch "$clt_placeholder"

    # shellcheck disable=SC2312
    clt_label=$(
        softwareupdate -l 2>/dev/null |
            grep -B 1 -E 'Command Line Tools' |
            awk -F'*' '/^ *\*/ {print $2}' |
            sed -e 's/^ *Label: //' -e 's/^ *//' |
            sort -V |
            tail -n1
    ) || true

    if [ -z "$clt_label" ]; then
        rm -f "$clt_placeholder"
        fail 'no Command Line Tools package found via softwareupdate'
    fi

    softwareupdate -i "$clt_label"
    xcode-select --switch /Library/Developer/CommandLineTools
    rm -f "$clt_placeholder"
}

main() {
    if ! is_macos; then
        step 'Not on macOS, skipping Xcode Command Line Tools installation.'
        exit 0
    fi

    if already_installed; then
        step 'Xcode Command Line Tools are already installed.'
        exit 0
    fi

    install_command_line_tools
    step 'Xcode Command Line Tools installed.'
}

main "$@"
