#!/usr/bin/env bash
#
# Reads and checks a profile's manifest. sync-env copies what it lists, and
# doctor checks it for drift. The directives are described in sync-env.
#
# Requires $dotfiles_dir to name the checkout.

# read_manifest reads <manifest> into two globals:
#
#   actions         one "<directive>|<absolute src>|<absolute dest>" for each
#                   line, in order. A group carries its label in the src field.
#   copies_nothing  "1" when the manifest has the `none` directive.
#
# The whole manifest is checked before anything is returned, so a mistake in it
# stops the caller rather than leaving $HOME half synced. On a mistake it
# prints the reason and returns 1.
#
# Usage: read_manifest <manifest>
read_manifest() {
  local manifest="$1" lineno=0 line where directive rest src dest extra
  local src_root src_label env_dir="$dotfiles_dir/env" commands_dir="$dotfiles_dir/commands"

  actions=()

  # Set by the `none` directive. A profile that copies nothing is legitimate,
  # but so is a manifest whose every line was commented out by mistake, and the
  # two look the same. `none` tells them apart.
  copies_nothing="0"

  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    where="$manifest:$lineno"

    # Blank lines and whole-line comments.
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue

    read -r directive rest <<<"$line"

    if [[ "$directive" == "group" ]]; then
      [[ -n "$rest" ]] || { _manifest_error "$where: group needs a label"; return 1; }
      actions+=("group|$rest|")
      continue
    fi

    if [[ "$directive" == "none" ]]; then
      [[ -z "$rest" ]] || { _manifest_error "$where: none takes no arguments"; return 1; }
      copies_nothing="1"
      continue
    fi

    read -r src dest extra <<<"$rest"

    # A command is read from ./commands/ rather than ./env/, so the directive
    # decides which tree its source is relative to.
    case "$directive" in
    file | dir | subdirs)
      src_root="$env_dir"
      src_label="env/"
      ;;
    command)
      src_root="$commands_dir"
      src_label="commands/"
      ;;
    *)
      _manifest_error "$where: unknown directive '$directive'"
      return 1
      ;;
    esac

    if [[ -z "$src" || -z "$dest" ]]; then
      _manifest_error "$where: $directive needs a source and a destination"
      return 1
    fi
    [[ -z "$extra" ]] || { _manifest_error "$where: too many fields ('$extra')"; return 1; }
    if [[ "$src" == /* ]]; then
      _manifest_error "$where: source '$src' must be relative to $src_label"
      return 1
    fi
    if [[ "/$src/" == */../* ]]; then
      _manifest_error "$where: source '$src' must not leave $src_label"
      return 1
    fi

    dest="${dest//\$HOME/$HOME}"
    if [[ "$dest" == *'$'* ]]; then
      _manifest_error "$where: destination '$dest' has an unknown variable"
      return 1
    fi
    if [[ "$dest" != "$HOME" && "$dest" != "$HOME"/* ]]; then
      _manifest_error "$where: destination '$dest' is outside \$HOME"
      return 1
    fi

    src="$src_root/$src"

    case "$directive" in
    file)
      [[ -f "$src" ]] || { _manifest_error "$where: '$src' is not a file"; return 1; }
      ;;
    dir | subdirs)
      [[ -d "$src" ]] || { _manifest_error "$where: '$src' is not a directory"; return 1; }
      # dir and subdirs both remove a path before copying, so neither may
      # target $HOME itself.
      if [[ "$dest" == "$HOME" ]]; then
        _manifest_error "$where: $directive cannot target \$HOME itself"
        return 1
      fi
      ;;
    command)
      [[ -d "$src" ]] || { _manifest_error "$where: '$src' is not a directory"; return 1; }
      # The entry point carries the command's name, because that is the name
      # the symlink on PATH gets.
      if [[ ! -x "$src/$(basename "$src")" ]]; then
        _manifest_error "$where: '$src' holds no executable $(basename "$src")"
        return 1
      fi
      ;;
    esac

    actions+=("$directive|$src|$dest")
  done <"$manifest"
}

_manifest_error() {
  printf '%s: %s\n' "$(basename "$0")" "$1" >&2
}
