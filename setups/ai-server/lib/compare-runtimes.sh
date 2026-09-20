#!/usr/bin/env bash
#
# Measures three ways of serving the same weights:
#
#   direct       llama-server on its own, started and stopped by this script
#   llama-swap   llama-server behind the proxy the profile installs
#   ollama       Ollama, importing the same file from disk
#
# It exists because the choice between llama-server and Ollama was made on a
# third-party report that was never reproduced here. See "The runtime choice is
# unverified" in docs/ai-server-decisions.md.
#
# Three and not two, because llama-swap is itself a proxy in front of a
# llama-server subprocess, which is the same shape as the thing Ollama was
# criticised for. Comparing llama-swap against Ollama compares two wrappers and
# says nothing about the engine. The direct run is the control: if it matches
# Ollama while llama-swap is slower, the overhead is ours.
#
# Usage:
#   bash compare-runtimes.sh <model-name> [requests]
#   bash compare-runtimes.sh --cleanup <model-name>
#
#   <model-name>  as llama-swap reports it, from `llama-model list`
#   [requests]    timed requests per runtime, default 5
#
# Two things the first version of this script got wrong, both of which made the
# prefill column meaningless:
#
#   - The prompt was 26 tokens. At that size the number is dominated by fixed
#     per-request cost, and it swung by a factor of three between samples.
#     PROMPT_WORDS below makes it long enough to measure throughput.
#   - Every request sent the same prompt, so a runtime that caches prompts
#     reported a near-zero prefill duration and an enormous rate. Each request
#     now carries a unique prefix, so nothing can be served from cache.

set -eo pipefail

models_dir="${LLAMA_MODELS_DIR:-/var/lib/llama/models}"
swap_url="${LLAMA_SWAP_URL:-http://127.0.0.1:8080}"
ollama_url="${OLLAMA_URL:-http://127.0.0.1:11434}"
llama_bin="${LLAMA_BIN:-/opt/llama.cpp/current/llama-server}"
direct_port="${DIRECT_PORT:-10098}"

# Long enough that prefill measures throughput rather than overhead. Roughly
# one token per word, so this is on the order of two thousand tokens.
prompt_words="${PROMPT_WORDS:-1800}"
max_tokens="${MAX_TOKENS:-120}"

die() {
  printf 'compare-runtimes: %s\n' "$1" >&2
  exit 1
}

if [[ "${1:-}" == "--cleanup" ]]; then
  [[ -n "${2:-}" ]] || die "--cleanup needs the model name"
  ollama rm "compare-$2" 2>/dev/null || true
  echo "Removed the imported Ollama entry for $2."
  exit 0
fi

model="${1:-}"
runs="${2:-5}"
[[ -n "$model" ]] || die "needs a model name. Run: llama-model list"

command -v ollama >/dev/null 2>&1 || die "ollama is not installed. Install it with:
  curl -fsSL https://ollama.com/install.sh | sh
It listens on 11434 and does not conflict with llama-swap on 8080."

[[ -x "$llama_bin" ]] || die "$llama_bin is not executable"

curl -fsS --max-time 5 "$swap_url/v1/models" >/dev/null 2>&1 ||
  die "llama-swap is not answering on $swap_url"

gguf="$(find "$models_dir" -maxdepth 1 -type f \
  \( -name "$model.gguf" -o -name "$model-00001-of-*.gguf" \) | head -1)"
[[ -n "$gguf" ]] || die "no GGUF in $models_dir for '$model'"

if [[ "$gguf" == *-00001-of-* ]]; then
  from_path="${gguf%-00001-of-*}-*-of-*.gguf"
else
  from_path="$gguf"
fi

ollama_model="compare-$model"

# The settings llama-swap was configured with, so the direct run is the same
# engine configured the same way and only the proxy differs.
ctx="$(sed -n "/\"$model\"/,/^  \"/p" /etc/llama-swap/config.yaml 2>/dev/null |
  sed -n 's/.*--ctx-size \([0-9]*\).*/\1/p' | head -1)"
ctx="${ctx:-16384}"

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
#
# A unique prefix per request defeats prompt caching in every runtime, so all
# three are measured doing the same work rather than one of them replaying an
# answer it already had.
make_prompt() {
  local tag="$1"
  python3 -c '
import sys, random
tag = sys.argv[1]
words = int(sys.argv[2])
random.seed(tag)
vocab = ["alpha","beta","gamma","delta","epsilon","zeta","eta","theta",
         "iota","kappa","lambda","mu","nu","xi","omicron","pi"]
body = " ".join(random.choice(vocab) for _ in range(words))
print("Context id " + tag + ". Ignore this filler: " + body +
      " End of filler. Now answer in one short sentence: what is 2 plus 2?")
' "$tag" "$prompt_words"
}

json_body_openai() {
  python3 -c '
import json, sys
model, prompt, n, effort = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
body = {"model": model, "messages": [{"role": "user", "content": prompt}],
        "max_tokens": n, "stream": False}
if effort:
    body["reasoning_effort"] = effort
print(json.dumps(body))
' "$1" "$2" "$3" "${4:-}"
}

