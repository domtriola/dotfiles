# agent-skills

A mixin kit that ships this repo's personal agent skills into the sandbox.

A startup hook symlinks each skill directory under `~/skills/` into
`~/.claude/skills/`, `~/.gemini/skills/` and `~/.agents/skills/`, so whichever
agent is running sees the same skills. A directory counts as a skill only if it
contains a `SKILL.md`.

Skills currently shipped:

- **kit-author**, for writing Docker Sandboxes kits.
- **skills-security-review**, for reviewing skills for potential security issues.

## Experimental skills

`files/home/skills/experimental/` is a scratch area whose contents are ignored by
git (see the `.gitignore` inside it) but are still copied into the sandbox, since
the kit is loaded from this working tree rather than from a clean checkout. Drop a
skill in and it is picked up on the next sandbox start:

```console
cp -R ../some-repo/skills/tdd sbx/kits/mixins/agent-skills/files/home/skills/experimental/
```

Up to two levels of grouping are supported, so both
`experimental/<name>/SKILL.md` and `experimental/<vendor>/<topic>/<name>/SKILL.md`
are found. Note: experimental skills are linked after the tracked ones, so an
experimental copy of a shipped skill shadows it.

To promote one, move it up into `files/home/skills/` and commit it.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/agent-skills
```
