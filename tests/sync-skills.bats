#!/usr/bin/env bats
#
# sync-skills, through its command line, on a copy of the agent-skills kit.

load helpers

setup() {
  common_setup
  sync_skills="$repo_root/commands/sync-skills/sync-skills"

  # A dotfiles checkout with what sync-skills reads: the style library, the
  # kit's committed files, and the skills.
  export DOTFILES_DIR="$BATS_TEST_TMPDIR/dotfiles"
  kit="$DOTFILES_DIR/sbx/kits/mixins/agent-skills"
  mkdir -p "$DOTFILES_DIR/profiles" "$DOTFILES_DIR/lib" "$kit"
  cp "$repo_root/lib/style.sh" "$DOTFILES_DIR/lib/"
  cp "$repo_root/sbx/kits/mixins/agent-skills/descriptor.yaml.tmpl" "$kit/"
  tracked="$DOTFILES_DIR/env/.agents/skills"
  local_skills="$DOTFILES_DIR/env/.agents/skills-local"
}

# skill <dir> <name> [body] makes a skill named <name> in <dir>.
skill() {
  mkdir -p "$1/$2"
  printf '%s\n' "${3:-tracked}" >"$1/$2/SKILL.md"
}

# entries prints the skill paths that the generated descriptor declares.
entries() {
  sed -n 's/^ *path: //p' "$kit/agent-skills.yaml"
}

@test "each skill gets its own agent-skill entry, in name order" {
  skill "$tracked" review
  skill "$tracked" design
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [ "$(entries)" = "/usr/share/agent-skills/design
/usr/share/agent-skills/review" ]
  [ "$(grep -c 'type: com.docker.sandbox/agent-skill@1' "$kit/agent-skills.yaml")" -eq 2 ]
  [ -f "$kit/skills/design/SKILL.md" ] && [ -f "$kit/skills/review/SKILL.md" ]
}

@test "the descriptor starts with the template" {
  skill "$tracked" review
  run "$sync_skills"
  [ "$status" -eq 0 ]
  template="$kit/descriptor.yaml.tmpl"
  [ "$(head -n "$(wc -l <"$template")" "$kit/agent-skills.yaml")" = "$(cat "$template")" ]
}

@test "a local skill shadows a tracked skill of the same name" {
  skill "$tracked" review
  skill "$local_skills" review local
  skill "$local_skills" scratch local
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [ "$(cat "$kit/skills/review/SKILL.md")" = local ]
  [ "$(entries)" = "/usr/share/agent-skills/review
/usr/share/agent-skills/scratch" ]
}

@test "a directory with no SKILL.md is not a skill" {
  skill "$tracked" review
  mkdir -p "$tracked/notes"
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [ "$(entries)" = "/usr/share/agent-skills/review" ]
  [ ! -e "$kit/skills/notes" ]
}

@test "a skill whose name the runtime refuses is left out, with a warning" {
  skill "$tracked" review
  skill "$tracked" "bad name"
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bad name"* ]]
  [ "$(entries)" = "/usr/share/agent-skills/review" ]
  [ ! -e "$kit/skills/bad name" ]
}

@test "a skill removed from the source is removed from the kit" {
  skill "$tracked" review
  skill "$tracked" old
  "$sync_skills" >/dev/null
  rm -rf "$tracked/old"
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [ ! -e "$kit/skills/old" ]
  [ "$(entries)" = "/usr/share/agent-skills/review" ]
}

@test "with no skills, the kit still builds: an empty skills directory and no entries" {
  mkdir -p "$tracked"
  run "$sync_skills"
  [ "$status" -eq 0 ]
  [ -d "$kit/skills" ]
  [ -z "$(entries)" ]
}

@test "a dry run changes nothing" {
  skill "$tracked" review
  run "$sync_skills" --dry
  [ "$status" -eq 0 ]
  [ ! -e "$kit/skills" ]
  [ ! -e "$kit/agent-skills.yaml" ]
}
