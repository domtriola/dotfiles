# agent-skills

A mixin kit that ships this repo's personal agent skills into the sandbox.

A startup hook symlinks each `~/skills/<name>/` into
`~/.claude/skills/`, `~/.gemini/skills/` and `~/.agents/skills/`, so whichever
agent is running sees the same skills.

Skills currently shipped:

- **kit-author**, for writing Docker Sandboxes kits.
- **skills-security-review**, for reviewing skills for potential security issues.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/agent-skills
```
