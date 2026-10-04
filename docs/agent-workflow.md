# Agent workflow

How the agent skills in `env/.agents/skills/` fit together, and the rules for
maintaining them. Each skill's own `SKILL.md` describes what it does.

## Stages

| Stage     | Skill                              | Output                                      |
| --------- | ---------------------------------- | ------------------------------------------- |
| Grill     | `grill-me`, with `domain-modeling` | Decisions, `GLOSSARY.md` terms, ADRs        |
| Spec      | `to-spec`                          | A spec in the repo's tracker                |
| Implement | `implement`, which uses `tdd`      | A PR that closes the spec                   |
| Review    | `code-review`                      | Findings on two axes: standards, and spec   |

Run `skills-init` once per repo before the spec stage. It writes
`docs/agents/issue-tracker.md`, which tells the other skills whether specs are
local Markdown files or GitHub issues. A spec is temporary in both cases: the
PR that implements it deletes or closes it.

The agent can push branches and open PRs, but branch protection keeps merges
with a human.

## Ownership

Some skills started as copies of
[mattpocock/skills](https://github.com/mattpocock/skills). They are maintained
here and are not updated from upstream, because local changes for this
workflow would conflict with each update. A copied skill holds a `LICENSE` with
both copyright lines, and keeps it however much it is rewritten.

To copy another skill, clone the upstream repo, copy the skill's directory into
`env/.agents/skills/`, add the `LICENSE`, and apply the rules below once. Review
it with the `skills-security-review` skill first: a skill is instructions that
run with the agent's permissions.

## Rules for skills

The `writing-for-agents` skill is the reference. These rules apply it:

1. **Invocation.** A skill is model-invoked only when the agent or another
   skill must find it without the user. Every other skill sets
   `disable-model-invocation: true`.
2. **Length.** A `SKILL.md` stays under about 100 lines. Material that only
   some branches need goes into a linked file in the skill's directory.
3. **Prune on copy.** A copied skill is pruned once with `writing-for-agents`,
   and its dependencies on skills that are not here are removed.
4. **Portability.** The skills must work in Claude Code and in `pi`, which has
   no Skill tool and no built-in sub-agents. Refer to another skill by name and
   relative path, for example "the `tdd` skill (`../tdd/SKILL.md`)". Give every
   sub-agent step a fallback for an agent that cannot dispatch one. Do not
   depend on tools that only one agent has.
