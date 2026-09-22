#!/usr/bin/env bash
#
# Prompts shared by the setup scripts.

# Ask a yes/no question before a step that is safe to skip.
#
# The answer is read from the terminal rather than from stdin, because a setup
# script can be reached through a pipe. With no terminal the answer is yes,
# since an unattended run is there to install things.
#
# Usage: if confirm "Update starship?"; then ...
confirm() {
  local answer
  # A test open, because a detached process has a readable /dev/tty that it
  # cannot open, and the failure would otherwise reach the terminal.
  (: </dev/tty) 2>/dev/null || return 0
  read -r -p "$1 [y/N] " answer </dev/tty || return 0
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}
