#!/usr/bin/env bats
#
# The runtime clone of kamaji: the copy that the host runs. kamaji-update keeps
# it at main, and the kamaji wrapper runs it. A local bare repository stands in
# for GitHub, and a fake pnpm logs its arguments.

load helpers

update="$repo_root/env/.local/bin/kamaji-update"
wrapper="$repo_root/env/.local/bin/kamaji"

setup() {
  common_setup
  export KAMAJI_REMOTE="$BATS_TEST_TMPDIR/kamaji.git"
  runtime="$HOME/.local/share/kamaji"
  git init --quiet --bare --initial-branch main "$KAMAJI_REMOTE"
  git clone --quiet "$KAMAJI_REMOTE" "$BATS_TEST_TMPDIR/upstream" 2>/dev/null
  upstream_commit "Add the CLI"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "$PWD $*" >>"%s/pnpm.log"\n' "$FAKE_STATE" >"$BATS_TEST_TMPDIR/bin/pnpm"
  chmod +x "$BATS_TEST_TMPDIR/bin/pnpm"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# upstream_commit merges a commit to main on the stand-in for GitHub. The CLI
# prints its arguments, its working directory and its snapshot directory.
upstream_commit() {
  local dir="$BATS_TEST_TMPDIR/upstream"
  echo '{"name": "kamaji", "bin": {"kamaji": "cli.js"}}' >"$dir/package.json"
  echo 'console.log(`args=${process.argv.slice(2).join(" ")} snapshot=${process.env.KAMAJI_SNAPSHOT_DIR ?? ""}`)' >"$dir/cli.js"
  echo "$1" >>"$dir/CHANGES"
  git -C "$dir" add -A
  git -C "$dir" -c user.name=t -c user.email=t@example.com commit --quiet -m "$1"
  git -C "$dir" push --quiet origin HEAD:main
}

@test "kamaji-update clones main the first time, and installs the locked dependencies" {
  run "$update"
  [ "$status" -eq 0 ]
  [ "$(git -C "$runtime" log -1 --format=%s)" = "Add the CLI" ]
  [ "$(cat "$FAKE_STATE/pnpm.log")" = "$runtime install --frozen-lockfile" ]
  [[ "${lines[-1]}" == "kamaji-update: the host now runs "*"Add the CLI" ]]
}

@test "kamaji-update fast-forwards to main, and lists the commits that it adds" {
  "$update"
  upstream_commit "Add the board"
  upstream_commit "Add the ranking"
  run "$update"
  [ "$status" -eq 0 ]
  [ "$(git -C "$runtime" log -1 --format=%s)" = "Add the ranking" ]
  [[ "$output" == *"Add the board"* && "$output" == *"Add the ranking"* ]]
}

@test "kamaji-update says when the runtime clone is already at main" {
  "$update"
  run "$update"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at main"* ]]
}

@test "kamaji-update refuses, and changes nothing, when the runtime clone has local changes" {
  "$update"
  echo "edited" >>"$runtime/CHANGES"
  upstream_commit "Add the board"
  run "$update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"local changes"* ]]
  [ "$(git -C "$runtime" log -1 --format=%s)" = "Add the CLI" ]
}

@test "kamaji-update refuses when the runtime clone has commits that are not on main" {
  "$update"
  git -C "$runtime" -c user.name=t -c user.email=t@example.com commit --quiet --allow-empty -m "Not reviewed"
  upstream_commit "Add the board"
  run "$update"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not on main"* ]]
}

@test "the kamaji wrapper runs the runtime clone, with the snapshot in the development checkout" {
  "$update"
  mkdir -p "$HOME/src/personal/kamaji"
  run "$wrapper" refresh --verbose
  [ "$status" -eq 0 ]
  [ "$output" = "args=refresh --verbose snapshot=$HOME/src/personal/kamaji/.kamaji" ]
}

@test "the kamaji wrapper sets no snapshot directory when there is no development checkout" {
  "$update"
  run "$wrapper" refresh
  [ "$output" = "args=refresh snapshot=" ]
}

@test "the kamaji wrapper refuses when the snapshot directory is a symlink" {
  "$update"
  mkdir -p "$HOME/src/personal/kamaji" "$HOME/elsewhere"
  ln -s "$HOME/elsewhere" "$HOME/src/personal/kamaji/.kamaji"
  run "$wrapper" refresh
  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink"* ]]
  [[ "$output" != *"args="* ]]
}

@test "the kamaji wrapper names kamaji-update when the runtime clone is missing" {
  run "$wrapper" board
  [ "$status" -ne 0 ]
  [[ "$output" == *"not installed, run kamaji-update"* ]]
}
