#!/usr/bin/env bats
#
# sbx-token, through its command line.

load helpers

setup_file() { make_key; }
setup() {
  make_key
  common_setup
}

@test "mint asks for a token limited to the repository and the default permissions" {
  given_app
  run "$sbx_token" mint --repo me/app
  [ "$status" -eq 0 ]
  [ "$output" = "ghs_fake" ]
  [ "$(token_request | jq -c .repositories)" = '["app"]' ]
  [ "$(token_request | jq -cS .permissions)" = '{"actions":"read","contents":"write","issues":"write","metadata":"read","pull_requests":"write"}' ]
}

@test "mint signs its requests with a JWT from the App key" {
  given_app
  run "$sbx_token" mint --repo me/app
  [ "$status" -eq 0 ]
  verify_jwt "$(jq -r 'select(.path == "/repos/me/app/installation") | .auth' "$FAKE_STATE/curl.log")"
}

@test "mint applies permission overrides, and none drops a default" {
  given_app
  run "$sbx_token" mint --repo me/app --perm workflows=write --perm issues=none --perm contents=read
  [ "$status" -eq 0 ]
  [ "$(token_request | jq -cS .permissions)" = '{"actions":"read","contents":"read","metadata":"read","pull_requests":"write","workflows":"write"}' ]
}

@test "mint takes several repositories of one owner" {
  given_app
  run "$sbx_token" mint --repo me/app --repo me/lib
  [ "$status" -eq 0 ]
  [ "$(token_request | jq -c .repositories)" = '["app","lib"]' ]
}

@test "mint refuses repositories of different owners" {
  given_app
  run "$sbx_token" mint --repo me/app --repo other/lib
  [ "$status" -eq 1 ]
  [[ "$output" == *"different owner"* ]]
  [ ! -s "$FAKE_STATE/curl.log" ]
}

@test "mint refuses a permission above the App's ceiling, before it calls GitHub" {
  given_app
  run "$sbx_token" mint --repo me/app --perm administration=write
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot grant administration=write"* ]]
  [ ! -s "$FAKE_STATE/curl.log" ]

  run "$sbx_token" mint --repo me/app --perm actions=write
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot grant actions=write"* ]]
}

@test "mint refuses a malformed repository or permission" {
  given_app
  run "$sbx_token" mint --repo 'me/app;rm -rf ~'
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a repository"* ]]

  run "$sbx_token" mint --repo me/app --perm contents=admin
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a permission"* ]]
}

@test "mint needs a repository" {
  given_app
  run "$sbx_token" mint
  [ "$status" -eq 1 ]
  [[ "$output" == *"--repo"* ]]
}

@test "mint gives the install URL when the App is not installed on the owner" {
  given_app
  FAKE_GH_OWNERS=someone-else run "$sbx_token" mint --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed on me"* ]]
  [[ "$output" == *"https://github.com/apps/me-sbx/installations/new"* ]]
}

@test "mint reports GitHub's message when the token is refused" {
  given_app
  FAKE_GH_TOKEN_ERROR="There is at least one repository that does not exist" run "$sbx_token" mint --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not mint a token for me/app: There is at least one repository"* ]]
}

@test "mint reports when GitHub cannot be reached" {
  given_app
  FAKE_GH_DOWN=1 run "$sbx_token" mint --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"GitHub could not be reached (curl exit 6)"* ]]
}

@test "mint without an App points to the bootstrap steps" {
  run "$sbx_token" mint --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"bootstrap.md"* ]]
  [[ "$output" == *"sbx-token import-key"* ]]
}

@test "mint without a key in the store says so" {
  given_app
  rm "$FAKE_STATE/store"
  run "$sbx_token" mint --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"no App private key in the secret-tool store"* ]]
  [ ! -s "$FAKE_STATE/curl.log" ]
}

@test "register stores the mint command as the sandbox's GitHub secret" {
  given_app
  run "$sbx_token" register app-feature --repo me/app --perm workflows=write
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/secrets/app-feature")" = "'$sbx_token' mint --repo me/app --perm workflows=write" ]
  grep -q '^secret set github --sandbox app-feature --command ' "$FAKE_STATE/sbx.log"
}

@test "register does not store a secret when the first token cannot be minted" {
  given_app
  FAKE_GH_OWNERS=nobody run "$sbx_token" register app-feature --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
  [ ! -e "$FAKE_STATE/secrets/app-feature" ]
}

@test "register refuses a helper that is not installed" {
  given_app
  SBX_TOKEN_BIN="$BATS_TEST_TMPDIR/missing" run "$sbx_token" register app-feature --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"run sync-env"* ]]
}

