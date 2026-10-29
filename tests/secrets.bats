#!/usr/bin/env bats
#
# secrets, through its command line, with a fake age (tests/fakes/bin/age)
# and a store in the test's own directory.

load helpers

setup() {
  common_setup
  export SECRETS_HOME="$BATS_TEST_TMPDIR/secrets"
  : >"$FAKE_STATE/age.argv"
  secrets="$repo_root/commands/secrets/secrets"
}

# given_store sets the store up as if secrets init had run with two YubiKeys.
given_store() {
  mkdir -p "$SECRETS_HOME"
  chmod 700 "$SECRETS_HOME"
  printf 'AGE-PLUGIN-YUBIKEY-1MAIN\nAGE-PLUGIN-YUBIKEY-1BACKUP\n' >"$SECRETS_HOME/identities.txt"
  printf '# main\nage1yubikey1main\n# backup\nage1yubikey1backup\n' >"$SECRETS_HOME/recipients.txt"
}

# set_values <project> <scope> <KEY=value>... sets the values through the
# prompt, one line each on stdin.
set_values() {
  local project="$1" scope="$2" pair keys=() values=""
  shift 2
  for pair in "$@"; do
    keys+=("${pair%%=*}")
    values+="${pair#*=}"$'\n'
  done
  printf '%s' "$values" | "$secrets" set "$project" "$scope" "${keys[@]}"
}

# value_of <project> <scope> <KEY> prints a value through get. Its stdout is
# a command substitution, not a terminal.
value_of() {
  "$secrets" get "$1" "$2" "$3"
}

@test "set stores the values, and get prints one of them" {
  given_store
  run set_values app production DATABASE_URL=postgres://db TOKEN=t0k
  [ "$status" -eq 0 ]
  [ "$(value_of app production DATABASE_URL)" = "postgres://db" ]
  [ "$(value_of app production TOKEN)" = "t0k" ]
}

@test "set keeps the other keys of the scope" {
  given_store
  set_values app production DATABASE_URL=postgres://db TOKEN=t0k
  run set_values app production TOKEN=new
  [ "$status" -eq 0 ]
  [ "$(value_of app production DATABASE_URL)" = "postgres://db" ]
  [ "$(value_of app production TOKEN)" = "new" ]
}

@test "set decrypts once and encrypts once" {
  given_store
  set_values app production A=1
  : >"$FAKE_STATE/age.argv"
  set_values app production B=2 C=3
  [ "$(grep -c -- '--decrypt' "$FAKE_STATE/age.argv")" -eq 1 ]
  [ "$(grep -c -- '--encrypt' "$FAKE_STATE/age.argv")" -eq 1 ]
}

@test "set and keys never print a value, and age never gets one in its arguments" {
  given_store
  run set_values app production TOKEN=s3cr3t
  [ "$status" -eq 0 ]
  [[ "$output" != *s3cr3t* ]]
  run "$secrets" keys app production
  [ "$status" -eq 0 ]
  [ "$output" = "TOKEN" ]
  run "$secrets" keys app
  [ "$output" = "production" ]
  ! grep -q s3cr3t "$FAKE_STATE/age.argv"
}

@test "get fails for a key that the scope does not hold" {
  given_store
  set_values app production A=1
  run value_of app production MISSING
  [ "$status" -eq 1 ]
  [[ "$output" == *"production has no MISSING"* ]]
}

@test "get refuses to print to a terminal" {
  command -v script >/dev/null 2>&1 || skip "script(1) is not installed"
  given_store
  set_values app production TOKEN=s3cr3t
  run script -qec "$secrets get app production TOKEN" /dev/null
  [[ "$output" == *"does not print to a terminal"* ]]
  [[ "$output" != *s3cr3t* ]]
}

@test "run gives the command the keys of the one scope, and no other" {
  given_store
  set_values app production DATABASE_URL=postgres://prod TOKEN=t0k
  set_values app preview PREVIEW_URL=postgres://preview
  run "$secrets" run app production -- env
  [ "$status" -eq 0 ]
  [[ "$output" == *"DATABASE_URL=postgres://prod"* ]]
  [[ "$output" == *"TOKEN=t0k"* ]]
  [[ "$output" != *PREVIEW_URL* ]]
}

@test "run passes the exit status of the command through" {
  given_store
  set_values app production A=1
  run "$secrets" run app production -- sh -c 'exit 7'
  [ "$status" -eq 7 ]
}

