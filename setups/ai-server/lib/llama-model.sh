#!/usr/bin/env bash
#
# Installed by 20_llama as /usr/local/bin/llama-model.
#
# Downloads GGUF models from Hugging Face into the directory llama-swap is
# configured from, and lists or removes what is there.
#
# Nothing else is needed to use it. The Hugging Face CLI is deliberately not a
# dependency: its public API lists a repository's files with their sizes, and
# every file has a stable download URL, so curl and the json module of the
# system python do the whole job. A model server has no other use for a Python
# package ecosystem, and a fresh machine can fetch a model as soon as this
# profile has run.
#
# The work that is left is what a plain download would not do:
#
#   - Repository layout is flattened. Many GGUF repositories put each
#     quantisation in its own folder, and the llama-swap configuration is built
#     from *.gguf at the top level of the models directory only.
#   - Files are given to the llama service account to read.
#   - Free space is checked against the real total before anything starts,
#     rather than filling the disk part way through.
#   - A large model arrives as several shards. All are needed, in one
#     directory, because the loader finds the rest from the first.
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
  llama-model add unsloth/Qwen3.8-27B-GGUF '*UD-Q4_K_XL*'
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
  local repo="$1" pattern="${2:-*.gguf}" staging listing total_gb avail_gb moved=0

  [[ -n "$repo" ]] || die "add needs a repository, such as unsloth/Qwen3.8-27B-GGUF"

  # No Hugging Face CLI is needed. The public API lists a repository's files
  # with their sizes, and every file has a stable download URL, so curl and the
  # json module of the system python are enough. That keeps the machine free of
  # a package ecosystem it otherwise has no use for, and means a fresh install
  # can fetch a model with nothing installed beyond this profile.
  echo "Listing $repo, files matching $pattern"

  listing="$(curl -fsSL --max-time 60 "https://huggingface.co/api/models/${repo}?blobs=true" 2>/dev/null |
    python3 -c '
import json, sys, fnmatch
pat = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for f in d.get("siblings", []):
    n = f["rfilename"]
    if n.endswith(".gguf") and fnmatch.fnmatch(n, pat):
        print(str(f.get("size") or 0) + "\t" + n)
' "$pattern")" || die "could not read $repo. Check the name, and that it is public."

  [[ -n "$listing" ]] || die "no .gguf file in $repo matches '$pattern'"

  # The size is known before anything is downloaded, so the disk is checked
  # first rather than filling up part way through a hundred gigabytes.
  # Rounded up, because a space check that under-reports what it needs is
  # worse than one that refuses a download which would just have fitted.
  total_gb="$(awk -F'\t' '{s+=$1} END {printf "%d", int(s/1000000000)+1}' <<<"$listing")"
  avail_gb="$(df -BG --output=avail "$models_dir" | tail -1 | tr -dc '0-9')"

  printf '\n%-58s %s\n' "FILE" "SIZE"
  awk -F'\t' '{printf "%-58s %6.1f GB\n", $2, $1/1000000000}' <<<"$listing"
  printf '\n  total %s GB, free %s GB\n\n' "$total_gb" "$avail_gb"

  if [[ "$total_gb" -ge "$avail_gb" ]]; then
    die "not enough space: needs ${total_gb} GB, ${avail_gb} GB free in $models_dir"
  fi

  # Staged outside the models directory so a cancelled download never leaves a
  # partial file where the configuration would pick it up. Resume works within
  # a run and across reruns of the same staging path is not attempted, because
  # a partial file of unknown provenance is worse than starting again.
  staging="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$staging'" EXIT

  while IFS=$'\t' read -r size path; do
    local name="${path##*/}"

    if [[ -e "$models_dir/$name" ]]; then
      echo "  have $name already"
      continue
    fi

    echo "  fetching $name"
    # -C - resumes a partial file, and the redirect to the CDN is followed.
    curl -fL -C - --retry 5 --retry-delay 5 \
      -o "$staging/$name" \
      "https://huggingface.co/${repo}/resolve/main/${path}" ||
      die "download of $name failed. Rerun to resume."

    sudo install -o "$service_user" -g "$service_user" -m 644 \
      "$staging/$name" "$models_dir/$name"
    rm -f "$staging/$name"
    moved=$((moved + 1))
  done <<<"$listing"

  if [[ $moved -eq 0 ]]; then
    echo "Nothing new to add."
  else
    echo
    echo "Added $moved file(s)."
  fi

  echo
  cmd_list
  echo
  echo "Run ./setup on this machine to rebuild the llama-swap configuration."
}

# `test -d` fails identically for a directory that is absent and one whose
# parent cannot be traversed, and reporting "does not exist" for the second
# sends the reader to the wrong problem. Walking up to the deepest ancestor
# that can be seen tells them apart, and needs no root to do it.
if [[ ! -d "$models_dir" ]]; then
  probe="$models_dir"
  while [[ ! -e "$probe" && "$probe" != "/" ]]; do
    probe="$(dirname "$probe")"
  done

  if [[ ! -x "$probe" ]]; then
    cat >&2 <<EOF
llama-model: $models_dir cannot be reached by $USER.

$probe is not traversable:

$(ls -ld "$probe" 2>/dev/null)

Running ./setup on this machine sets the modes it expects. To open it now:

  sudo chmod 755 $probe
EOF
    exit 1
  fi

  die "$models_dir does not exist. Run ./setup on this machine first."
fi

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
