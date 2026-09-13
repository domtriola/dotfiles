# Docker Sandbox

This folder holds my custom Docker Sandboxes kits.

- `kits/sandboxes/my-claude` — Claude Code with my settings. The default agent.
- `kits/mixins/agent-skills` — ships my personal agent skills into the sandbox.

## Starting a sandbox

Run `sbx-up` (from `env/.local/bin`) anywhere inside a project. It opens a new
tmux window and starts a sandbox for that project and branch, removing any
existing sandbox of the same name first so you always get fresh state.

The default branch gets the bare project name; every other branch is suffixed,
so branches can run side by side:

| Branch    | Sandbox name       |
| --------- | ------------------ |
| `main`    | `dotfiles`         |
| `sbx-bin` | `dotfiles-sbx-bin` |
| `feat/x`  | `dotfiles-feat-x`  |

The default branch is read from `origin/HEAD`, so run
`git remote set-head origin --auto` in any repo where that is not set.

## Per-project settings

Drop a `.sbx.json` at the project root. Every key is optional, and `jq` merges
it over the defaults:

```json
{
  "agent": "my-claude",
  "kits": ["agent-skills"],
  "memory": "8g",
  "clone": true
}
```

`agent` names a kit in `kits/sandboxes` and `kits` names mixins in
`kits/mixins`; a name containing a `/` is used as a path instead.
