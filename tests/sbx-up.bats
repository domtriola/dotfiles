#!/usr/bin/env bats
#
# sbx-up's GitHub token, through its command line.

load helpers

setup_file() { make_key; }
setup() {
  make_key
  common_setup
  unset TMUX

  # sbx-up finds sbx-token on PATH, as it would the installed copy.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  ln -s "$sbx_token" "$BATS_TEST_TMPDIR/bin/sbx-token"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  # A dotfiles checkout with only the kits that sbx-up checks for.
  export SBX_UP_DOTFILES="$BATS_TEST_TMPDIR/dotfiles"
  mkdir -p "$SBX_UP_DOTFILES/sbx/kits/sandboxes/my-claude"

  project="$BATS_TEST_TMPDIR/app"
  git init -q -b main "$project"
  git -C "$project" remote add origin git@github.com:me/app.git
  cd "$project"
}

sbx_up() { "$repo_root/commands/sbx-up/sbx-up" "$@"; }

@test "the sandbox gets a token for the origin repository, stored after the old sandbox is removed" {
  given_app
  run sbx_up
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/secrets/app-main")" = "'$sbx_token' mint --repo me/app" ]
  [ "$(cut -d' ' -f1-2 "$FAKE_STATE/sbx.log" | tr '\n' ,)" = "rm --force,secret set,run $SBX_UP_DOTFILES/sbx/kits/sandboxes/my-claude," ]
}

@test "the repos and permissions in .sbx.json reach the token" {
  given_app
  echo '{"repos": ["me/app", "me/lib"], "permissions": {"workflows": "write", "issues": "none"}}' >.sbx.json
  run sbx_up
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/secrets/app-main")" = "'$sbx_token' mint --repo me/app --repo me/lib --perm workflows=write --perm issues=none" ]
  [ "$(token_request | jq -c .repositories)" = '["app","lib"]' ]
}

@test "an https origin works too" {
  given_app
  git remote set-url origin https://github.com/me/app
  run sbx_up
  [ "$status" -eq 0 ]
  [[ "$(cat "$FAKE_STATE/secrets/app-main")" == *"--repo me/app" ]]
}

@test "a failed mint stops before the old sandbox is removed" {
  given_app
  FAKE_GH_OWNERS=nobody run sbx_up
  [ "$status" -eq 1 ]
  [[ "$output" == *"https://github.com/apps/me-sbx/installations/new"* ]]
  [[ "$output" == *"--no-gh"* ]]
  [ ! -s "$FAKE_STATE/sbx.log" ]
}

@test "a machine without an App stops, and never falls back to the gh token" {
  run sbx_up
  [ "$status" -eq 1 ]
  [[ "$output" == *"sbx-token import-key"* ]]
  [ ! -s "$FAKE_STATE/sbx.log" ]
  [ ! -e "$FAKE_STATE/gh.log" ]
}

@test "an origin that is not on GitHub stops with what to do" {
  given_app
  git remote set-url origin https://gitlab.com/me/app.git
  run sbx_up
  [ "$status" -eq 1 ]
  [[ "$output" == *'Set "repos" in .sbx.json, or pass --no-gh'* ]]
}

@test "a malformed permissions setting is reported" {
  given_app
  echo '{"permissions": ["workflows"]}' >.sbx.json
  run sbx_up
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read"* ]]
}

@test "--no-gh starts the sandbox without a token, and needs no App" {
  run sbx_up --no-gh
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_STATE/secrets/app-main" ]
  [ ! -s "$FAKE_STATE/curl.log" ]
  grep -q '^run ' "$FAKE_STATE/sbx.log"
}

@test "in tmux, a clone sandbox gets only the agent window" {
  given_app
  echo '{"clone": true}' >.sbx.json
  : >"$FAKE_STATE/tmux.log"
  TMUX=fake run sbx_up
  [ "$status" -eq 0 ]
  [ "$(grep -c '^new-window$' "$FAKE_STATE/tmux.log")" -eq 1 ]
  grep -qx 'sbx-main' "$FAKE_STATE/tmux.log"
  ! grep -q 'shell' "$FAKE_STATE/tmux.log"
}
