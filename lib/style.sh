#!/usr/bin/env bash
#
# The output style that every command shares. docs/design.md is the
# specification: read it before you add a word or a color.
#
# Only the 16 basic ANSI colors and the attributes are used, so the terminal
# theme decides the real colors. Every variable is empty when stdout is not a
# terminal or $NO_COLOR is set, so the output reads the same in a pipe or a log.
#
# No other file writes an escape code. A command uses these variables and
# functions instead.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  STYLE_OK=$'\033[32m'
  STYLE_WARN=$'\033[33m'
  STYLE_FAIL=$'\033[31m'
  STYLE_MUTED=$'\033[2m'
  STYLE_INFO=$'\033[36m'
  STYLE_HEAD=$'\033[1m'
  STYLE_OFF=$'\033[0m'
else
  STYLE_OK="" STYLE_WARN="" STYLE_FAIL="" STYLE_MUTED="" STYLE_INFO="" STYLE_HEAD="" STYLE_OFF=""
fi

# The width of the status column: the longest status word.
_STYLE_WORD_WIDTH=7

# The width of the label column, when a detail follows it.
_STYLE_LABEL_WIDTH=34

# style_color prints the color of a status word. Each word belongs to exactly
# one color, so a word looks the same in every command.
#
# Usage: style_color <word>
style_color() {
  case "$1" in
  ok | copied | ran) printf '%s' "$STYLE_OK" ;;
  warn | drift) printf '%s' "$STYLE_WARN" ;;
  FAIL) printf '%s' "$STYLE_FAIL" ;;
  same | skipped | "not run" | pending) printf '%s' "$STYLE_MUTED" ;;
  tunable | info | copy) printf '%s' "$STYLE_INFO" ;;
  *)
    printf 'style: unknown status word "%s"\n' "$1" >&2
    return 1
    ;;
  esac
}

# status prints one result: the status word in its colored column, the label,
# and the detail if there is one.
#
# Usage: status <word> <label> [detail]
status() {
  local word="$1" label="$2" detail="${3:-}" color
  color="$(style_color "$word")"

  if [[ -n "$detail" ]]; then
    printf '  %s%-*s%s %-*s %s\n' "$color" "$_STYLE_WORD_WIDTH" "$word" "$STYLE_OFF" \
      "$_STYLE_LABEL_WIDTH" "$label" "$detail"
  else
    printf '  %s%-*s%s %s\n' "$color" "$_STYLE_WORD_WIDTH" "$word" "$STYLE_OFF" "$label"
  fi
}

# status_note prints a muted line under a status line, lined up with its label.
# A dry run uses it for the raw commands it would run.
#
# Usage: status_note <text>
status_note() {
  printf '  %*s %s%s%s\n' "$_STYLE_WORD_WIDTH" "" "$STYLE_MUTED" "$1" "$STYLE_OFF"
}

# section starts a group: a blank line, then its name in bold.
#
# Usage: section <name>
section() {
  printf '\n%s%s%s\n' "$STYLE_HEAD" "$1" "$STYLE_OFF"
}

# heading prints a bold line with no blank line before it, for the first line
# of a command's output.
#
# Usage: heading <text>
heading() {
  printf '%s%s%s\n' "$STYLE_HEAD" "$1" "$STYLE_OFF"
}

# verdict prints the last line of a command: the counts, in the color of the
# worst status. The caller prints the blank line and the table before it.
#
# Usage: verdict <worst word> <text>
verdict() {
  local color
  color="$(style_color "$1")"
  printf '%s%s%s%s\n' "$STYLE_HEAD" "$color" "$2" "$STYLE_OFF"
}

# style_clear_line erases the current terminal line, so that a progress line
# can be drawn again in its place. It prints nothing when stdout is not a
# terminal.
style_clear_line() {
  [[ -t 1 ]] && printf '\r\033[2K'
  return 0
}
