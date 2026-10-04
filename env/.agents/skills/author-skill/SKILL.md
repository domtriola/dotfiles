---
name: author-skill
description: Author an agent skill. Use when creating, copying, or editing a skill in this repo.
---

Skills live in `env/.agents/skills/<name>/`. The `writing-for-agents` skill (`../writing-for-agents/SKILL.md`) is the reference for how to write one. Read it before you write, and apply it to every line.

## Rules

1. **Naming.** A skill that creates a resource is named `author-<resource>`.
2. **Invocation.** A skill is model-invoked only when the agent or another skill must find it without the user. Every other skill sets `disable-model-invocation: true`.
3. **Length.** A `SKILL.md` stays under about 100 lines. Material that only some branches need goes into a linked file in the skill's directory.
4. **Portability.** Skills must work in Claude Code and in `pi`, which has no Skill tool and no built-in sub-agents. Refer to another skill by name and relative path, for example "the `tdd` skill (`../tdd/SKILL.md`)". Give every sub-agent step a fallback for an agent that cannot dispatch one. Use only tools that every agent has.

## Copying a skill from another repo

1. Review it with the `skills-security-review` skill (`../skills-security-review/SKILL.md`). A skill is instructions that run with the agent's permissions.
2. Copy its directory into `env/.agents/skills/`. Keep the upstream `LICENSE` and add `Copyright (c) <year> Dominick Triola` below its copyright line. If the license is not MIT, stop and ask the user.
3. Prune it once with `writing-for-agents`, and remove its dependencies on skills that are not here.

A copied skill is maintained here and is not updated from upstream.

The work is done when every rule above holds for the skill.
