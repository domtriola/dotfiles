#!/usr/bin/env bash
#
# The sync record, and the drift check that sync-env and doctor share.
#
# The sync record holds one line for each file that sync-env copied:
#
#   <sha256> TAB <target> TAB <path in $HOME>
#
# <target> names the manifest line that last wrote the file. Two lines can
# write into one tree (`dir .agents/skills` and `subdirs .agents/skills-local`
# both write into ~/.claude/skills), and each file belongs to the last one.
#
# Drift is a file that the next sync would overwrite or delete, and that
# changed since the last sync. A file is checked only inside the paths that its
# target replaces, so the other files beside a `file` target, and the other
# subdirectories beside a `subdirs` target, are never part of it. A file that
# already matches the source is never drift, because the sync loses nothing.
#
# Bash 3.2 has no associative arrays, so the lookups are done in awk.
#
# Requires $dotfiles_dir to name the checkout.

SYNC_RECORD="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/synced"

# The hash program, in the format of sha256sum. macOS has only shasum.
if command -v sha256sum >/dev/null 2>&1; then
  _SHA256=(sha256sum)
else
  _SHA256=(shasum -a 256)
fi

# _hash_tree prints "<sha256> TAB <relative path>" for each file under <root>.
# A <root> that is a file prints its own hash, with the path ".". A <root> that
# does not exist prints nothing.
_hash_tree() {
  local root="$1"

  if [[ -f "$root" ]]; then
    "${_SHA256[@]}" "$root" | awk '{ print $1 "\t." }'
  elif [[ -d "$root" ]]; then
    (cd "$root" && find . -type f -exec "${_SHA256[@]}" {} +) |
      awk '{ hash = $1; sub(/^[^ ]+ [ *]\.\//, ""); print hash "\t" $0 }'
  fi
}

# target_key names a manifest line in the record. The source is relative to
# the checkout, so a checkout that moves keeps its record.
#
# Usage: target_key <directive> <src> <dest>
target_key() {
  printf '%s %s %s' "$1" "${2#"$dotfiles_dir"/}" "$3"
}

# _target_scopes prints "<path in $HOME> TAB <source>" for each path that a
# target replaces.
_target_scopes() {
  local directive="$1" src="$2" dest="$3" sub

  case "$directive" in
  file) printf '%s\t%s\n' "$dest/$(basename "$src")" "$src" ;;
  dir) printf '%s\t%s\n' "$dest" "$src" ;;
  subdirs)
    while IFS= read -r sub; do
      printf '%s\t%s\n' "$dest/$(basename "$sub")" "$sub"
    done < <(find "$src" -mindepth 1 -maxdepth 1 -type d | sort)
    ;;
  command) printf '%s\t%s\n' "$dest/lib/$(basename "$src")" "$src" ;;
  esac
}

# _join prints <root>/<rel>, or <root> for the path ".".
_join() {
  if [[ "$2" == "." ]]; then
    printf '%s' "$1"
  else
    printf '%s/%s' "$1" "$2"
  fi
}

# target_drift prints one line for each drifted file of a target:
#
#   <kind> TAB <path in $HOME> TAB <source path>
#
# <kind> is "changed", "added" (in a replaced tree, but neither copied there
# nor in the source) or "deleted" (copied there, and now gone). A target with
# no record is compared with the source alone, so a copy that differs from the
# source is drift.
#
# Usage: target_drift <directive> <src> <dest>
target_drift() {
  local key home_root src_root kind rel
  key="$(target_key "$@")"

  while IFS=$'\t' read -r home_root src_root; do
    while IFS=$'\t' read -r kind rel; do
      printf '%s\t%s\t%s\n' "$kind" "$(_join "$home_root" "$rel")" "$(_join "$src_root" "$rel")"
    done < <(_scope_drift "$key" "$home_root" "$src_root")
  done < <(_target_scopes "$@")
}

