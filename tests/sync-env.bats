#!/usr/bin/env bats
#
# sync-env and the doctor drift check, through their command lines, against a
# fake checkout and a fake home.

load helpers

setup() {
  common_setup
  export XDG_STATE_HOME="$HOME/.local/state"
  record="$XDG_STATE_HOME/dotfiles/synced"
  sync_env="$repo_root/commands/sync-env/sync-env"
  doctor="$repo_root/commands/doctor/doctor"

  # No terminal, unless a test gives answers. A run from a real terminal must
  # never wait for one.
  export PROMPT_TTY="$BATS_TEST_TMPDIR/no-terminal"

  checkout="$BATS_TEST_TMPDIR/checkout"
  export DOTFILES_DIR="$checkout"
  if [[ "$OSTYPE" == darwin* ]]; then
    export DOTFILES_PROFILE="dev-mac"
  else
    export DOTFILES_PROFILE="dev-linux"
  fi

  mkdir -p "$checkout/env/.config/app/sub" "$checkout/env/skills/one" \
    "$checkout/commands/hello" "$checkout/profiles/$DOTFILES_PROFILE"
  ln -s "$repo_root/lib" "$checkout/lib"
  echo "rc" >"$checkout/env/.testrc"
  echo "a" >"$checkout/env/.config/app/a.conf"
  echo "b" >"$checkout/env/.config/app/sub/b.conf"
  echo "one" >"$checkout/env/skills/one/SKILL.md"
  printf '#!/bin/sh\necho hello\n' >"$checkout/commands/hello/hello"
  chmod +x "$checkout/commands/hello/hello"

  cat >"$checkout/profiles/$DOTFILES_PROFILE/env.manifest" <<'EOF'
group Test
file .testrc $HOME
dir .config/app $HOME/.config/app
subdirs skills $HOME/skills
command hello $HOME/.local
EOF
}

# answer makes the next prompts read <answer> from a fake terminal.
answer() {
  echo "$1" >"$BATS_TEST_TMPDIR/terminal"
  export PROMPT_TTY="$BATS_TEST_TMPDIR/terminal"
}

@test "a first sync copies everything, writes a record, and finds no drift" {
  run "$sync_env"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Drift"* ]]
  [ "$(cat "$HOME/.testrc")" = "rc" ]
  [ "$(cat "$HOME/.local/bin/hello")" = "$(cat "$checkout/commands/hello/hello")" ]
  grep -q "	file env/.testrc $HOME	$HOME/.testrc$" "$record"
  grep -q "	dir env/.config/app $HOME/.config/app	$HOME/.config/app/sub/b.conf$" "$record"
  grep -q "$HOME/skills/one/SKILL.md$" "$record"
  grep -q "$HOME/.local/lib/hello/hello$" "$record"
}

@test "changes on the repo side are not drift" {
  "$sync_env"
  echo "rc2" >"$checkout/env/.testrc"
  rm "$checkout/env/.config/app/sub/b.conf"
  echo "new" >"$checkout/env/.config/app/new.conf"

  run "$sync_env"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Drift"* ]]
  [ "$(cat "$HOME/.testrc")" = "rc2" ]
  [ ! -e "$HOME/.config/app/sub/b.conf" ]
  ! grep -q "b.conf" "$record"
}

@test "a changed, an added and a deleted file are drift, with a diff" {
  "$sync_env"
  echo "mine" >"$HOME/.config/app/a.conf"
  echo "secret" >"$HOME/.config/app/secret.conf"
  rm "$HOME/.config/app/sub/b.conf"

  run "$sync_env" --dry
  [ "$status" -eq 0 ]
  [[ "$output" == *"Drift in ~/.config/app (dir)"* ]]
  [[ "$output" == *"changed  ~/.config/app/a.conf"* ]]
  [[ "$output" == *"added    ~/.config/app/secret.conf"* ]]
  [[ "$output" == *"deleted  ~/.config/app/sub/b.conf"* ]]
  [[ "$output" == *"-mine"* ]]
  [[ "$output" == *"+a"* ]]
  [[ "$output" == *"-secret"* ]]
}

@test "files outside the paths that a target replaces are never drift" {
  "$sync_env"
  echo "x" >"$HOME/.other-rc"
  mkdir -p "$HOME/.config/gh" "$HOME/skills/local"
  echo "token" >"$HOME/.config/gh/hosts.yml"
  echo "local" >"$HOME/skills/local/SKILL.md"

  run "$sync_env" --dry
  [ "$status" -eq 0 ]
  [[ "$output" != *"Drift"* ]]
}

@test "a file that already matches the source is not drift" {
  "$sync_env"
  echo "rc2" >"$checkout/env/.testrc"
  echo "rc2" >"$HOME/.testrc"

  run "$sync_env" --dry
  [[ "$output" != *"Drift"* ]]
}

