#!/usr/bin/env bash
#
# Machine configuration for the ai-server profile.
#
# Sourced by every setup script that needs an answer it cannot work out for
# itself. The answers live in /etc/ai-server/config.env, written once by
# 00_preflight, so that a run never stops half way to ask a question.
#
# Two rules decide everything here.
#
# **Environment wins.** A variable already set in the environment is left
# alone. That is how an unattended run, a second machine, or a one-off states
# an answer without editing a file. A variable set to the empty string counts
# as set, and so means "ignore the file", not "unanswered".
#
# **The file is parsed, not sourced.** Sourcing would run whatever is in it as
# code, and the scripts that read it go on to use sudo. Only plain assignments
# to upper-case names are honoured; anything else is ignored rather than
# executed.
#
# Secrets never appear here. The file is mode 644 because every tool that
# reports on this machine has to read it, and that is only safe while the rule
# holds. A setup key is prompted for at the moment it is used.
#
# Source lives in the dotfiles repo at setups/ai-server/lib/config.sh.
# ./setup only runs files directly inside a profile directory, so nothing under
# lib/ is ever mistaken for a setup step.

ai_server_config="${AI_SERVER_CONFIG:-/etc/ai-server/config.env}"

# Which settings came from the file. Recorded during the load, because it
# cannot be worked out afterwards: a value present in both places has already
# been decided by the environment, and the file still holds a line for it.
declare -A ai_server_origin=()

# ---------------------------------------------------------------------------
# ai_server_config_load reads the file into the environment, skipping anything
# already set. It is safe to call when the file does not exist: a machine that
# has not run 00_preflight yet has no answers, which the callers report through
# ai_server_require rather than by failing here.
# ---------------------------------------------------------------------------
ai_server_config_load() {
  local line key value

  [[ -r "$ai_server_config" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || continue

    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"

    # One layer of matching quotes, so a value with spaces can be written the
    # way a person would expect.
    if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi

    # Set, even to empty, means the caller has spoken.
    [[ -n "${!key+set}" ]] && continue

    export "$key=$value"
    ai_server_origin["$key"]="$ai_server_config"
  done <"$ai_server_config"
}

# ---------------------------------------------------------------------------
# ai_server_require names the settings a script cannot run without, and stops
# with one message listing every missing one rather than failing on the first.
#
# It points at the preflight rather than at the file, because editing the file
# by hand skips the validation that makes a value safe to act on.
# ---------------------------------------------------------------------------
ai_server_require() {
  local key missing=()

  for key in "$@"; do
    [[ -n "${!key:-}" ]] || missing+=("$key")
  done

  [[ ${#missing[@]} -eq 0 ]] && return 0

  cat >&2 <<EOF

${0##*/}: this machine has no answer for: ${missing[*]}

These are asked once, before anything is installed:

  ./setup 00_preflight

They can also be given in the environment for an unattended run:

  ${missing[0]}=<value> ./setup

EOF
  return 1
}

# ---------------------------------------------------------------------------
# ai_server_config_summary prints what is in effect, and where each value came
# from. Used by 00_preflight, and by anything that wants to show the machine's
# answers without re-reading the file itself.
# ---------------------------------------------------------------------------
ai_server_config_summary() {
  local key value origin

  for key in "$@"; do
    value="${!key:-}"

    if [[ -z "$value" ]]; then
      origin="unset, the default applies"
    elif [[ -n "${ai_server_origin[$key]:-}" ]]; then
      origin="${ai_server_origin[$key]}"
    else
      origin="environment"
    fi

    printf '  %-30s %-12s %s\n' "$key" "$value" "$origin"
  done
}