@test "a failed encrypt leaves the old file" {
  given_store
  set_values app production TOKEN=old
  cp "$SECRETS_HOME/app/production.age" "$BATS_TEST_TMPDIR/before"
  FAKE_AGE_FAIL=encrypt run set_values app production TOKEN=new
  [ "$status" -eq 1 ]
  [[ "$output" == *"unchanged"* ]]
  cmp "$SECRETS_HOME/app/production.age" "$BATS_TEST_TMPDIR/before"
  [ "$(ls "$SECRETS_HOME/app")" = "production.age" ]
}

@test "rekey encrypts every scope to the current recipients, and keeps every value" {
  given_store
  set_values app production A=1 B=2
  set_values other ci C=3
  printf 'age1yubikey1main\nage1yubikey1new\n' >"$SECRETS_HOME/recipients.txt"
  run "$secrets" rekey
  [ "$status" -eq 0 ]
  [[ "$output" == *"encrypted 2 scopes again"* ]]
  [ "$(head -1 "$SECRETS_HOME/app/production.age")" = "fake-age age1yubikey1main,age1yubikey1new" ]
  [ "$(head -1 "$SECRETS_HOME/other/ci.age")" = "fake-age age1yubikey1main,age1yubikey1new" ]
  [ "$(value_of app production A)" = "1" ]
  [ "$(value_of app production B)" = "2" ]
  [ "$(value_of other ci C)" = "3" ]
}

@test "rekey of one project leaves the others" {
  given_store
  set_values app production A=1
  set_values other ci C=3
  printf 'age1yubikey1new\n' >"$SECRETS_HOME/recipients.txt"
  run "$secrets" rekey app
  [ "$status" -eq 0 ]
  [ "$(head -1 "$SECRETS_HOME/app/production.age")" = "fake-age age1yubikey1new" ]
  [ "$(head -1 "$SECRETS_HOME/other/ci.age")" = "fake-age age1yubikey1backup,age1yubikey1main" ]
}

@test "the recipients of a project replace the shared ones" {
  given_store
  mkdir -p "$SECRETS_HOME/app"
  printf 'age1yubikey1project\n' >"$SECRETS_HOME/app/recipients.txt"
  set_values app production A=1
  [ "$(head -1 "$SECRETS_HOME/app/production.age")" = "fake-age age1yubikey1project" ]
}

@test "init makes a private store, makes an age slot, and adds its identity and recipient" {
  run "$secrets" init
  [ "$status" -eq 0 ]
  [ "$(stat -c %a "$SECRETS_HOME")" = "700" ]
  [ "$(stat -c %a "$SECRETS_HOME/identities.txt")" = "600" ]
  grep -q -- '--generate --pin-policy once --touch-policy always' "$FAKE_STATE/age-plugin-yubikey.argv"
  grep -qx 'AGE-PLUGIN-YUBIKEY-1KEY1' "$SECRETS_HOME/identities.txt"
  grep -qx 'age1yubikey1key1' "$SECRETS_HOME/recipients.txt"
  [[ "$output" == *"backup YubiKey"* ]]
}

@test "init with the backup YubiKey adds it, and adds no key twice" {
  "$secrets" init
  FAKE_YUBIKEY=key2 "$secrets" init
  run "$secrets" init
  [ "$status" -eq 0 ]
  [[ "$output" == *"in the store already"* ]]
  [ "$(grep -c '^age1' "$SECRETS_HOME/recipients.txt")" -eq 2 ]
  [ "$(grep -c '^AGE-PLUGIN' "$SECRETS_HOME/identities.txt")" -eq 2 ]
}

@test "stored_secret sets a variable from the store, and returns 1 when the store does not have it" {
  given_store
  set_values app production TOKEN=t0k
  run bash -c 'source "$1"; stored_secret v app production TOKEN && printf "%s" "$v"' _ "$repo_root/commands/secrets/lib/store.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "t0k" ]
  run bash -c 'source "$1"; stored_secret v app production MISSING' _ "$repo_root/commands/secrets/lib/store.sh"
  [ "$status" -eq 1 ]
  run bash -c 'source "$1"; stored_secret v app preview TOKEN' _ "$repo_root/commands/secrets/lib/store.sh"
  [ "$status" -eq 1 ]
}
