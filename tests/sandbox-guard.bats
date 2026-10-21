#!/usr/bin/env bats
#
# The guard in setup_suite.bash, which stops every suite outside a Docker
# Sandbox. A missing or wrong fake then runs a real command only inside a
# sandbox, never on the operator's machine.

load helpers

# guard runs setup_suite in a new shell, with is_sandbox answering <answer>.
guard() {
  bash -c '
    answer="$2"
    source "$1/tests/setup_suite.bash"
    is_sandbox() { [[ "$answer" == "yes" ]]; }
    setup_suite
  ' guard "$repo_root" "$1"
}

@test "outside a sandbox, the suites stop with a reason" {
  run guard no
  [ "$status" -ne 0 ]
  [[ "$output" == *"only in a Docker Sandbox"* ]]
}

@test "inside a sandbox, the suites run" {
  run guard yes
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a real bats run outside a sandbox runs no test" {
  suite="$BATS_TEST_TMPDIR/suite"
  mkdir -p "$suite"
  # The real guard, with a sandbox check that says no.
  printf 'source "%s/tests/setup_suite.bash"\nis_sandbox() { false; }\n' "$repo_root" \
    >"$suite/setup_suite.bash"
  printf '@test "x" { touch "%s/ran"; }\n' "$BATS_TEST_TMPDIR" >"$suite/x.bats"

  run bats "$suite"
  [ "$status" -ne 0 ]
  [[ "$output" == *"only in a Docker Sandbox"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/ran" ]
}

@test "./test outside a sandbox stops before bats, with only the reason" {
  # A copy of ./test, beside a platform library whose sandbox check says no.
  checkout="$BATS_TEST_TMPDIR/checkout"
  mkdir -p "$checkout/lib"
  cp "$repo_root/test" "$checkout/test"
  printf 'is_sandbox() { false; }\n' >"$checkout/lib/platform.sh"

  run "$checkout/test"
  [ "$status" -eq 1 ]
  [ "$output" = "test: the tests run only in a Docker Sandbox. Start one with sbx-up, and run ./test there." ]
}
