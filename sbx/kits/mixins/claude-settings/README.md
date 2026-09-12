# claude-settings

This mixin injects a project scoped Claude Code settings file into a sandbox. The
file is owned by the kit, not by the repository that happens to be mounted, and it is
rewritten on every container start.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/claude-settings
```
