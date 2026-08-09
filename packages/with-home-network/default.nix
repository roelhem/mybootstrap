{
  writeShellApplication,
  tailscale,
  curl,
}:

writeShellApplication {
  name = "with-home-network";
  runtimeInputs = [
    tailscale
    curl
  ];

  text = ''
    step() {
        printf '\033[36m==> %s\033[0m\n' "$1"
    }

    home_network_check_url='https://gitea.mmrh.nl'
    headscale_login_server='https://headscale.mmrh.nl'

    if [ "$#" -eq 0 ]; then
        printf 'usage: with-home-network <command> [args...]\n' >&2
        exit 1
    fi

    home_network_reachable() {
        curl --silent --fail --max-time 5 --output /dev/null "$home_network_check_url"
    }

    # Only torn down in cleanup if this script is the one that brought it up, so an
    # already-running, unrelated tailscale connection is left alone.
    tailscale_started=0
    cmd_exit_code=0

    # shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT`
    cleanup() {
        if [ "$tailscale_started" -eq 1 ]; then
            step 'Closing temporary tailscale connection...'
            tailscale down
        fi
    }
    trap cleanup EXIT

    if home_network_reachable; then
        step 'Home network already reachable.'
    else
        step "Home network unreachable, connecting via $headscale_login_server..."
        tailscale up --login-server="$headscale_login_server"
        tailscale_started=1
    fi

    # Run outside of `set -e` so a failing command doesn't skip the cleanup trap's
    # `tailscale down`, and so its exit code can be propagated below.
    set +e
    "$@"
    cmd_exit_code=$?
    set -e

    exit "$cmd_exit_code"
  '';
}
