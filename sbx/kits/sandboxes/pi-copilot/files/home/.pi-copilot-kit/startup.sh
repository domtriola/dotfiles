#!/bin/sh
#
# Write ~/.pi/agent/models.json for the Copilot endpoint, and record whether
# the endpoint served this client.
#
# Runs on every sandbox start, so everything here is idempotent.
#
# The engine does not stop a sandbox whose startup hook fails, so
# ~/.pi-copilot-kit.log is the only place a failure can be read afterwards.
# That log is the point of this kit: the status code the probe gets back is
# the answer to the question the README asks.

set -eu

# Defaulted because a startup hook is not guaranteed to inherit
# environment.variables.
base_url="${COPILOT_BASE_URL:-https://${{ kit.args.copilotHost }}}"
integration_id="${COPILOT_INTEGRATION_ID:-${{ kit.args.copilotIntegrationId }}}"
models="${MODEL_IDS:-${{ kit.args.modelIds }}}"

conf="$HOME/.pi/agent"
mkdir -p "$conf"

exec >"$HOME/.pi-copilot-kit.log" 2>&1
echo "--- pi-copilot kit ---"
echo "baseUrl=$base_url"
echo "Copilot-Integration-Id=$integration_id"

# node is not part of the kit tool floor. It comes from the image, which runs
# pi, an npm package.
have_node=0
command -v node >/dev/null 2>&1 && have_node=1

# The probe sends the same headers pi will send, so a refusal here is the same
# refusal a model call would get, read at start rather than mid-session.
#
# The status code is kept rather than folded into a pass or fail, because the
# three failures mean different things and only one of them is fixable here.
body="$(mktemp)"
trap 'rm -f "$body"' EXIT
code="$(
  curl -sS --max-time 15 -o "$body" -w '%{http_code}' \
    -H "Authorization: Bearer ${COPILOT_GITHUB_TOKEN:-}" \
    -H "Copilot-Integration-Id: $integration_id" \
    -H "Editor-Version: pi-copilot-kit/0.1.0" \
    "$base_url/models" 2>/dev/null
)" || code="000"

case "$code" in
  200)
    echo "the endpoint answered 200 and served this client"
    ;;
  401)
    echo "WARNING: 401 from $base_url/models"
    echo "  the token was rejected. Check that the bound secret is a"
    echo "  user-owned fine-grained PAT with the Copilot Requests"
    echo "  permission, and that it has not expired. A classic PAT does"
    echo "  not carry that permission and cannot be made to."
    ;;
  403)
    echo "WARNING: 403 from $base_url/models"
    echo "  the token is valid and the endpoint refused this client. That"
    echo "  is the answer this kit was built to get: the Copilot inference"
    echo "  endpoint is gated to its own editors, and an honestly named"
    echo "  client is not one of them. Do not work around it by copying an"
    echo "  editor's Copilot-Integration-Id. Read README.md."
    ;;
  404)
    echo "WARNING: 404 from $base_url/models"
    echo "  the path moved, or the host is wrong for this plan. Pro and"
    echo "  Pro+ use api.individual.githubcopilot.com; Business and"
    echo "  Enterprise each have their own host. Set copilotHost."
    ;;
  000)
    echo "WARNING: no answer from $base_url"
    echo "  traffic out of a sandbox is denied unless the kit lists the"
    echo "  host, and this kit lists the four Copilot hosts. A host that"
    echo "  is not one of them reads exactly like a routing fault."
    echo "  sbx policy log names the host and the reason."
    ;;
  *)
    echo "WARNING: HTTP $code from $base_url/models"
    ;;
esac

if [ "$code" != "200" ]; then
  echo "the response body, first 400 bytes:"
  head -c 400 "$body" || true
  echo
fi

# Copilot lists embedding models beside chat models, and pi has no use for the
# embedding ones. `capabilities.type` is what separates them; the context
# window lives at capabilities.limits.max_context_window_tokens, which is a
# Copilot-specific shape and not one of the OpenAI-compatible field names.
served=""
entries="[]"
if [ "$code" = "200" ] && [ "$have_node" -eq 1 ]; then
  served="$(MODELS="$models" node -e '
    const fs = require("fs");
    let data = [];
    try {
      data = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).data || [];
    } catch (e) {
      data = [];
    }
    const chat = data.filter((m) => !m.capabilities || m.capabilities.type === "chat");
    process.stdout.write(chat.map((m) => m.id).join(","));
  ' "$body" 2>/dev/null)"
  echo "chat models served: ${served:-none}"
elif [ "$code" = "200" ]; then
  echo "WARNING: no node in this image, so the model list cannot be read."
fi

if [ -n "$models" ]; then
  echo "using the pinned ids: $models"
else
  models="$served"
fi
default_model="${models%%,*}"

# Without contextWindow, pi rations a conversation to its own default of 128000
# tokens whatever the model allows: wasting a model configured higher, and
# overrunning one configured lower as a refused request mid-session.
if [ "$have_node" -eq 1 ]; then
  entries="$(MODELS="$models" node -e '
    const fs = require("fs");
    const wanted = (process.env.MODELS || "").split(",").filter(Boolean);
    let data = [];
    try {
      data = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).data || [];
    } catch (e) {
      data = [];
    }
    const byId = new Map(data.map((m) => [m.id, m]));
    const out = wanted.map((id) => {
      const limits = ((byId.get(id) || {}).capabilities || {}).limits || {};
      const ctx = limits.max_context_window_tokens;
      return ctx ? { id, contextWindow: ctx } : { id };
    });
    process.stdout.write(JSON.stringify(out));
  ' "$body" 2>/dev/null)"
else
  sep=""
  entries=""
  for id in $(printf '%s' "$models" | tr ',' ' '); do
    entries="${entries}${sep}{\"id\":\"${id}\"}"
    sep=","
  done
  entries="[${entries}]"
fi
entries="${entries:-[]}"

if [ "$entries" = "[]" ]; then
  echo "WARNING: no models. The endpoint named none and none were pinned."
  echo "  pi starts with an empty provider. Fix the failure above, or set"
  echo "  modelIds, then restart the sandbox."
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

# apiKey holds the sentinel, not a token. pi interpolates $NAME in models.json
# at request time, sends it as `Authorization: Bearer`, and the sandbox proxy
# replaces the whole header on egress to a Copilot host.
#
# The two headers are what the endpoint reads to decide which client is asking.
# They name this kit, truthfully. Changing them to an editor's values would
# make the request pass as something it is not.
#
# compat turns off two OpenAI-isms that the Copilot endpoint does not
# implement the same way. Both are set from observed behaviour; pi's own docs
# say not to set them because an endpoint claims OpenAI compatibility.
cat >"$conf/models.json" <<EOF
{
  "providers": {
    "copilot": {
      "baseUrl": "$base_url",
      "api": "openai-completions",
      "apiKey": "\$COPILOT_GITHUB_TOKEN",
      "headers": {
        "Copilot-Integration-Id": "$integration_id",
        "Editor-Version": "pi-copilot-kit/0.1.0"
      },
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
  "defaultProvider": "copilot",
  "defaultModel": "$default_model"
}
EOF
  echo "seeded $conf/settings.json with $default_model"
fi

echo "--- pi-copilot kit finished ---"
