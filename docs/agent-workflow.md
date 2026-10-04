# Agent workflow

How the agent skills in `env/.agents/skills/` fit together. Each skill's own `SKILL.md` describes what it does.

## Stages

| Stage     | Skill                              | Output                                    |
| --------- | ---------------------------------- | ----------------------------------------- |
| Grill     | `grill-me`, with `domain-modeling` | Decisions, `GLOSSARY.md` terms, ADRs      |
| Spec      | `author-spec`                      | A spec in the repo's tracker              |
| Implement | `implement`, which uses `tdd`      | A PR that closes the spec                 |
| Review    | `code-review`                      | Findings on two axes: standards, and spec |

Run `skills-init` once per repo before the spec stage. It writes
`docs/agents/issue-tracker.md`, which tells the other skills whether specs are
local Markdown files or GitHub issues. A spec is temporary in both cases: the
PR that implements it deletes or closes it.

The agent can push branches and open PRs, but branch protection keeps merges
with a human.

To create, copy, or edit a skill, use the `author-skill` skill.
