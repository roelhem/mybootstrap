# shellcheck shell=bash
# Wrapped by writeShellApplication in ./default.nix, which adds the shebang, strict mode and
# runtimeInputs on PATH.

step() {
    printf '\033[36m==> %s\033[0m\n' "$1"
}

fail() {
    printf '\033[31mclone-config-repos failed: %s\033[0m\n' "$1" >&2
    exit 1
}

gitea_url='https://gitea.mmrh.nl'
workspace_dir="$HOME/workspace/roelhem"
repos='myconf'

# Fail up front with a clear message, instead of an opaque git error for every repo.
assert_gitea_reachable() {
    if ! curl --silent --fail --max-time 5 --output /dev/null "$gitea_url"; then
        fail "cannot reach $gitea_url (is the home network connected?)"
    fi
}

# Fast-forward the local `main` branch to `origin/main`. Only fast-forwards, so local commits
# or a diverged history make this fail loudly instead of creating a merge.
update_repo() {
    local name="$1" dir="$2"
    step "Updating $name..."

    if [ "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" = main ]; then
        git -C "$dir" pull --ff-only origin main
    else
        # Not checked out, so the ref can be fast-forwarded directly without touching the
        # working tree of whatever branch is checked out.
        git -C "$dir" fetch origin main:main
    fi
}

clone_repo() {
    local name="$1" dir="$2"
    step "Cloning $name..."
    git clone "$gitea_url/roelhem/$name.git" "$dir"
}

sync_repo() {
    local name="$1"
    local dir="$workspace_dir/$name"

    if [ -d "$dir/.git" ]; then
        update_repo "$name" "$dir"
    elif [ -e "$dir" ]; then
        fail "$dir exists but is not a git repository"
    else
        clone_repo "$name" "$dir"
    fi
}

main() {
    assert_gitea_reachable
    mkdir -p "$workspace_dir"

    for name in $repos; do
        sync_repo "$name"
    done

    step 'Config repos are up to date.'
}

main "$@"
