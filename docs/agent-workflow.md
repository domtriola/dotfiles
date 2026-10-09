# Agent workflow

How the agent skills in `env/.agents/skills/` fit together. Each skill's own `SKILL.md` describes what it does.

## Stages

| Stage     | Skill                                                          | Output                                    |
| --------- | -------------------------------------------------------------- | ----------------------------------------- |
| Triage    | `triage`                                                       | Labeled issues, agent briefs              |
| Wayfind   | `wayfinder`, for an effort too big for one session             | A map of resolved decision tickets        |
| Grill     | `grill-me`, with `domain-modeling`                             | Decisions, `GLOSSARY.md` terms, ADRs      |
| Spec      | `author-spec`                                                  | A spec in the repo's tracker              |
| Threat    | `author-threat-model`, for a feature that adds attack surface  | A model in `docs/threat-model/`           |
| Tickets   | `author-tickets`, for a spec too big for one session           | Tickets with blocking edges               |
| Implement | `implement` or `implement-tickets`, with `tdd` and `author-pr` | A PR that closes the spec or issue        |
| Review    | `code-review`                                                  | Findings on standards, spec, and security |

Run `skills-init` once per repo before the first stage. It writes
`docs/agents/issue-tracker.md`, which tells the other skills whether specs,
tickets, and maps are local Markdown files or GitHub issues. `triage` needs
GitHub issues. A spec is temporary in both cases: the PR that implements it
deletes or closes it.

The agent can push branches and open PRs, but branch protection keeps merges
with a human. An instruction to implement is the approval to commit, push, and
open the PR, so an issue that `triage` marks `ready-for-agent` needs no other
approval. `implement` stops to ask only when the spec contradicts the code, or
before a one-way door.

Two skills work at any stage: `diagnosing-bugs` for a hard bug, and
`author-prototype` for a design question. Run `retro` after a session to find
improvements to the agent's environment.

Run `author-threat-model` once per repo for the product model. The
Security axis of `code-review` checks every change against it.

To create, copy, or edit a skill, use the `author-skill` skill.

## Vocabulary

Two skills own the terms that the other skills use:

- `codebase-design` owns the design terms: module, interface, depth, seam, and adapter. Other skills link to it and do not define these terms again.
- `domain-modeling` owns each project's `GLOSSARY.md`, which holds that project's domain terms.
