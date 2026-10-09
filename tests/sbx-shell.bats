#!/usr/bin/env bats
#
# sbx-shell, through its command line.

load helpers

setup() {
  common_setup
  sbx_shell="$repo_root/commands/sbx-shell/sbx-shell"
  export FAKE_SBX_SANDBOXES="app app-feature"
  : >"$FAKE_STATE/tmux.log"
}

@test "in tmux, it opens a shell-<sandbox> window that waits, then runs a login shell" {
  TMUX=fake run "$sbx_shell" app-feature
  [ "$status" -eq 0 ]
  [ "$(sed -n 1,3p "$FAKE_STATE/tmux.log" | tr '\n' ' ')" = "new-window -n shell-app-feature " ]
  launch="$(sed -n '4,/^$/p' "$FAKE_STATE/tmux.log")"
  [[ "$launch" == "$repo_root/commands/sbx-shell/libexec/sbx-wait app-feature"* ]]
  [[ "$launch" == *"Press enter to close this window"* ]]
  [[ "$launch" == *"exec sbx exec -it app-feature -- bash -l "* ]]
}

@test "outside tmux, it waits and runs the shell in this terminal" {
  unset TMUX
  run "$sbx_shell" app
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready in"* ]]
  [ "$(tail -1 "$FAKE_STATE/sbx.log")" = "exec -it app -- bash -l" ]
  [ ! -s "$FAKE_STATE/tmux.log" ]
}

@test "it waits for the dotfiles kit when the kit is configuring the sandbox" {
  unset TMUX
  FAKE_SBX_KIT_STATUS=ready run "$sbx_shell" app
  [ "$status" -eq 0 ]
  grep -q 'cat "$HOME/.dotfiles-kit.status"' "$FAKE_STATE/sbx.log"
  [ "$(tail -1 "$FAKE_STATE/sbx.log")" = "exec -it app -- bash -l" ]
}

@test "a failed dotfiles kit still opens the shell, after the end of the kit log" {
  unset TMUX
  FAKE_SBX_KIT_STATUS=failed run "$sbx_shell" app
  [ "$status" -eq 0 ]
  [[ "$output" == *"the dotfiles kit failed"* ]]
  [[ "$output" == *"the kit log"* ]]
  [ "$(tail -1 "$FAKE_STATE/sbx.log")" = "exec -it app -- bash -l" ]
}

@test "an unknown sandbox is reported, and nothing opens" {
  TMUX=fake run "$sbx_shell" nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"no sandbox is named nope"* ]]
  [ ! -s "$FAKE_STATE/tmux.log" ]
}

@test "the name must be whole, not a prefix of another sandbox" {
  TMUX=fake run "$sbx_shell" app-feat
  [ "$status" -eq 1 ]
}

@test "it needs exactly one sandbox name" {
  run "$sbx_shell"
  [ "$status" -eq 1 ]
  [[ "$output" == *"name the sandbox"* ]]

  run "$sbx_shell" app app-feature
  [ "$status" -eq 1 ]
  [[ "$output" == *"only one sandbox"* ]]
}
