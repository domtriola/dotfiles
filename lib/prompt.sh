#!/usr/bin/env bash
#
# Prompts shared by the setup steps and the commands.

# Ask a yes/no question before a step that is safe to skip.
#
# The answer is read from the terminal rather than from stdin, because a setup
# setup step can be reached through a pipe. With no terminal the answer is yes,
# since an unattended run is there to install things.
#
# Usage: if confirm "Update starship?"; then ...
confirm() {
  local answer
  has_terminal || return 0
  read -r -p "$1 [y/N] " answer <"${PROMPT_TTY:-/dev/tty}" || return 0
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

# has_terminal reports whether a question can be asked. $PROMPT_TTY replaces
# the terminal, so that a test can answer from a file.
has_terminal() {
  # A test open, because a detached process has a readable /dev/tty that it
  # cannot open, and the failure would otherwise reach the terminal.
  (: <"${PROMPT_TTY:-/dev/tty}") 2>/dev/null
}
