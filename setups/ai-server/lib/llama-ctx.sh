#!/usr/bin/env bash
#
# Installed by 20_llama as /usr/local/bin/llama-ctx.
#
# Reports how much of the GPU memory pool a loaded model uses, and how far its
# context can be raised before it stops fitting.
#
# The context length is the one number in this profile that cannot be reasoned
# out from the model file. It decides the size of the KV cache, the cache
# competes with the weights for a single pool, and the cost per token depends on
# the model's attention geometry rather than on its size on disk. `ctx_for` in
# 20_llama therefore picks a coarse default per size band, and this measures
# whether that default is anywhere near right.
#
# It works by difference, because that is the only figure available without
# reading the model's internals. Take a sample, change the context, reload, and
# take another: the change in pool usage divided by the change in context is the
# cost per token. With that, the free space gives the largest context that fits.
#
# Both failure directions are loud but neither names the context:
#
#   too high  The model loads and then exits, on a failed allocation.
#   too low   Requests are refused with "exceeds the available context size".
#
# Source lives in the dotfiles repo at setups/ai-server/lib/llama-ctx.sh.
# ./setup only runs files directly inside a profile directory, so nothing under
# lib/ is ever mistaken for a setup step.

set -eo pipefail

# Kept out of the pool so that a model which just fits does not leave the rest
# of the machine with nothing. The GPU shares this memory with the system.
margin_gib="${LLAMA_CTX_MARGIN_GIB:-4}"

# Samples are per user and survive a reboot, because the second half of a
# measurement usually happens after one.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/llama-ctx"
samples="$state_dir/samples"

usage() {
  cat <<'EOF'
Usage:
  llama-ctx              report the pool, the loaded model, and the headroom
  llama-ctx --sample     the same, and record this reading for comparison
  llama-ctx --reset      forget the recorded readings
  llama-ctx --help

Measuring the cost per token needs two readings of the same model at different
context lengths:

  llama-ctx --sample                     with the current context
  $EDITOR <dotfiles>/setups/ai-server/20_llama     change ctx_for
  ./setup 20_llama                       rebuild and restart
  <send one request>                     the server loads on demand
  llama-ctx --sample                     the second reading

Until then it reports the pool and says what it cannot yet work out.
EOF
}

die() {
  echo "llama-ctx: $1" >&2
  exit 1
}

case "${1:-}" in
--help | -h)
  usage
  exit 0
  ;;
--reset)
  rm -f "$samples"
  echo "Forgot every recorded reading."
  exit 0
  ;;
--sample) ;;
"") ;;
*)
  usage >&2
  exit 1
  ;;
esac

# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------
#
# GTT is the pool that holds model weights and the KV cache. It is a ceiling
# rather than a reservation: the kernel reclaims what the GPU does not use, so
# "used" is what is actually committed right now.
gtt_total=0
gtt_used=0
for d in /sys/class/drm/card*/device; do
  [[ -f "$d/mem_info_gtt_total" ]] || continue
  gtt_total="$(cat "$d/mem_info_gtt_total")"
  gtt_used="$(cat "$d/mem_info_gtt_used")"
  break
done

[[ "$gtt_total" -gt 0 ]] || die "no DRM device exposes mem_info_gtt_total"

gib() { printf '%.1f' "$(awk -v b="$1" 'BEGIN { print b / 1073741824 }')"; }

gtt_free=$((gtt_total - gtt_used))

echo "--- memory ---"
printf '  total  %s GiB\n' "$(gib "$gtt_total")"
printf '  used   %s GiB\n' "$(gib "$gtt_used")"
printf '  free   %s GiB (margin %s GiB held back)\n' "$(gib "$gtt_free")" "$margin_gib"

# ---------------------------------------------------------------------------
# The loaded model
# ---------------------------------------------------------------------------
#
# The address comes from systemd rather than from a default, because 25_network
# moves the listener onto the overlay and loopback stops answering then.
listen="$(systemctl show -p Environment --value llama-swap 2>/dev/null |
  tr ' ' '\n' | sed -n 's/^LLAMA_SWAP_LISTEN=//p' | tail -1)"
listen="${listen:-127.0.0.1:8080}"
host="${listen%:*}"
port="${listen##*:}"
[[ -z "$host" || "$host" == "0.0.0.0" ]] && host="127.0.0.1"

command -v jq >/dev/null 2>&1 || die "jq is missing. Run 10_packages."

if ! running="$(curl -fsS --max-time 5 "http://${host}:${port}/running" 2>/dev/null)"; then
  die "no answer from http://${host}:${port}/running. Is llama-swap running?"
fi

model="$(jq -r '[.running[] | select(.state == "ready")][0].model // ""' <<<"$running")"
cmd="$(jq -r '[.running[] | select(.state == "ready")][0].cmd // ""' <<<"$running")"

