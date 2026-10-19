#!/usr/bin/env bats
#
# env/.tmux.conf, loaded into a real tmux server. The server has a private
# socket in the test's own directory, so it can never reach the operator's
# tmux. A test that presses keys attaches a client under script(1), which
# gives it a terminal.

load helpers

setup() {
  # The real tmux, found before common_setup puts the fake one first on PATH.
  real_tmux="$(command -v tmux)" || skip "tmux is not installed"
  # A full path, because some tests give the server a PATH without tail.
  idle="$(command -v tail) -f /dev/null"
  common_setup
  unset TMUX
  export TMUX_TMPDIR="$BATS_TEST_TMPDIR/tmux"
  mkdir -p "$TMUX_TMPDIR"
  conf="$repo_root/env/.tmux.conf"
  client_pid=""
}

teardown() {
  t kill-server 2>/dev/null || true
  [[ -n "$client_pid" ]] && wait "$client_pid" 2>/dev/null || true
}

t() { "$real_tmux" -L conf "$@"; }

# start_server starts the server with env/.tmux.conf. Arguments go to env(1),
# as extra environment for the server. The pane runs a command that ignores
# its input, so that the end of the client's input (a Ctrl-D) cannot end the
# session. The server must not hold bats' file descriptor 3, or bats waits for
# it.
start_server() {
  env "$@" "$real_tmux" -L conf -f "$conf" \
    new-session -d -s main -x 120 -y 30 "$idle" 3>&-
}

# attach_client attaches a client under script(1), and waits for it.
attach_client() {
  command -v script >/dev/null 2>&1 || skip "script(1) is not installed"
  script -qec "$real_tmux -L conf attach -t main" /dev/null >/dev/null 2>&1 3>&- &
  client_pid=$!
  for _ in $(seq 50); do
    client="$(t list-clients -F '#{client_name}' 2>/dev/null | head -1)"
    [[ -n "$client" ]] && return 0
    sleep 0.1
  done
  echo "no client attached" >&2
  return 1
}

# press sends one key to the client, as if it were typed.
press() {
  t send-keys -K -c "$client" "$1"
  sleep 0.2
}

key_table() { t display-message -p -c "$client" '#{client_key_table}'; }

@test "the prefix is C-a, and C-a C-a sends the prefix" {
  start_server
  [ "$(t show -gv prefix)" = "C-a" ]
  run t list-keys -T prefix C-a
  [[ "$output" == *"send-prefix"* ]]
}

@test "copies go to the terminal's clipboard through OSC 52" {
  start_server
  [ "$(t show -sv set-clipboard)" = "on" ]
}

@test "with no clipboard command installed, y in copy mode still copies" {
  # Only the tools that the config could look for, and none of them.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  start_server PATH="$BATS_TEST_TMPDIR/bin"
  [ -z "$(t show -sv copy-command)" ]
  run t list-keys -T copy-mode-vi y
  [[ "$output" == *"copy-pipe-and-cancel"* ]]
}

@test "with wl-copy installed, y in copy mode pipes to it" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\ncat >/dev/null\n' >"$BATS_TEST_TMPDIR/bin/wl-copy"
  chmod +x "$BATS_TEST_TMPDIR/bin/wl-copy"
  start_server PATH="$BATS_TEST_TMPDIR/bin"
  [ "$(t show -sv copy-command)" = "wl-copy" ]
}

@test "F12 turns the prefix off and shows OFF, and F12 again turns it back on" {
  start_server
  attach_client

  press F12
  [ "$(key_table)" = "off" ]
  [ "$(t show -v prefix)" = "None" ]
  [[ "$(t display-message -p -c "$client" '#{T:status-right}')" == *"OFF"* ]]

  # C-a in the off table does nothing here, so the next F12 still toggles.
  press C-a
  [ "$(key_table)" = "off" ]

  press F12
  [ "$(key_table)" = "root" ]
  [ "$(t show -gv prefix)" = "C-a" ]
  run t show -v prefix
  [ -z "$output" ]
  [[ "$(t display-message -p -c "$client" '#{T:status-right}')" != *"OFF"* ]]
}

@test "over SSH, the status bar shows the hostname" {
  start_server SSH_CONNECTION="192.0.2.1 50000 192.0.2.2 22"
  host="$(t display-message -p '#h')"
  [[ "$(t display-message -p '#{T:status-left}')" == *"$host"* ]]
}

@test "without SSH, the status bar shows the session but not the hostname" {
  start_server -u SSH_CONNECTION
  host="$(t display-message -p '#h')"
  left="$(t display-message -p '#{T:status-left}')"
  [[ "$left" == *"main"* ]]
  [[ "$left" != *"$host"* ]]
}