@test "a declined prompt keeps the drift and the old record, and asks again" {
  "$sync_env"
  echo "mine" >"$HOME/.testrc"
  echo "rc2" >"$checkout/env/.testrc"
  cp "$record" "$BATS_TEST_TMPDIR/record.before"

  answer n
  run "$sync_env"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.testrc")" = "mine" ]
  [[ "$output" == *"Skipped, because you kept their drift:"* ]]
  [[ "$output" == *"  ~"* ]]
  grep "	file env/.testrc " "$record" >"$BATS_TEST_TMPDIR/after"
  grep "	file env/.testrc " "$BATS_TEST_TMPDIR/record.before" | diff - "$BATS_TEST_TMPDIR/after"

  run "$sync_env" --dry
  [[ "$output" == *"changed  ~/.testrc"* ]]
}

@test "an accepted prompt overwrites the drift" {
  "$sync_env"
  echo "mine" >"$HOME/.testrc"

  answer y
  run "$sync_env"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.testrc")" = "rc" ]
  [[ "$output" != *"WARNING"* ]]
}

@test "with no terminal, the drift is overwritten with a warning" {
  "$sync_env"
  echo "mine" >"$HOME/.config/app/a.conf"

  run "$sync_env"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: overwriting the drift in ~/.config/app"* ]]
  [ "$(cat "$HOME/.config/app/a.conf")" = "a" ]

  run "$sync_env" --dry
  [[ "$output" != *"Drift"* ]]
}

@test "--yes copies everything without a drift check, and writes the record" {
  "$sync_env"
  echo "mine" >"$HOME/.testrc"

  answer n
  run "$sync_env" --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"Drift"* ]]
  [[ "$output" != *"WARNING"* ]]
  [ "$(cat "$HOME/.testrc")" = "rc" ]

  run "$sync_env" --dry
  [[ "$output" != *"Drift"* ]]
}

@test "--dry shows the drift and writes nothing" {
  "$sync_env"
  echo "mine" >"$HOME/.testrc"
  echo "rc2" >"$checkout/env/.testrc"
  cp "$record" "$BATS_TEST_TMPDIR/record.before"

  answer y
  run "$sync_env" --dry
  [ "$status" -eq 0 ]
  [[ "$output" == *"would ask to overwrite the drift in ~"* ]]
  [ "$(cat "$HOME/.testrc")" = "mine" ]
  diff "$BATS_TEST_TMPDIR/record.before" "$record"
}

@test "with no record, a copy that differs from the source is drift" {
  echo "old" >"$HOME/.testrc"
  mkdir -p "$HOME/.config/app"
  echo "a" >"$HOME/.config/app/a.conf"

  run "$sync_env" --dry
  [[ "$output" == *"changed  ~/.testrc"* ]]
  [[ "$output" != *"Drift in ~/.config/app"* ]]
}

@test "a file that a later target wrote into the tree is not drift" {
  mkdir -p "$checkout/env/local/two"
  echo "two" >"$checkout/env/local/two/SKILL.md"
  # The subdirs line writes into the tree that the dir line replaces.
  cat >>"$checkout/profiles/$DOTFILES_PROFILE/env.manifest" <<'EOF'
dir skills $HOME/skills-all
subdirs local $HOME/skills-all
EOF
  "$sync_env"
  [ -f "$HOME/skills-all/two/SKILL.md" ]

  run "$sync_env" --dry
  [[ "$output" != *"Drift"* ]]

  echo "mine" >"$HOME/skills-all/two/SKILL.md"
  run "$sync_env" --dry
  [ "$(grep -c "^Drift in" <<<"$output")" -eq 1 ]
  [[ "$output" == *"Drift in ~/skills-all (subdirs)"* ]]
}

@test "an edited command is drift" {
  "$sync_env"
  echo "echo evil" >>"$HOME/.local/lib/hello/hello"

  run "$sync_env" --dry
  [[ "$output" == *"Drift in ~/.local (command)"* ]]
  [[ "$output" == *"changed  ~/.local/lib/hello/hello"* ]]
}

@test "doctor warns for each target with drift" {
  "$sync_env"
  echo "mine" >"$HOME/.testrc"
  echo "mine" >"$HOME/.config/app/a.conf"

  run "$doctor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dotfiles"* ]]
  [ "$(grep -c "drifted, see sync-env --dry" <<<"$output")" -eq 2 ]
}

@test "doctor says nothing about dotfiles without drift, or without a record" {
  run "$doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Dotfiles"* ]]

  "$sync_env"
  run "$doctor"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Dotfiles"* ]]
}
