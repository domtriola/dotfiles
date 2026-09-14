# Docker Sandbox

This folder holds my custom Docker Sandboxes kits.

- `kits/sandboxes/my-claude` — Claude Code with my settings. The default agent.
- `kits/mixins/agent-skills` — ships my personal agent skills into the sandbox.

## Starting a sandbox

Run `sbx-up` (from `env/.local/bin`) anywhere inside a project. It opens a tmux
window named `sbx` and starts a sandbox for that project and branch, removing
any existing sandbox of the same name first so you always get fresh state.
Inside tmux, it also opens a second window, `shell`, with a plain shell into
the same sandbox (`sbx exec <name> -- bash`) so you can edit files or run git
commands there without going through the agent.

The default branch gets the bare project name; every other branch is suffixed,
so branches can run side by side:

| Branch   | Sandbox name      | tmux windows                 |
| -------- | ----------------- | ---------------------------- |
| `main`   | `dotfiles`        | `sbx`, `shell`               |
| `feat`   | `dotfiles-feat`   | `sbx-feat`, `shell-feat`     |
| `feat/x` | `dotfiles-feat-x` | `sbx-feat-x`, `shell-feat-x` |

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

## Pulling changes from a `--clone` sandbox

A `--clone` sandbox is a standalone git clone, so commits made inside it don't
reach the host until fetched. Run `sbx-pull` (from `env/.local/bin`) from the
same project root and branch used to start the sandbox: it fetches from the
sandbox's `sandbox-<name>` remote and fast-forwards the current branch onto
the new commits. Pass `--rebase` to rebase instead, if the branch has also
moved on the host. It only works while the sandbox is still up, since its
git-daemon goes away with it.
