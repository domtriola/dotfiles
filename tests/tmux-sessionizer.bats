#!/usr/bin/env bats
#
# tmux-sessionizer, through its command line, with the fake tmux.

load helpers

setup() {
  common_setup
  sessionizer="$repo_root/env/.local/bin/tmux-sessionizer"
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project" "$BATS_TEST_TMPDIR/bin"
  unset TMUX
}

# sent_keys prints the keys that tmux send-keys got, one call on each line.
sent_keys() {
  awk 'BEGIN { RS = ""; FS = "\n" } $1 == "send-keys" { print $4 }' "$FAKE_STATE/tmux.log"
}

@test "a new session runs ready-tmux when the command is installed" {
  printf '#!/bin/sh\n' >"$BATS_TEST_TMPDIR/bin/ready-tmux"
  chmod +x "$BATS_TEST_TMPDIR/bin/ready-tmux"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$sessionizer" "$project"
  [ "$status" -eq 0 ]
  grep -qx "new-session" "$FAKE_STATE/tmux.log"
  [ "$(sent_keys)" = "ready-tmux" ]
}

@test "a new session is a plain shell when ready-tmux is not installed" {
  PATH="$repo_root/tests/fakes/bin:/usr/bin:/bin" run "$sessionizer" "$project"
  [ "$status" -eq 0 ]
  grep -qx "new-session" "$FAKE_STATE/tmux.log"
  [ -z "$(sent_keys)" ]
}
