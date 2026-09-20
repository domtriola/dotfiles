#!/usr/bin/env bash
#
# Installed by 20_llama as /usr/local/bin/llama-model.
#
# Downloads GGUF models from Hugging Face into the directory llama-swap is
# configured from, and lists or removes what is there.
#
# `hf download` on its own does not produce what this setup needs:
#
#   - It keeps the repository's directory structure, and many GGUF repositories
#     put each quantisation in its own folder. The llama-swap configuration is
#     built from *.gguf at the top level of the models directory, so a file in
#     a subfolder is never found. This flattens them.
#   - Files have to be readable by the llama service account.
#   - A large model arrives as several shards. All of them are needed, and they
#     have to land in the same directory for the loader to find them from the
#     first one.
#
# Source lives in the dotfiles repo at setups/ai-server/lib/llama-model.sh.
# ./setup only runs files directly inside a profile directory, so nothing
# under lib/ is ever mistaken for a setup step.

set -eo pipefail

models_dir="${LLAMA_MODELS_DIR:-/var/lib/llama/models}"
service_user="${LLAMA_SERVICE_USER:-llama}"

usage() {
  cat <<'EOF'
Usage:
  llama-model add <repo> [pattern]   download GGUF files from a Hugging Face repo
  llama-model list                   show installed models
  llama-model rm <name>              remove a model and any shards
  llama-model space                  show free space in the models directory

Examples:
  llama-model add unsloth/Qwen3-30B-A3B-GGUF '*Q4_K_M*'
  llama-model add bartowski/some-model-GGUF

The pattern defaults to '*.gguf', which takes every quantisation in the repo.
That is rarely wanted: name a quantisation unless the repo holds only one.

After a download, run ./setup on this machine to rebuild the llama-swap
configuration. Nothing is served until that happens.
EOF
}

die() {
  printf 'llama-model: %s\n' "$1" >&2
  exit 1
}

# model_names prints one name per model, with the shards of a split model
# collapsed to the name the loader uses.
model_names() {
  find "$models_dir" -maxdepth 1 -type f -name '*.gguf' -printf '%f\n' 2>/dev/null |
    sed -E 's/-[0-9]{5}-of-[0-9]{5}\.gguf$/.gguf/' |
    sed -E 's/\.gguf$//' |
    sort -u
}

cmd_space() {
  df -h "$models_dir" | awk 'NR==1 || NR==2'
}

cmd_list() {
  local name count files size
  count=0

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    count=$((count + 1))
    # A split model is several files. Report the total, not the first shard.
    mapfile -t files < <(find "$models_dir" -maxdepth 1 -type f -name "$name*.gguf")
    size="$(du -ch "${files[@]}" 2>/dev/null | awk '/total/ { print $1 }')"
    printf '  %-48s %6s  %d file(s)\n' "$name" "$size" "${#files[@]}"
  done < <(model_names)

  if [[ $count -eq 0 ]]; then
    echo "  no models in $models_dir"
  fi
}

cmd_rm() {
  local name="$1" files
  [[ -n "$name" ]] || die "rm needs a model name. Run 'llama-model list'."

  mapfile -t files < <(find "$models_dir" -maxdepth 1 -type f -name "$name.gguf" -o \
    -maxdepth 1 -type f -name "$name-[0-9][0-9][0-9][0-9][0-9]-of-*.gguf")

  [[ ${#files[@]} -gt 0 ]] || die "no model named '$name' in $models_dir"

  printf 'Removing %d file(s):\n' "${#files[@]}"
  printf '  %s\n' "${files[@]}"
  read -r -p "Delete them? [y/N] " answer
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || die "cancelled"

  sudo rm -f -- "${files[@]}"
  echo "Removed. Run ./setup to rebuild the llama-swap configuration."
}

cmd_add() {
  local repo="$1" pattern="${2:-*.gguf}" staging moved=0 found

  [[ -n "$repo" ]] || die "add needs a repository, such as unsloth/Qwen3-30B-A3B-GGUF"

  if ! command -v hf >/dev/null 2>&1; then
    cat >&2 <<'EOF'
llama-model: the `hf` command is missing.

Install it without adding Python to this machine:

  curl -LsSf https://hf.co/cli/install.sh | bash -s -- --exclude-skill

--exclude-skill leaves out the agent skill, which a model server has no use
for.
EOF
    exit 1
  fi

  echo "Free space before:"
  cmd_space

  # Staged outside the models directory so that a failed or cancelled download
  # never leaves a partial file where the configuration would pick it up.
  staging="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$staging'" EXIT

  echo
  echo "Downloading $repo, files matching $pattern"
  hf download "$repo" --include "$pattern" --local-dir "$staging"

  # Flattened: the repository layout does not survive, because the
  # configuration only reads the top level of the models directory.
  while IFS= read -r file; do
    found="$(basename "$file")"
    if [[ -e "$models_dir/$found" ]]; then
      echo "  skipping $found, already present"
      continue
    fi
    sudo install -o "$service_user" -g "$service_user" -m 644 "$file" "$models_dir/$found"
    echo "  added $found"
    moved=$((moved + 1))
  done < <(find "$staging" -type f -name '*.gguf' | sort)

  [[ $moved -gt 0 ]] || die "no .gguf files matched '$pattern' in $repo"

  echo
  echo "Added $moved file(s). Installed models:"
  cmd_list
  echo
  echo "Run ./setup on this machine to rebuild the llama-swap configuration."
}

[[ -d "$models_dir" ]] || die "$models_dir does not exist. Run ./setup first."

case "${1:-}" in
add)
  shift
  cmd_add "$@"
  ;;
list)
  cmd_list
  ;;
rm)
  shift
  cmd_rm "$@"
  ;;
space)
  cmd_space
  ;;
"" | -h | --help)
  usage
  ;;
*)
  die "unknown command '$1'. Run 'llama-model --help'."
  ;;
esac
