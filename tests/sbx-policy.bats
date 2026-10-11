#!/usr/bin/env bats
#
# sbx-policy, through its command line.

load helpers

setup() {
  common_setup
  sbx_policy="$repo_root/commands/sbx-policy/sbx-policy"
  export FAKE_SBX_APPROVALS="network:aaa app api.example.com:443
network:bbb other cdn.example.com:443
network:ccc app registry.npmjs.org:443"
}

@test "pending lists the approvals that wait for one sandbox" {
  run "$sbx_policy" pending app
  [ "$status" -eq 0 ]
  [[ "$output" == *"api.example.com:443"* ]]
  [[ "$output" == *"registry.npmjs.org:443"* ]]
  [[ "$output" != *"cdn.example.com"* ]]
  [[ "$output" == *"2 pending"* ]]
}

# responses prints the approvals that were answered, as "<id> <option>".
responses() {
  sed -n 's/^policy approval respond \(.*\) --option \(.*\)$/\1 \2/p' "$FAKE_STATE/sbx.log"
}

@test "approve allows the named destinations of one sandbox, with or without the port" {
  export FAKE_SBX_APPROVALS="$FAKE_SBX_APPROVALS
network:ddd other api.example.com:443
network:eee app GET api.example.com:8443/v1/data"
  run "$sbx_policy" approve app api.example.com registry.npmjs.org:443
  [ "$status" -eq 0 ]
  [ "$(responses)" = "network:aaa allow
network:eee allow
network:ccc allow" ]
  [[ "$output" == *"3 approved"* ]]
}

@test "a host that does not wait is reported, and the others are still answered" {
  run "$sbx_policy" approve app cdn.example.com api.example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"cdn.example.com"*"not pending for app"* ]]
  [ "$(responses)" = "network:aaa allow" ]
}

@test "dismiss --all dismisses every approval of one sandbox" {
  run "$sbx_policy" dismiss app --all
  [ "$status" -eq 0 ]
  [ "$(responses)" = "network:aaa dismiss
network:ccc dismiss" ]
  [[ "$output" == *"2 dismissed"* ]]
}

@test "approve needs a sandbox and at least one host" {
  run "$sbx_policy" approve
  [ "$status" -eq 1 ]
  [[ "$output" == *"name the sandbox"* ]]

  run "$sbx_policy" approve app
  [ "$status" -eq 1 ]
  [[ "$output" == *"or pass --all"* ]]
  [ -z "$(responses)" ]
}

@test "allow and deny add one network rule for all the hosts, for all sandboxes or for one" {
  run "$sbx_policy" allow api.example.com "*.npmjs.org"
  [ "$status" -eq 0 ]
  run "$sbx_policy" deny --sandbox app ads.example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/sbx.log")" = "policy allow network api.example.com,*.npmjs.org
policy deny network --sandbox app ads.example.com" ]
}

@test "rm removes rules by host or by rule ID" {
  run "$sbx_policy" rm -s app api.example.com 2d3c1f0e-4a73-4e05-bc9d-f2f9a4b50d67 cdn.example.com
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/sbx.log")" = "policy rm network --sandbox app --resource api.example.com,cdn.example.com
policy rm network --sandbox app --id 2d3c1f0e-4a73-4e05-bc9d-f2f9a4b50d67" ]
}

@test "ls lists the local network rules, and passes other flags to sbx" {
  run "$sbx_policy" ls app --created-via approval
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_STATE/sbx.log")" = "policy ls --wide --source local --type network app --created-via approval" ]
}

@test "allow needs a host" {
  run "$sbx_policy" allow --sandbox app
  [ "$status" -eq 1 ]
  [[ "$output" == *"name the hosts"* ]]
  [ ! -s "$FAKE_STATE/sbx.log" ]
}

@test "--help after a verb prints the usage, and changes nothing" {
  run "$sbx_policy" approve --help
  [ "$status" -eq 0 ]
  [[ "$output" == "Usage:"* ]]
  [ ! -s "$FAKE_STATE/sbx.log" ]
}

@test "pending for all sandboxes groups the approvals under each sandbox" {
  export FAKE_SBX_APPROVALS="$FAKE_SBX_APPROVALS
network:ddd other telemetry.nextjs.org.other.docker.internal:443"
  run "$sbx_policy" pending
  [ "$status" -eq 0 ]
  [ "$(sed -n '2,$p' <<<"$output")" = "
app
  waiting api.example.com:443
  waiting registry.npmjs.org:443

other
  waiting cdn.example.com:443
  waiting telemetry.nextjs.org.other.docker.internal:443

4 pending. Answer with sbx-policy approve or dismiss." ]
}
