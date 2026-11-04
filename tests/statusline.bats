#!/usr/bin/env bats
#
# The Claude Code status line, in the dotfile copy and in the sandbox kit's copy.
# Each test gives a script the JSON that Claude Code sends, and reads what it prints.

load helpers

setup() {
  common_setup
  command -v jq >/dev/null 2>&1 || skip "jq is not installed"
  dotfile="$repo_root/env/.claude/statusline.sh"
  kit="$repo_root/sbx/kits/mixins/my-claude/files/home/.local/bin/statusline.sh"
  input='{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/src/app"},"cost":{"total_cost_usd":1.5,"total_duration_ms":65000},"context_window":{"used_percentage":12}}'
}

draw() {
  bash "$1" <<<"$input"
}

# A glyph that ends in U+FE0F has a width that depends on the program that
# measures it. Claude Code repaints only the changed cells, so a disagreement
# puts later digits in the wrong cells (issue #147).
@test "the status line prints no variation selector" {
  for script in "$dotfile" "$kit"; do
    run draw "$script"
    [ "$status" -eq 0 ]
    [[ "$output" != *$'\xef\xb8\x8f'* ]]
  done
}

@test "the status line shows the time as minutes and seconds" {
  for script in "$dotfile" "$kit"; do
    run draw "$script"
    [[ "$output" == *"1m 5s"* ]]
  done
}

@test "the kit's status line shows memory and load with their decimals" {
  [ -r /proc/loadavg ] || skip "this system has no /proc"
  run draw "$kit"
  [[ "$output" =~ mem\ [0-9]+\.[0-9]/[0-9]+\.[0-9]G ]]
  [[ "$output" =~ load\ [0-9]+\.[0-9]{2} ]]
}