if [[ -z "$model" ]]; then
  cat <<EOF

No model is loaded, so there is nothing to measure. The server loads on the
first request that names a model, which takes tens of seconds:

  curl -fsS http://${host}:${port}/v1/chat/completions \\
    -H 'Content-Type: application/json' \\
    -d '{"model":"<id>","messages":[{"role":"user","content":"hi"}],"max_tokens":1}'
EOF
  exit 0
fi

# The context the process actually got, read from its command line rather than
# from the configuration file, so an edit that has not been applied yet cannot
# be mistaken for one that has.
ctx="$(sed -n 's/.*--ctx-size[ =]\([0-9]*\).*/\1/p' <<<"$cmd" | head -1)"

echo
echo "--- model ---"
printf '  %s\n' "$model"
printf '  context %s\n' "${ctx:-unknown}"

[[ -n "$ctx" ]] || die "could not read --ctx-size from the running command"

# ---------------------------------------------------------------------------
# Headroom
# ---------------------------------------------------------------------------
mkdir -p "$state_dir"
touch "$samples"

if [[ "${1:-}" == "--sample" ]]; then
  # One reading per model and context. Re-recording the same pair replaces it,
  # because the later reading is the more accurate one: an idle server has
  # finished whatever it was doing when the first was taken.
  tmp="$(mktemp)"
  awk -v m="$model" -v c="$ctx" '$1 != m || $2 != c' "$samples" >"$tmp" 2>/dev/null || true
  printf '%s %s %s\n' "$model" "$ctx" "$gtt_used" >>"$tmp"
  mv "$tmp" "$samples"
  echo "  recorded"
fi

# The other reading for this model, at the context furthest from the current
# one. A wider gap makes the division less sensitive to whatever else was
# using the pool at the time.
other="$(awk -v m="$model" -v c="$ctx" '
  $1 == m && $2 != c {
    d = ($2 > c) ? $2 - c : c - $2
    if (d > best) { best = d; line = $2 " " $3 }
  }
  END { print line }
' "$samples")"

echo
echo "--- headroom ---"

usable=$((gtt_free - margin_gib * 1073741824))

if [[ -z "$other" ]]; then
  cat <<EOF
  Not enough readings. The cost per token cannot be measured from one context.

  Record this one, change the context, reload, and record the second:

    llama-ctx --sample
    # edit ctx_for in setups/ai-server/20_llama, then:
    ./setup 20_llama
    # send one request so the server loads the model, then:
    llama-ctx --sample

  Free space says only that something can grow into $(gib "$usable") GiB.
EOF
  exit 0
fi

other_ctx="${other%% *}"
other_used="${other##* }"

bytes_per_token="$(awk -v u1="$gtt_used" -v c1="$ctx" -v u2="$other_used" -v c2="$other_ctx" \
  'BEGIN { d = u1 - u2; if (d < 0) d = -d; n = c1 - c2; if (n < 0) n = -n; print (n ? d / n : 0) }')"

if awk -v b="$bytes_per_token" 'BEGIN { exit !(b <= 0) }'; then
  cat <<EOF
  The two readings show no change in memory between context $other_ctx and
  context $ctx, which cannot be right. One of them was probably taken before
  the model finished loading. Take both again with the model "ready".
EOF
  exit 1
fi

extra_tokens="$(awk -v u="$usable" -v b="$bytes_per_token" 'BEGIN { printf "%d", (u > 0 ? u / b : 0) }')"
max_ctx=$((ctx + extra_tokens))

# Rounded down to a power of two, which is what the ladder in 20_llama uses and
# what avoids claiming a precision this method does not have.
pow2=1024
while [[ $((pow2 * 2)) -le "$max_ctx" ]]; do pow2=$((pow2 * 2)); done

printf '  measured against context %s\n' "$other_ctx"
printf '  cost    %s KiB per token of context\n' \
  "$(awk -v b="$bytes_per_token" 'BEGIN { printf "%.1f", b / 1024 }')"
printf '  fits    about %s tokens, so %s with the margin kept back\n' "$max_ctx" "$pow2"

if [[ "$pow2" -le "$ctx" ]]; then
  echo
  echo "  That is at or below the current $ctx. There is no room to raise it."
else
  cat <<EOF

  Raise it in ctx_for, in setups/ai-server/20_llama, then:

    ./setup 20_llama

  Two things this does not know. A shared KV cache is divided between the
  slots llama-server runs, so an agent making parallel calls needs headroom
  above its largest single prompt. And a context above what the model was
  trained on is accepted and degrades quality; llama-server warns when the
  configured context exceeds n_ctx_train.
EOF
fi
