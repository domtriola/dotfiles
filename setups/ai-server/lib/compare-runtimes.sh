#!/usr/bin/env bash
#
# Measures llama-server, behind llama-swap, against Ollama, on the same weights.
#
# This exists because the choice between them was made on a third-party report
# that was never reproduced here. See "The runtime choice is unverified" in
# docs/ai-server-decisions.md.
#
# Usage:
#   bash compare-runtimes.sh <model-name> [requests]
#
#   <model-name>  as llama-swap reports it, from `llama-model list`
#   [requests]    how many timed requests per runtime, default 5
#
# Nothing is installed and nothing is changed except an Ollama model entry,
# which `--cleanup` removes again. Ollama imports the existing GGUF from disk
# rather than downloading it a second time.
#
# Pick a small model. The claim is about per-request overhead, which is a larger
# share of a short request, so a small model shows it more clearly and costs far
# less disk to import.

set -eo pipefail

models_dir="${LLAMA_MODELS_DIR:-/var/lib/llama/models}"
swap_url="${LLAMA_SWAP_URL:-http://127.0.0.1:8080}"
ollama_url="${OLLAMA_URL:-http://127.0.0.1:11434}"
prompt="Write a bash function that retries a command up to 3 times."
max_tokens=200

die() {
  printf 'compare-runtimes: %s\n' "$1" >&2
  exit 1
}

model="${1:-}"
runs="${2:-5}"

if [[ "$model" == "--cleanup" ]]; then
  ollama rm "compare-${2:-}" 2>/dev/null || true
  echo "Removed the imported Ollama entry."
  exit 0
fi

[[ -n "$model" ]] || die "needs a model name. Run: llama-model list"

# ---------------------------------------------------------------------------
# Both runtimes have to be present. Ollama is not installed by the profile.
# ---------------------------------------------------------------------------
command -v ollama >/dev/null 2>&1 || die "ollama is not installed. Install it with:
  curl -fsSL https://ollama.com/install.sh | sh
It listens on 11434 and does not conflict with llama-swap on 8080."

curl -fsS --max-time 5 "$swap_url/v1/models" >/dev/null 2>&1 ||
  die "llama-swap is not answering on $swap_url"

# The first shard is the entry point for a split model, and the whole set has
# to be matched so Ollama imports every part.
gguf="$(find "$models_dir" -maxdepth 1 -type f \
  \( -name "$model.gguf" -o -name "$model-00001-of-*.gguf" \) | head -1)"
[[ -n "$gguf" ]] || die "no GGUF in $models_dir for '$model'"

if [[ "$gguf" == *-00001-of-* ]]; then
  from_path="${gguf%-00001-of-*}-*-of-*.gguf"
else
  from_path="$gguf"
fi

ollama_model="compare-$model"

# ---------------------------------------------------------------------------
# Import, without downloading anything.
# ---------------------------------------------------------------------------
if ollama list 2>/dev/null | grep -q "^${ollama_model}[: ]"; then
  echo "Ollama already has $ollama_model"
else
  echo "Importing $gguf into Ollama (copied, not downloaded)"
  modelfile="$(mktemp)"
  printf 'FROM %s\n' "$from_path" >"$modelfile"
  ollama create "$ollama_model" -f "$modelfile" || die "ollama create failed"
  rm -f "$modelfile"
fi

# ---------------------------------------------------------------------------
# Measure
# ---------------------------------------------------------------------------
#
# Both are asked the same question, with the same token limit. One warm-up
# request each is discarded, because the first one loads the weights and would
# otherwise swamp the result.
#
# The two report timings differently: llama.cpp gives rates directly, Ollama
# gives counts and nanosecond durations. Both are reduced to tokens per second.

warm_swap() {
  curl -fsS --max-time 600 "$swap_url/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"model":"%s","reasoning_effort":"none","messages":[{"role":"user","content":"hi"}],"max_tokens":4}' "$model")" \
    >/dev/null 2>&1 || true
}

warm_ollama() {
  curl -fsS --max-time 600 "$ollama_url/api/chat" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"model":"%s","stream":false,"messages":[{"role":"user","content":"hi"}],"options":{"num_predict":4}}' "$ollama_model")" \
    >/dev/null 2>&1 || true
}

run_swap() {
  curl -fsS --max-time 600 "$swap_url/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"model":"%s","reasoning_effort":"none","messages":[{"role":"user","content":"%s"}],"max_tokens":%d}' \
      "$model" "$prompt" "$max_tokens")" |
    python3 -c '
import json, sys
t = json.load(sys.stdin)["timings"]
pp = t["prompt_per_second"]
tg = t["predicted_per_second"]
n = t["predicted_n"]
print(f"{pp:.2f} {tg:.2f} {n}")
' 
}

run_ollama() {
  curl -fsS --max-time 600 "$ollama_url/api/chat" \
    -H 'Content-Type: application/json' \
    -d "$(printf '{"model":"%s","stream":false,"messages":[{"role":"user","content":"%s"}],"options":{"num_predict":%d}}' \
      "$ollama_model" "$prompt" "$max_tokens")" |
    python3 -c '
import json, sys
d = json.load(sys.stdin)
pe = d.get("prompt_eval_count", 0)
ped = d.get("prompt_eval_duration", 0) or 1
ec = d.get("eval_count", 0)
ed = d.get("eval_duration", 0) or 1
pp = pe / (ped / 1e9)
tg = ec / (ed / 1e9)
print(f"{pp:.2f} {tg:.2f} {ec}")
' 
}

summarise() {
  python3 -c '
import sys
rows = [l.split() for l in sys.stdin if l.strip()]
if not rows:
    print("    no results"); raise SystemExit
pp = sorted(float(r[0]) for r in rows)
tg = sorted(float(r[1]) for r in rows)
mid = len(pp) // 2
print(f"    prefill {pp[mid]:7.1f} tok/s   decode {tg[mid]:6.2f} tok/s   (median of {len(rows)})")
'
}

echo
echo "Model:    $model"
echo "Requests: $runs each, plus one warm-up discarded"
echo

echo "llama-swap:"
warm_swap
for _ in $(seq "$runs"); do run_swap; done | summarise

echo "ollama:"
warm_ollama
for _ in $(seq "$runs"); do run_ollama; done | summarise

cat <<EOF

What this does not control:
  - Context. llama-swap uses what 20_llama configured; Ollama defaults to its
    own. A different KV allocation is part of what is being compared, but it is
    not a like-for-like setting.
  - Quantised KV cache. The llama-swap side runs q8_0 for K and V; Ollama uses
    its own default.
  - Thinking. The llama-swap side sets reasoning_effort none. Ollama has no
    equivalent switch on this endpoint, so a reasoning model may spend tokens
    differently between the two.

Remove the imported entry with:
  bash compare-runtimes.sh --cleanup $model
EOF
