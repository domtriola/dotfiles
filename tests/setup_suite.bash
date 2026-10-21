# bats runs setup_suite once, before any test file in this directory. It stops
# the whole run outside a Docker Sandbox. A command that has no fake is the
# real one. Thus a missing fake must never run on the operator's machine.

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/../lib/platform.sh"

setup_suite() {
  if ! is_sandbox; then
    echo "tests: the tests run only in a Docker Sandbox. Start one with sbx-up, and run ./test there." >&2
    return 1
  fi
}
