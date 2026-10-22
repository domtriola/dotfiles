#!/usr/bin/env bats
#
# doctor, through its command line, with the real agent-server checks.
#
# A check that reads the system finds the sandbox, not the box, so these tests
# look only at the lines that they are about.

load helpers

setup() {
  common_setup
  unset DOTFILES_PROFILE
  export DOTFILES_DIR="$repo_root"
  export PROMPT_TTY="$BATS_TEST_TMPDIR/no-terminal"
  export REBOOT_REQUIRED_FILE="$BATS_TEST_TMPDIR/reboot-required"
  doctor="$repo_root/commands/doctor/doctor"
}

@test "agent-server doctor reports a pending reboot when the marker exists" {
  echo "*** System restart required ***" >"$REBOOT_REQUIRED_FILE"
  run "$doctor" --profile agent-server --offline
  [[ "$output" == *"warn"*"reboot"*"required"* ]]
}

@test "agent-server doctor reports no reboot when the marker is missing" {
  run "$doctor" --profile agent-server --offline
  [[ "$output" =~ ok\ +reboot\ +not\ required ]]
}
