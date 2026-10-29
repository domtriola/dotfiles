#!/usr/bin/env bats
#
# setup, through its command line, against a fake checkout whose profile has
# three setup steps.

load helpers

setup() {
  common_setup
  setup_cmd="$repo_root/commands/setup/setup"

  checkout="$BATS_TEST_TMPDIR/checkout"
  export DOTFILES_DIR="$checkout"
  if [[ "$OSTYPE" == darwin* ]]; then
    export DOTFILES_PROFILE="dev-mac"
  else
    export DOTFILES_PROFILE="dev-linux"
  fi

  steps="$checkout/profiles/$DOTFILES_PROFILE"
  mkdir -p "$steps/lib"
  ln -s "$repo_root/lib" "$checkout/lib"

  given_step 10_first 'echo "first step output"'
  given_step 20_second 'echo "second step output"'
  given_step 30_third 'echo "third step output"'

  # Not a setup step: not executable, or under lib/.
  echo 'echo "never"' >"$steps/40_not_executable"
  given_step lib/doctor.sh 'echo "never"'
}

# given_step writes an executable setup step with <body> as its script.
given_step() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$steps/$1"
  chmod +x "$steps/$1"
}

@test "every step runs in order, with its output, a result and a summary" {
  run "$setup_cmd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"first step output"*"ran     10_first"*"second step output"*"third step output"* ]]
  [[ "$output" != *"never"* ]]
  [ "$(grep -c "^  ran     10_first" <<<"$output")" -eq 2 ]
  [[ "$(tail -5 <<<"$output")" == *"ran     10_first"*"ran     20_second"*"ran     30_third"* ]]
  [ "$(tail -1 <<<"$output")" = "setup: 3 ran" ]
}

@test "a failing step stops the run, and the later steps are not run" {
  given_step 20_second 'echo "second step output"; exit 3'

  run "$setup_cmd"
  [ "$status" -eq 3 ]
  [[ "$output" != *"third step output"* ]]
  [[ "$output" == *"FAIL    20_second"* ]]
  [[ "$output" == *"not run 30_third"* ]]
  [ "$(tail -1 <<<"$output")" = "setup: 1 ran, 1 FAIL, 1 not run" ]
}

@test "a step that does not match the pattern is skipped" {
  run "$setup_cmd" second
  [ "$status" -eq 0 ]
  [[ "$output" != *"first step output"* ]]
  [[ "$output" == *"second step output"* ]]
  [[ "$output" == *"skipped 10_first"*"does not match 'second'"* ]]
  [ "$(tail -1 <<<"$output")" = "setup: 1 ran, 2 skipped" ]
}

@test "--dry lists the steps and runs none" {
  run "$setup_cmd" --dry
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run: nothing changes"* ]]
  [[ "$output" != *"step output"* ]]
  [[ "$output" == *"info    10_first"*"would run"* ]]
  [ "$(tail -1 <<<"$output")" = "setup: 3 to run" ]
}

@test "with no profile on Ubuntu, setup detects none and asks for --profile" {
  unset DOTFILES_PROFILE
  # A checkout whose platform library says Ubuntu, outside a sandbox.
  rm "$checkout/lib"
  mkdir "$checkout/lib"
  ln -s "$repo_root/lib/profile.sh" "$repo_root/lib/style.sh" "$checkout/lib/"
  cat >"$checkout/lib/platform.sh" <<PLATFORM
source "$repo_root/lib/platform.sh"
is_mac() { false; }
is_linux() { true; }
is_sandbox() { false; }
is_qubes() { false; }
is_fedora() { false; }
is_ubuntu() { true; }
PLATFORM

  run "$setup_cmd" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot detect a profile"*"ai-server or agent-server"*"Pass --profile"* ]]
  [[ "$output" == *"agent-server"* ]]
  [ ! -e "$XDG_CONFIG_HOME/dotfiles/profile" ]
}

@test "setup --profile agent-server --dry lists the profile's steps in order, and runs none" {
  unset DOTFILES_PROFILE
  DOTFILES_DIR="$repo_root" run "$setup_cmd" --profile agent-server --dry
  [ "$status" -eq 0 ]
  [[ "$output" == *"info    05_hardening"*"info    10_packages"*"info    12_storage"*"info    15_pnpm"*"info    22_sandboxes"*"info    25_network"*"info    30_git"* ]]
  [ "$(tail -1 <<<"$output")" = "setup: 7 to run" ]
  [ ! -e "$XDG_CONFIG_HOME/dotfiles/profile" ]
}