# _scope_drift prints "<kind> TAB <relative path>" for one replaced path.
_scope_drift() {
  local key="$1" home_root="$2" src_root="$3" record

  record="$SYNC_RECORD"
  [[ -f "$record" ]] || record=/dev/null

  # A file in the record that another target owns is that target's to check.
  awk -F'\t' '
    FILENAME == ARGV[1] { src[$2] = $1; next }
    FILENAME == ARGV[2] { rec[$3] = $1; own[$3] = $2; next }
    { home[$2] = $1 }
    END {
      for (r in home) {
        if ((r in rec) && own[r] != "1") continue
        if ((r in src) && src[r] == home[r]) continue
        if ((r in rec) && rec[r] == home[r]) continue
        print (((r in rec) || (r in src)) ? "changed" : "added") "\t" r
      }
      for (r in rec)
        if (own[r] == "1" && !(r in home) && (r in src)) print "deleted\t" r
    }
  ' <(_hash_tree "$src_root") \
    <(awk -F'\t' -v root="$home_root" -v key="$key" '
        $3 == root { print $1 "\t" ($2 == key) "\t." }
        index($3, root "/") == 1 { print $1 "\t" ($2 == key) "\t" substr($3, length(root) + 2) }
      ' "$record") \
    <(_hash_tree "$home_root") |
    sort -t$'\t' -k2
}

# record_lines prints the record lines for a target as its source stands, which
# is what a copy just wrote.
#
# Usage: record_lines <directive> <src> <dest>
record_lines() {
  local key home_root src_root hash rel
  key="$(target_key "$@")"

  while IFS=$'\t' read -r home_root src_root; do
    while IFS=$'\t' read -r hash rel; do
      printf '%s\t%s\t%s\n' "$hash" "$key" "$(_join "$home_root" "$rel")"
    done < <(_hash_tree "$src_root")
  done < <(_target_scopes "$@")
}

# recorded_lines prints the lines that the record holds for a target now.
#
# Usage: recorded_lines <directive> <src> <dest>
recorded_lines() {
  [[ -f "$SYNC_RECORD" ]] || return 0
  awk -F'\t' -v key="$(target_key "$@")" '$2 == key' "$SYNC_RECORD"
}

# write_record replaces the record with the lines on stdin. When two lines name
# one path, the later one wins, so a file belongs to the last target that
# wrote it. Lines of targets that left the manifest are not passed in, so they
# drop out.
write_record() {
  local tmp
  mkdir -p "$(dirname "$SYNC_RECORD")"
  tmp="$SYNC_RECORD.tmp.$$"
  awk -F'\t' '
    !($3 in line) { order[++n] = $3 }
    { line[$3] = $0 }
    END { for (i = 1; i <= n; i++) print line[order[i]] }
  ' >"$tmp" && mv "$tmp" "$SYNC_RECORD"
}

# tilde prints a path with $HOME shortened to ~.
tilde() {
  case "$1" in
  "$HOME") printf '~' ;;
  "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
  *) printf '%s' "$1" ;;
  esac
}

# show_drift prints the drift lines on stdin as a list, then a diff from the
# copy in $HOME to the source for each changed or added file.
show_drift() {
  local kind home src lines
  lines="$(cat)"

  while IFS=$'\t' read -r kind home src; do
    printf '  %-8s %s\n' "$kind" "$(tilde "$home")"
  done <<<"$lines"

  while IFS=$'\t' read -r kind home src; do
    [[ "$kind" == "deleted" ]] && continue
    [[ -f "$src" ]] || src=/dev/null
    diff -u "$home" "$src" | _color_diff || true
  done <<<"$lines"
}

# _color_diff colors a unified diff when it goes to a terminal, unless
# $NO_COLOR is set. Not every diff has --color, so this works on any of them.
_color_diff() {
  if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
    cat
    return
  fi
  awk '
    /^(---|\+\+\+) / { print "\033[1m" $0 "\033[0m"; next }
    /^@@/ { print "\033[36m" $0 "\033[0m"; next }
    /^-/ { print "\033[31m" $0 "\033[0m"; next }
    /^\+/ { print "\033[32m" $0 "\033[0m"; next }
    { print }
  '
}
