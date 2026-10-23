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

# given_kamaji sets this machine up as if kamaji were cloned and linked, the
# App were installed on both owners, and the refresh job had run once.
given_kamaji() {
  mkdir -p "$HOME/src/personal/kamaji"
  fake_command kamaji 'exit 0'
  fake_command sbx-token 'echo "sbx-token: me-sbx, installed on Fernata-Studio, domtriola"'
  fake_command launchctl 'echo "state = not running"; echo "last exit code = 0"'
}

@test "dev-mac doctor reports kamaji as pending, and checks nothing else, when it is not cloned" {
  given_kamaji
  rm -r "$HOME/src/personal/kamaji"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ pending\ +kamaji\ +not\ cloned ]]
  [[ "$output" != *"kamaji command"* ]]
  [[ "$output" != *"kamaji refresh job"* ]]
}

@test "dev-mac doctor reports each kamaji check as ok when all is set up" {
  given_kamaji
  run "$doctor" --profile dev-mac
  [[ "$output" =~ ok\ +kamaji\ +~/src/personal/kamaji ]]
  [[ "$output" =~ ok\ +kamaji\ command ]]
  [[ "$output" =~ ok\ +kamaji\ owners\ +domtriola,\ Fernata-Studio ]]
  [[ "$output" =~ ok\ +kamaji\ refresh\ job ]]
}

@test "dev-mac doctor reports the kamaji command as pending when it is not linked" {
  given_kamaji
  rm "$BATS_TEST_TMPDIR/bin/kamaji"
  run "$doctor" --profile dev-mac
  [[ "$output" =~ pending\ +kamaji\ command\ +not\ installed,\ run\ pnpm\ link\ --global ]]
}

@test "dev-mac doctor warns when the App is not installed on a kamaji owner" {
  given_kamaji
  fake_command sbx-token 'echo "sbx-token: me-sbx, installed on domtriola (only selected repositories on domtriola)"'
  run "$doctor" --profile dev-mac
  [[ "$output" =~ warn\ +kamaji\ owners\ +the\ App\ is\ not\ installed\ on\ Fernata-Studio ]]
}

@test "dev-mac doctor does not check the kamaji owners offline" {
  given_kamaji
  fake_command sbx-token 'echo "sbx-token: me-sbx, key stored (not checked with GitHub)"'
  run "$doctor" --profile dev-mac --offline
  [[ "$output" != *"kamaji owners"* ]]
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
