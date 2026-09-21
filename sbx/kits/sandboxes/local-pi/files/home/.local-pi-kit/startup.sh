#!/bin/sh
#
# Write ~/.pi/agent/models.json for the model server, and check that it answers.
#
# Runs on every sandbox start, so everything here is idempotent.
#
# The engine does not stop a sandbox whose startup hook fails, so
# ~/.local-pi-kit.log is the only place a failure can be read afterwards.

set -eu

# Defaulted because a startup hook is not guaranteed to inherit
# environment.variables.
base_url="${MODEL_BASE_URL:-http://${{ kit.args.modelHost }}:${{ kit.args.modelPort }}/v1}"
models="${MODEL_IDS:-${{ kit.args.modelIds }}}"

conf="$HOME/.pi/agent"
mkdir -p "$conf"

exec >"$HOME/.local-pi-kit.log" 2>&1
echo "--- local-pi kit ---"
echo "baseUrl=$base_url"

# node is not part of the kit tool floor. It comes from the image, which runs
# pi, an npm package.
have_node=0
command -v node >/dev/null 2>&1 && have_node=1

# One request, two jobs: it proves the path, and it supplies the model ids when
# the caller pinned none. It does not prove the models: a server lists what it
# is configured to serve whether or not any of it can load.
served=""
curl_out=""
if curl_out="$(curl -fsS --max-time 10 "$base_url/models" 2>/dev/null)"; then
  if [ "$have_node" -eq 1 ]; then
    served="$(printf '%s' "$curl_out" | node -e '
      let raw = "";
      process.stdin.on("data", (d) => (raw += d)).on("end", () => {
        let data;
        try {
          data = JSON.parse(raw).data || [];
        } catch (e) {
          process.exit(1);
        }
        process.stdout.write(data.map((m) => m.id).join(","));
      });
    ')"
  else
    served="$(printf '%s' "$curl_out" |
      tr ',' '\n' |
      sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
      tr '\n' ',' | sed 's/,$//')"
  fi
  echo "the server answered, and serves: ${served:-nothing}"
else
  echo "WARNING: no answer from $base_url"
  echo "  - is the host reachable from this sandbox? a private network"
  echo "    has to be up on this machine as well as on the server"
  echo "  - is it allowed? traffic out of a sandbox is denied unless"
  echo "    the kit lists it, and this kit lists the modelHost it was"
  echo "    given, so a mismatch reads exactly like a routing fault"
  echo "  - is the server running and listening on that address?"
fi

if [ -n "$models" ]; then
  echo "using the pinned ids: $models"
else
  models="$served"
fi
default_model="${models%%,*}"

# Without contextWindow, pi rations a conversation to its own default of 128000
# tokens whatever the server serves: wasting a model configured higher, and
# overrunning one configured lower as a refused request mid-session.
#
# An id can be read out of the JSON with sed; a number attached to the right id
# cannot, not reliably.
if [ "$have_node" -eq 1 ]; then
  entries="$(printf '%s' "$curl_out" | MODELS="$models" node -e '
    let raw = "";
    process.stdin.on("data", (d) => (raw += d)).on("end", () => {
      const wanted = (process.env.MODELS || "").split(",").filter(Boolean);
      let served = [];
      try {
        served = JSON.parse(raw).data || [];
      } catch (e) {
        served = [];
      }
      const byId = new Map(served.map((m) => [m.id, m]));
      const ids = wanted.length ? wanted : served.map((m) => m.id);
      const out = ids.map((id) => {
        const m = byId.get(id) || {};
        const ctx = m.context_length || m.context_window || (m.meta || {}).n_ctx;
        return ctx ? { id, contextWindow: ctx } : { id };
      });
      process.stdout.write(JSON.stringify(out));
    });
  ' 2>/dev/null)"
else
  echo "WARNING: no node in this image, so no context window can be read."
  echo "  pi rations every model to its own default of 128000 tokens."
  entries=""
  sep=""
  for id in $(printf '%s' "$models" | tr ',' ' '); do
    entries="${entries}${sep}{\"id\":\"${id}\"}"
    sep=","
  done
  entries="[${entries}]"
fi
entries="${entries:-[]}"

if [ "$entries" = "[]" ]; then
  echo "WARNING: no models. The server named none and none were pinned."
  echo "  pi starts with an empty provider. Set modelIds, or fix the"
  echo "  server, then restart the sandbox."
elif [ "$have_node" -eq 1 ]; then
  printf '%s' "$entries" | node -e '
    let raw = "";
    process.stdin.on("data", (d) => (raw += d)).on("end", () => {
      for (const m of JSON.parse(raw)) {
        console.log("  " + m.id + ": context " + (m.contextWindow || "pi default"));
      }
    });
  ' 2>/dev/null || true
fi

# apiKey is sent and ignored by a server that has no authentication. pi wants
# the field set for an openai-completions provider.
#
# compat turns off two OpenAI-isms that not every server implements.
# reasoning_effort is the one to turn on first where it is supported.
cat >"$conf/models.json" <<EOF
{
  "providers": {
    "local": {
      "baseUrl": "$base_url",
      "api": "openai-completions",
      "apiKey": "unused",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": $entries
    }
  }
}
EOF
echo "wrote $conf/models.json"

# Seeded once and then left alone: pi writes this file itself when `/model`
# saves a choice, and overwriting it every start would throw that away.
if [ -f "$conf/settings.json" ]; then
  echo "kept the existing $conf/settings.json"
elif [ -z "$default_model" ]; then
  echo "no default model to seed $conf/settings.json with"
else
  cat >"$conf/settings.json" <<EOF
{
  "defaultProvider": "local",
  "defaultModel": "$default_model"
}
EOF
  echo "seeded $conf/settings.json with $default_model"
  echo "  the first request loads it, which can take tens of seconds"
fi

echo "--- local-pi kit finished ---"