json_body_ollama() {
  python3 -c '
import json, sys
model, prompt, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
print(json.dumps({"model": model, "stream": False,
                  "messages": [{"role": "user", "content": prompt}],
                  "options": {"num_predict": n}}))
' "$1" "$2" "$3"
}

# ---------------------------------------------------------------------------
# One timed request against each kind of endpoint. Both print
# "<prefill> <decode> <tokens>".
# ---------------------------------------------------------------------------
parse_llamacpp='
import json, sys
t = json.load(sys.stdin)["timings"]
pp = t["prompt_per_second"]
tg = t["predicted_per_second"]
n = t["predicted_n"]
print(f"{pp:.2f} {tg:.2f} {n}")
'

parse_ollama='
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

req_openai() {
  local url="$1" name="$2" prompt="$3" effort="${4:-}"
  curl -fsS --max-time 900 "$url/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$(json_body_openai "$name" "$prompt" "$max_tokens" "$effort")" |
    python3 -c "$parse_llamacpp"
}

req_ollama() {
  local prompt="$1"
  curl -fsS --max-time 900 "$ollama_url/api/chat" \
    -H 'Content-Type: application/json' \
    -d "$(json_body_ollama "$ollama_model" "$prompt" "$max_tokens")" |
    python3 -c "$parse_ollama"
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
print(f"    prefill {pp[mid]:8.1f} tok/s    decode {tg[mid]:6.2f} tok/s    (median of {len(rows)})")
'
}

# ---------------------------------------------------------------------------
# Import into Ollama, from the file already on disk.
# ---------------------------------------------------------------------------
if ollama list 2>/dev/null | grep -q "^${ollama_model}[: ]"; then
  echo "Ollama already has $ollama_model"
else
  echo "Importing $gguf into Ollama (copied from disk, not downloaded)"
  modelfile="$(mktemp)"
  printf 'FROM %s\n' "$from_path" >"$modelfile"
  ollama create "$ollama_model" -f "$modelfile" || die "ollama create failed"
  rm -f "$modelfile"
fi

echo
echo "Model:    $model"
echo "Prompt:   about $prompt_words words, unique per request"
echo "Requests: $runs per runtime, after one warm-up that is discarded"
echo "Context:  $ctx for both llama-server runs"
echo

# ---------------------------------------------------------------------------
# 1. llama-server on its own. This is the control.
# ---------------------------------------------------------------------------
echo "direct (llama-server, no proxy):"

direct_pid=""
cleanup_direct() {
  [[ -n "$direct_pid" ]] && kill "$direct_pid" 2>/dev/null || true
}
trap cleanup_direct EXIT

"$llama_bin" --model "$gguf" -ngl all --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 --ctx-size "$ctx" \
  --host 127.0.0.1 --port "$direct_port" >/tmp/compare-direct.log 2>&1 &
direct_pid=$!

# Loading a large model takes minutes, so this waits rather than assuming.
for _ in $(seq 180); do
  curl -fsS --max-time 2 "http://127.0.0.1:$direct_port/health" >/dev/null 2>&1 && break
  kill -0 "$direct_pid" 2>/dev/null || die "llama-server exited. See /tmp/compare-direct.log"
  sleep 2
done

req_openai "http://127.0.0.1:$direct_port" "$model" "$(make_prompt warm)" none >/dev/null 2>&1 || true
for i in $(seq "$runs"); do
  req_openai "http://127.0.0.1:$direct_port" "$model" "$(make_prompt "d$i")" none
done | summarise

cleanup_direct
direct_pid=""
trap - EXIT

# ---------------------------------------------------------------------------
# 2. Through llama-swap.
# ---------------------------------------------------------------------------
echo "llama-swap (llama-server behind the proxy):"
req_openai "$swap_url" "$model" "$(make_prompt warm)" none >/dev/null 2>&1 || true
for i in $(seq "$runs"); do
  req_openai "$swap_url" "$model" "$(make_prompt "s$i")" none
done | summarise

# ---------------------------------------------------------------------------
# 3. Ollama.
# ---------------------------------------------------------------------------
echo "ollama:"
req_ollama "$(make_prompt warm)" >/dev/null 2>&1 || true
for i in $(seq "$runs"); do
  req_ollama "$(make_prompt "o$i")"
done | summarise

cat <<EOF

Reading it:
  direct and ollama close, llama-swap behind   the proxy costs what it costs
  direct ahead of ollama                       the engine is genuinely faster
  all three close                              the runtime choice does not matter

Still not controlled:
  - Ollama chooses its own context and KV cache type. The two llama-server runs
    use $ctx with an 8 bit cache.
  - Ollama has no reasoning_effort switch on this endpoint, so a reasoning
    model may spend its token budget differently there.

Remove the imported entry with:
  bash compare-runtimes.sh --cleanup $model
EOF
