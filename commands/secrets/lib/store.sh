#!/usr/bin/env bash
#
# The store: where it is, and how a scope is read and written. The secrets
# command sources this file, and so can a project's shell script, in place of
# its own copy:
#
#   source "$HOME/.local/lib/secrets/lib/store.sh"
#   stored_secret DATABASE_URL app production DATABASE_URL ||
#     read -rsp "DATABASE_URL: " DATABASE_URL
#
# macOS ships bash 3.2, so nothing here needs bash 4. Nothing here exits or
# sets a shell option. A plaintext goes only through pipes, command
# substitutions and parameter expansions: never a file, a here-string or a
# heredoc, which bash can write to /tmp.

secrets_home() {
  printf '%s' "${SECRETS_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/secrets}"
}

# secrets_scope_file <project> <scope>
secrets_scope_file() {
  printf '%s/%s/%s.age' "$(secrets_home)" "$1" "$2"
}

# secrets_recipients <project> prints the recipients file that the scopes of
# the project are encrypted to: the project's own, if it has one.
secrets_recipients() {
  local own
  own="$(secrets_home)/$1/recipients.txt"
  if [[ -f "$own" ]]; then
    printf '%s' "$own"
  else
    printf '%s/recipients.txt' "$(secrets_home)"
  fi
}

# secrets_decrypt <project> <scope> prints the KEY=value lines of a scope. It
# fails when the scope has no file, or when age cannot decrypt it.
secrets_decrypt() {
  local file
  file="$(secrets_scope_file "$1" "$2")"
  [[ -f "$file" ]] || return 1
  age --decrypt --identity "$(secrets_home)/identities.txt" "$file"
}

# secrets_encrypt <project> <scope> replaces the scope with the lines on
# stdin. The file is replaced only after age succeeds.
secrets_encrypt() {
  local file
  file="$(secrets_scope_file "$1" "$2")"
  mkdir -p "$(dirname "$file")" || return 1
  if age --encrypt --recipients-file "$(secrets_recipients "$1")" --output "$file.new"; then
    mv -f "$file.new" "$file"
  else
    rm -f "$file.new"
    return 1
  fi
}

# secrets_lookup <var> <lines> <KEY> sets the variable named var to the value
# of KEY in the KEY=value lines. It fails when no line has the key.
secrets_lookup() {
  local _secrets_line
  while IFS= read -r _secrets_line; do
    if [[ "$_secrets_line" == "$3="* ]]; then
      printf -v "$1" '%s' "${_secrets_line#*=}"
      return 0
    fi
  done < <(printf '%s\n' "$2")
  return 1
}

# stored_secret <var> <project> <scope> <KEY> sets the variable named var to
# one value from the store. It returns 1 when the store does not have it, or
# cannot decrypt it, so that the caller can ask for the value instead.
stored_secret() {
  local _secrets_lines
  command -v age >/dev/null 2>&1 || return 1
  _secrets_lines="$(secrets_decrypt "$2" "$3")" || return 1
  secrets_lookup "$1" "$_secrets_lines" "$4"
}
