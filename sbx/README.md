# Docker Sandbox

This folder holds my custom Docker Sandboxes kits.

- `kits/sandboxes/my-claude` — Claude Code with my settings. The default agent.
- `kits/sandboxes/local-pi` — the pi agent, pointed at an Ollama server on the
  host. No hosted model and no API credential.
- `kits/mixins/agent-skills` — ships my personal agent skills into the sandbox.
- `kits/mixins/dotfiles` — clones this repo into the sandbox and applies it with
  the `sbx-linux` profile.

## Starting a sandbox

Run `sbx-up` (from `env/.local/bin`) anywhere inside a project. It opens a tmux
window named `sbx` and starts a sandbox for that project and branch, removing
any existing sandbox of the same name first so you always get fresh state.
Inside tmux, it also opens a second window, `shell`, with a plain shell into
the same sandbox (`sbx exec -it <name> -- bash -l`) so you can edit files or run
git commands there without going through the agent.

## Per-project settings

Drop a `.sbx.json` at the project root. Every key is optional, and `jq` merges
it over the defaults:

```json
{
  "agent": "my-claude",
  "kits": ["dotfiles", "agent-skills"],
  "memory": "8g",
  "clone": true
}
```

## Pulling changes from a `--clone` sandbox

A `--clone` sandbox is a standalone git clone, so commits made inside it don't
reach the host until fetched. Run `sbx-pull` (from `env/.local/bin`) from the
same project root and branch used to start the sandbox: it fetches from the
sandbox's `sandbox-<name>` remote.
