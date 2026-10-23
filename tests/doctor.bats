#!/usr/bin/env bats
#
# doctor, through its command line, with the real agent-server and dev-mac
# checks.
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

@test "agent-server doctor warns when the git identity is not set" {
  run "$doctor" --profile agent-server --offline
  [[ "$output" =~ warn\ +git\ user\.name\ +not\ set ]]
  [[ "$output" =~ warn\ +git\ user\.email\ +not\ set ]]
}

@test "agent-server doctor reports the git identity when it is set" {
  git config --global user.name "Ann Example"
  git config --global user.email "ann@example.com"
  run "$doctor" --profile agent-server --offline
  [[ "$output" =~ ok\ +git\ user\.name\ +Ann\ Example ]]
  [[ "$output" =~ ok\ +git\ user\.email\ +ann@example\.com ]]
}

# fake_command writes a command into a directory that comes first on PATH.
fake_command() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$BATS_TEST_TMPDIR/bin/$1"
  chmod +x "$BATS_TEST_TMPDIR/bin/$1"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# given_kamaji sets this machine up as if kamaji-update had made the runtime
# clone, the development checkout were cloned, sync-env had installed the
# wrapper, the App were installed on both owners, and the refresh job had run
# once.
given_kamaji() {
  runtime="$HOME/.local/share/kamaji"
  git init --quiet "$runtime"
  git -C "$runtime" -c user.name=t -c user.email=t@example.com commit --quiet --allow-empty -m "Add the CLI"
  mkdir -p "$HOME/src/personal/kamaji" "$HOME/.local/bin"
  printf '#!/bin/sh\n' >"$HOME/.local/bin/kamaji"
  chmod +x "$HOME/.local/bin/kamaji"
  export PATH="$HOME/.local/bin:$PATH"
  fake_command sbx-token 'echo "sbx-token: me-sbx, installed on Fernata-Studio, domtriola"'
  fake_command launchctl 'echo "state = not running"; echo "last exit code = 0"'
}

@test "dev-mac doctor reports kamaji as pending, and checks nothing else, when it is not installed" {
  given_kamaji
  rm -rf "$runtime"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ pending\ +kamaji\ +not\ installed,\ see\ bootstrap.md ]]
  [[ "$output" != *"kamaji command"* ]]
  [[ "$output" != *"kamaji refresh job"* ]]
}

@test "dev-mac doctor reports each kamaji check as ok when all is set up" {
  given_kamaji
  run "$doctor" --profile dev-mac
  [[ "$output" =~ ok\ +kamaji\ runtime\ +[0-9a-f]+\ [0-9-]+,\ update\ with\ kamaji-update ]]
  [[ "$output" =~ ok\ +kamaji\ checkout\ +~/src/personal/kamaji ]]
  [[ "$output" =~ ok\ +kamaji\ command\ +runs\ the\ runtime\ clone ]]
  [[ "$output" =~ ok\ +kamaji\ owners\ +domtriola,\ Fernata-Studio ]]
  [[ "$output" =~ ok\ +kamaji\ refresh\ job ]]
}

@test "dev-mac doctor warns when the runtime clone has local changes, because the host runs them" {
  given_kamaji
  echo "edited" >"$runtime/cli.js"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ runtime\ +has\ local\ changes ]]
}

@test "dev-mac doctor warns when the development checkout is missing, because the sandbox gets no snapshot" {
  given_kamaji
  rm -r "$HOME/src/personal/kamaji"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ checkout\ +not\ cloned ]]
}

@test "dev-mac doctor fails when the kamaji sandbox would mount the development checkout read and write" {
  given_kamaji
  echo '{"clone": false}' >"$HOME/src/personal/kamaji/.sbx.json"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ FAIL\ +kamaji\ checkout\ +[^$'\n']*clone ]]
}

@test "dev-mac doctor fails when another kamaji comes first on PATH, such as a linked development checkout" {
  given_kamaji
  fake_command kamaji 'exit 0'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ FAIL\ +kamaji\ command\ +[^$'\n']*/bin/kamaji\ comes\ first\ on\ PATH ]]
}

@test "dev-mac doctor fails when the kamaji wrapper is not installed" {
  given_kamaji
  rm "$HOME/.local/bin/kamaji"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ FAIL\ +kamaji\ command\ +not\ installed,\ run\ sync-env ]]
}

@test "dev-mac doctor warns when the App is not installed on a kamaji owner" {
  given_kamaji
  fake_command sbx-token 'echo "sbx-token: me-sbx, installed on domtriola (only selected repositories on domtriola)"'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ owners\ +the\ App\ is\ not\ installed\ on\ Fernata-Studio,\ install\ it\ there,\ then\ run\ sbx-token\ expect ]]
}

@test "dev-mac doctor reports the kamaji owners as pending offline" {
  given_kamaji
  fake_command sbx-token 'echo "sbx-token: me-sbx, key stored (not checked with GitHub)"'
  run "$doctor" --profile dev-mac --offline
  [[ "$output" =~ pending\ +kamaji\ owners\ +needs\ an\ online\ sbx-token\ check ]]
}

@test "dev-mac doctor warns, with the command that loads it, when the refresh job is not loaded" {
  given_kamaji
  fake_command launchctl 'echo "Could not find service" >&2; exit 113'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ refresh\ job\ +not\ loaded,\ run\ launchctl\ bootstrap\ gui/ ]]
}

@test "dev-mac doctor warns, and names the log, when the last refresh failed" {
  given_kamaji
  fake_command launchctl 'echo "last exit code = 1"'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ refresh\ job\ +last\ refresh\ exited\ 1,\ see\ ~/Library/Logs/kamaji-refresh.log ]]
}

@test "dev-mac doctor reports the refresh job as ok before its first run" {
  given_kamaji
  fake_command launchctl 'echo "last exit code = (never exited)"'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ ok\ +kamaji\ refresh\ job ]]
}