@test "register resolves a symlinked helper to the installed copy" {
  given_app
  mkdir -p "$HOME/.local/bin"
  ln -s "$sbx_token" "$HOME/.local/bin/sbx-token"
  SBX_TOKEN_BIN="$HOME/.local/bin/sbx-token" run "$sbx_token" register app-feature --repo me/app
  [ "$status" -eq 0 ]
  [[ "$(cat "$FAKE_STATE/secrets/app-feature")" == "'$sbx_token' mint "* ]]
}

@test "register needs a sandbox name" {
  given_app
  run "$sbx_token" register --repo me/app
  [ "$status" -eq 1 ]
  [[ "$output" == *"name the sandbox"* ]]
}

@test "check reports the accounts the App is installed on" {
  given_app
  run "$sbx_token" check
  [ "$status" -eq 0 ]
  [ "$output" = "me-sbx, installed on me" ]
}

@test "check exits 3 when no App is set up" {
  run "$sbx_token" check
  [ "$status" -eq 3 ]
}

@test "check names the permissions an installation lacks" {
  given_app
  FAKE_GH_INSTALLATIONS='[{"account": {"login": "me"}, "repository_selection": "all", "permissions": {"contents": "read", "pull_requests": "write", "issues": "write", "actions": "read", "metadata": "read"}}]' \
    run "$sbx_token" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"lacks permissions on me (contents=write workflows=write)"* ]]
}

@test "check notes an installation on selected repositories only" {
  given_app
  FAKE_GH_INSTALLATIONS="$(jq -c '.[0].repository_selection = "selected"' <<<'[{"account": {"login": "me"}, "permissions": {"contents": "write", "pull_requests": "write", "issues": "write", "actions": "read", "workflows": "write", "metadata": "read"}}]')" \
    run "$sbx_token" check
  [ "$status" -eq 0 ]
  [ "$output" = "me-sbx, installed on me (only selected repositories on me)" ]
}

@test "check fails when the App is installed nowhere" {
  given_app
  FAKE_GH_INSTALLATIONS='[]' run "$sbx_token" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed on any account"* ]]
}

@test "import-key stores the key and reads the slug from GitHub" {
  run "$sbx_token" import-key --app-id 99 "$FAKE_PEM"
  [ "$status" -eq 0 ]
  [ "$(jq -c . "$XDG_CONFIG_HOME/sbx-token/config.json")" = '{"app_id":99,"slug":"me-sbx"}' ]
  [ "$(openssl base64 -d -A <"$FAKE_STATE/store")" = "$(cat "$FAKE_PEM")" ]
}

@test "import-key refuses a file that is not a private key" {
  echo "not a key" >"$BATS_TEST_TMPDIR/app.pem"
  run "$sbx_token" import-key --app-id 99 "$BATS_TEST_TMPDIR/app.pem"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a private key"* ]]
  [ ! -e "$FAKE_STATE/store" ]
}

@test "import-key does not save the config when the key does not authenticate" {
  FAKE_GH_BAD_KEY=1 run "$sbx_token" import-key --app-id 99 "$FAKE_PEM"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not authenticate as App 99"* ]]
  [ ! -e "$XDG_CONFIG_HOME/sbx-token/config.json" ]
}

@test "the Keychain backend keeps the key off argv" {
  export SBX_TOKEN_STORE=security
  run "$sbx_token" import-key --app-id 99 "$FAKE_PEM"
  [ "$status" -eq 0 ]
  ! grep -q "$(openssl base64 -A <"$FAKE_PEM" | cut -c1-40)" "$FAKE_STATE/security.argv"

  run "$sbx_token" mint --repo me/app
  [ "$status" -eq 0 ]
  [ "$output" = "ghs_fake" ]
}

@test "no verb asks gh for its token" {
  given_app
  "$sbx_token" mint --repo me/app >/dev/null
  "$sbx_token" register app-feature --repo me/app 2>/dev/null
  [ ! -e "$FAKE_STATE/gh.log" ] || ! grep -q token "$FAKE_STATE/gh.log"
}

@test "check --offline only looks for the config and the key" {
  given_app
  run "$sbx_token" check --offline
  [ "$status" -eq 0 ]
  [ "$output" = "me-sbx, key stored (not checked with GitHub)" ]
  [ ! -s "$FAKE_STATE/curl.log" ]

  rm "$FAKE_STATE/store"
  run "$sbx_token" check --offline
  [ "$status" -eq 1 ]
}
