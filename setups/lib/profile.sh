#!/usr/bin/env bash
#
# Profile resolution.
#
# A profile names the use-case of a machine, not just its operating system. It
# decides which scripts under ./setups/ run and which environment files
# ./sync-env copies.
#
# Resolution order, first match wins:
#   1. $DOTFILES_PROFILE          (a one-off override; never persisted)
#   2. --profile <name>           (passed in by the caller; persisted)
#   3. the persisted profile file (see PROFILE_FILE below)
#   4. detection, confirmed by the user (persisted)
#
# Requires setups/lib/platform.sh to be sourced first.

PROFILE_FILE="${DOTFILES_PROFILE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile}"

PROFILES=(dev-mac dev-linux infosec-qubes sbx-linux ai-server)

# profile_list prints the known profiles on one line, for error messages.
profile_list() { echo "${PROFILES[*]}"; }

is_profile() {
  local candidate="$1" profile
  for profile in "${PROFILES[@]}"; do
    [[ "$profile" == "$candidate" ]] && return 0
  done
  return 1
}

# profile_os prints the operating system a profile requires.
profile_os() {
  case "$1" in
  dev-mac) echo "mac" ;;
  dev-linux | infosec-qubes | sbx-linux | ai-server) echo "linux" ;;
  esac
}

# detect_profile prints the profile that suits this machine, or nothing if it
# cannot tell. A sandbox is checked before the other Linux profiles because it
# is the most specific.
#
# The order of the last three tests carries meaning. A sandbox runs on Ubuntu
# too, so is_sandbox has to be asked before is_ubuntu, or every sandbox would
# detect as ai-server. The final is_linux keeps a distribution that matches
# none of the tests on the dev-linux profile, as before.
detect_profile() {
  if is_mac; then
    echo "dev-mac"
  elif is_sandbox; then
    echo "sbx-linux"
  elif is_qubes; then
    echo "infosec-qubes"
  elif is_fedora; then
    echo "dev-linux"
  elif is_ubuntu; then
    echo "ai-server"
  elif is_linux; then
    echo "dev-linux"
  fi
}

# assert_profile_compatible stops a profile from running on the wrong OS, so a
# stale profile file cannot call brew on Linux, or dnf on a Mac. A dry run only
# warns, so any profile can be previewed from any machine.
assert_profile_compatible() {
  local profile="$1" want
  want="$(profile_os "$profile")"

  if [[ "$want" == "mac" ]] && ! is_mac; then
    printf "profile '%s' needs macOS, but this machine is not a Mac\n" "$profile" >&2
    return 1
  fi
  if [[ "$want" == "linux" ]] && ! is_linux; then
    printf "profile '%s' needs Linux, but this machine is not Linux\n" "$profile" >&2
    return 1
  fi
}

persist_profile() {
  local profile="$1"
  mkdir -p "$(dirname "$PROFILE_FILE")"
  printf '%s\n' "$profile" >"$PROFILE_FILE"
  printf 'Saved profile %s to %s\n' "$profile" "$PROFILE_FILE" >&2
}

# confirm_profile asks the user to accept a detected profile. It fails when
# there is no terminal to ask on, so an unattended run never guesses.
confirm_profile() {
  local profile="$1" answer

  if [[ ! -t 0 ]]; then
    printf 'No profile is set and there is no terminal to ask on.\n' >&2
    printf 'Pass --profile <name> or set $DOTFILES_PROFILE. Known profiles: %s\n' \
      "$(profile_list)" >&2
    return 1
  fi

  printf 'No profile is set for this machine. Detected: %s\n' "$profile" >&2
  printf 'Known profiles: %s\n' "$(profile_list)" >&2
  read -r -p "Use '$profile'? [y/N] " answer
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

# resolve_profile prints the profile to use on stdout. Every message it writes
# goes to stderr, so the caller can capture the result with $(...).
#
# Usage: resolve_profile [<requested>] [<dry>]
#   <requested>  the value of --profile, or empty
#   <dry>        "1" during a dry run: nothing is written and nothing is asked
resolve_profile() {
  local requested="${1:-}" dry="${2:-0}" profile="" persist="0"

  if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
    profile="$DOTFILES_PROFILE"
  elif [[ -n "$requested" ]]; then
    profile="$requested"
    persist="1"
  elif [[ -f "$PROFILE_FILE" ]]; then
    profile="$(tr -d '[:space:]' <"$PROFILE_FILE")"
  else
    profile="$(detect_profile)"
    if [[ -z "$profile" ]]; then
      printf 'Cannot detect a profile for this machine (OSTYPE=%s).\n' "$OSTYPE" >&2
      printf 'Pass --profile <name>. Known profiles: %s\n' "$(profile_list)" >&2
      return 1
    fi
    if [[ "$dry" == "1" ]]; then
      printf 'No profile is set. Using the detected profile %s for this dry run.\n' \
        "$profile" >&2
      printf 'A real run asks you to confirm it, then saves it to %s\n' "$PROFILE_FILE" >&2
    else
      confirm_profile "$profile" || return 1
      persist="1"
    fi
  fi

  if [[ -z "$profile" ]]; then
    printf 'The profile is empty. Known profiles: %s\n' "$(profile_list)" >&2
    return 1
  fi
  if ! is_profile "$profile"; then
    printf "Unknown profile '%s'. Known profiles: %s\n" "$profile" "$(profile_list)" >&2
    return 1
  fi
  if ! assert_profile_compatible "$profile"; then
    [[ "$dry" == "1" ]] || return 1
    printf 'Continuing anyway, because a dry run changes nothing.\n' >&2
  fi

  if [[ "$persist" == "1" && "$dry" != "1" ]]; then
    persist_profile "$profile"
  fi

  printf '%s\n' "$profile"
}
