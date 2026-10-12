#!/usr/bin/env bats
#
# The retro skill's context-cost script, through its command line, against a
# small Claude Code session log written by each test.

load helpers

setup() {
  common_setup
  context_cost="$repo_root/env/.agents/skills/retro/scripts/context-cost"
  projects="$HOME/.claude/projects/-some-project"
  mkdir -p "$projects"
  session="$projects/abc-123.jsonl"
  given_session >"$session"
}

# assistant prints one assistant line: <id> <input> <cache writes> <cache reads>
# <output> [<tool_use content>]. Claude Code writes one line per content
# block, all with the same message id and usage.
assistant() {
  jq -cn --arg id "$1" --argjson i "$2" --argjson cw "$3" --argjson cr "$4" \
    --argjson o "$5" --argjson content "${6:-[]}" \
    '{type: "assistant", message: {id: $id, role: "assistant", content: $content,
      usage: {input_tokens: $i, cache_creation_input_tokens: $cw,
              cache_read_input_tokens: $cr, output_tokens: $o}}}'
}

# tool_result prints one user line that answers <tool_use_id> with <content>.
tool_result() {
  jq -cn --arg id "$1" --argjson content "$2" \
    '{type: "user", message: {role: "user",
      content: [{type: "tool_result", tool_use_id: $id, content: $content}]}}'
}

# chars prints <n> characters.
chars() {
  head -c "$1" /dev/zero | tr '\0' x
}

# given_session prints five turns. Turn contexts: 100, 110, 201, 301, 401.
given_session() {
  local bash_call='[{"type": "tool_use", "id": "t1", "name": "Bash", "input": {"command": "cat big.txt"}}]'
  local read_call='[{"type": "tool_use", "id": "t2", "name": "Read", "input": {"file_path": "/x/small.txt"}}]'
  assistant a1 10 90 0 5 '[{"type": "text", "text": "Reading."}]'
  assistant a1 10 90 0 5 "$bash_call"
  tool_result t1 "$(jq -n --arg s "$(chars 4000)" '$s')"
  assistant a2 1 9 100 7 "$read_call"
  tool_result t2 "$(jq -n --arg s "$(chars 400)" '[{type: "text", text: $s}]')"
  jq -cn --arg s "$(chars 800)" '{type: "attachment", attachment: {type: "edited_text_file", content: $s}}'
  jq -cn --arg s "$(chars 200)" '{type: "attachment", attachment: {type: "edited_text_file", content: $s}}'
  jq -cn '{type: "attachment", attachment: {type: "date", date: "2026-10-12"}}'
  assistant a3 1 0 200 3
  assistant a4 1 0 300 1
  assistant a5 1 0 400 1
}

@test "the context size at the first turn, the quartiles, the end, and the peak" {
  run "$context_cost" "$session"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turns: 5"* ]]
  [[ "$output" == *"first 100, 25% 110, 50% 201, 75% 301, last 401, peak 401"* ]]
}

@test "the totals count a message once, though its log has a line per block" {
  run "$context_cost" "$session"
  [[ "$output" == *"Cache reads: 1000"* ]]
  [[ "$output" == *"Cache writes: 99"* ]]
  [[ "$output" == *"Output: 17"* ]]
}

@test "the largest tool results come first, with their tool and input" {
  run "$context_cost" "$session"
  local results="${output#*Largest tool results}"
  [[ "$results" == *"1000  Bash  cat big.txt"*"100  Read  /x/small.txt"* ]]
}

@test "the attachments are grouped by type, largest first" {
  run "$context_cost" "$session"
  local attachments="${output#*Attachments by type}"
  [[ "$attachments" =~ edited_text_file\ +2\ +[0-9]+ ]]
  [[ "$attachments" == *"edited_text_file"*"date"* ]]
}

@test "a session id finds its log under ~/.claude/projects" {
  run "$context_cost" abc-123
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turns: 5"* ]]
}

@test "an unknown session is an error" {
  run "$context_cost" no-such-session
  [ "$status" -ne 0 ]
  [[ "$output" == *"no session log"* ]]
}
