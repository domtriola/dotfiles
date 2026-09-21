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
# Secrets never appear here. The file is mode 644 so that every tool reporting
# on this machine can read it, which is only safe while that holds.

ai_server_config="${AI_SERVER_CONFIG:-/etc/ai-server/config.env}"

# Which settings came from the file. Recorded during the load: afterwards a
# value present in both places is indistinguishable from one only in the file.
declare -A ai_server_origin=()

# ---------------------------------------------------------------------------
# ai_server_config_load reads the file into the environment, skipping anything
# already set. A missing file is not an error here; ai_server_require is what
# reports a setting the caller needs.
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
# ai_server_require names the settings a script cannot run without, and lists
# every missing one rather than failing on the first.
#
# It points at the preflight rather than at the file, because a value written
# by hand skips validation.
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
