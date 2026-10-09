#!/usr/bin/env bats
#
# The shared output style. A test that needs a terminal runs the library under
# script(1), which gives it one.

load helpers

setup() {
  common_setup
  style="$repo_root/lib/style.sh"
}

# on_terminal runs a bash command with stdout on a pseudo-terminal, and prints
# what it wrote. script(1) takes its arguments differently on macOS.
on_terminal() {
  command -v script >/dev/null 2>&1 || skip "script(1) is not installed"
  if [[ "$OSTYPE" == darwin* ]]; then
    script -q /dev/null bash -c "$1"
  else
    script -qec "bash -c '$1'" /dev/null
  fi
}

@test "on a terminal, a status word is in its color" {
  run on_terminal "source $style; status ok label"
  [[ "$output" == *$'\033[32mok'* ]]
}

@test "with NO_COLOR, a terminal gets no escape codes" {
  run on_terminal "NO_COLOR=1; source $style; status FAIL label; section name; verdict FAIL done"
  [[ "$output" == *"FAIL"* ]]
  [[ "$output" != *$'\033'* ]]
}

@test "in a pipe, there are no escape codes" {
  run bash -c "source $style; status FAIL label; section name; verdict FAIL done"
  [[ "$output" != *$'\033'* ]]
}

@test "a status line has the word in a fixed column, then the label and the detail" {
  run bash -c "source $style; status ok short detail; status 'not run' a-longer-label"
  [ "${lines[0]}" = "  ok      short                              detail" ]
  [ "${lines[1]}" = "  not run a-longer-label" ]
}

@test "an unknown status word is an error" {
  run bash -c "source $style; style_color great"
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown status word "great"'* ]]
}
