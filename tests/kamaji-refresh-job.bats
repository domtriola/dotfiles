#!/usr/bin/env bats
#
# The launchd job that refreshes the kamaji snapshot on dev-mac. launchd runs
# it with no terminal and a minimal PATH, so these tests run its program the
# same way, with a fake nvm and a fake kamaji wrapper.

load helpers

plist="$repo_root/env/Library/LaunchAgents/com.domtriola.kamaji-refresh.plist"

setup() {
  common_setup
  mkdir -p "$HOME/.nvm" "$HOME/.local/bin"
  # nvm puts the node it selects first on PATH, as the real one does.
  cat >"$HOME/.nvm/nvm.sh" <<'NVM'
nvm() { echo "nvm $*" >>"$FAKE_STATE/nvm.log"; PATH="$HOME/.nvm/versions/node/v24/bin:$PATH"; }
NVM
  cat >"$HOME/.local/bin/kamaji" <<'KAMAJI'
#!/bin/sh
echo "$* $PATH" >>"$FAKE_STATE/kamaji.log"
echo "refreshed"
exit "${KAMAJI_EXIT:-0}"
KAMAJI
  chmod +x "$HOME/.local/bin/kamaji"
}

# value prints a top-level key of the plist as JSON.
value() {
  python3 -I -c 'import json, plistlib, sys; print(json.dumps(plistlib.load(open(sys.argv[1], "rb"))[sys.argv[2]]))' "$plist" "$1"
}

# run_job runs the job's program with the environment that launchd gives it.
run_job() {
  local -a args
  mapfile -d '' -t args < <(python3 -I -c 'import plistlib, sys; sys.stdout.write("".join(a + "\0" for a in plistlib.load(open(sys.argv[1], "rb"))["ProgramArguments"]))' "$plist")
  run env -i HOME="$HOME" FAKE_STATE="$FAKE_STATE" KAMAJI_EXIT="${KAMAJI_EXIT:-0}" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin "${args[@]}" </dev/null
}

@test "the job runs at load and every 15 minutes" {
  [ "$(value Label)" = '"com.domtriola.kamaji-refresh"' ]
  [ "$(value RunAtLoad)" = "true" ]
  [ "$(value StartInterval)" = "900" ]
}

@test "the job runs kamaji refresh through the wrapper, with Node 24 from nvm first on PATH" {
  run_job
  [ "$status" -eq 0 ]
  [[ "$(cat "$FAKE_STATE/nvm.log")" == *"use"*"24"* ]]
  log="$(cat "$FAKE_STATE/kamaji.log")"
  [[ "$log" == "refresh $HOME/.nvm/versions/node/v24/bin:"* ]]
  [[ "$log" == *":$HOME/.local/bin:"* ]]
}

@test "the job appends its output to a log" {
  run_job
  run_job
  [ "$(grep -c refreshed "$HOME/Library/Logs/kamaji-refresh.log")" -eq 2 ]
}

@test "the job exits with the status of kamaji refresh, so launchctl print shows a failure" {
  KAMAJI_EXIT=3 run_job
  [ "$status" -eq 3 ]
}
