{
  writeShellApplication,
  tailscale,
  curl,
  stdenv,
}:

let
  # macOS has no systemd unit to lean on, so tailscaled is spawned directly
  # and torn down again by PID. `--state=mem:` keeps it fully ephemeral since
  # this connection only exists for the lifetime of the wrapped command.
  startTailscaledCmd = ''
    tailscaled --state=mem: >/tmp/with-home-network-tailscaled.log 2>&1 &
    tailscaled_pid=$!
  '';
  stopTailscaledCmd = ''
    kill "$tailscaled_pid" 2>/dev/null || true
    wait "$tailscaled_pid" 2>/dev/null || true
  '';
in
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

    fail() {
        printf '\033[31mwith-home-network failed: %s\033[0m\n' "$1" >&2
        exit 1
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

    # `tailscale status` fails to even connect to tailscaled's local socket
    # (distinct from just reporting a logged-out state) when the daemon
    # itself isn't running yet.
    tailscaled_reachable() {
        local output
        if output=$(tailscale status 2>&1); then
            return 0
        fi
        ! printf '%s\n' "$output" | grep -q 'failed to connect'
    }

    start_tailscaled() {
        step 'Starting tailscaled...'
        ${
          if stdenv.isDarwin then startTailscaledCmd else "systemctl start tailscaled"
        }
        tailscaled_started=1

        local i=0
        while [ "$i" -lt 20 ]; do
            if tailscaled_reachable; then
                return 0
            fi
            sleep 0.5
            i=$((i + 1))
        done

        fail 'timed out waiting for tailscaled to start'
    }

    # Only torn down in cleanup if this script is the one that brought it up, so an
    # already-running, unrelated tailscale connection/daemon is left alone.
    tailscale_started=0
    tailscaled_started=0
    cmd_exit_code=0

    # shellcheck disable=SC2329 # invoked indirectly via `trap ... EXIT`
    cleanup() {
        if [ "$tailscale_started" -eq 1 ]; then
            step 'Closing temporary tailscale connection...'
            tailscale down
        fi
        if [ "$tailscaled_started" -eq 1 ]; then
            step 'Stopping temporary tailscaled...'
            ${if stdenv.isDarwin then stopTailscaledCmd else "systemctl stop tailscaled"}
        fi
    }
    trap cleanup EXIT

    if home_network_reachable; then
        step 'Home network already reachable.'
    else
        if ! tailscaled_reachable; then
            start_tailscaled
        fi

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
