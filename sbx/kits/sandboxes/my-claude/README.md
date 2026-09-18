# my-claude

A sandbox kit for the Claude Code agent with custom settings. It extends the
upstream `claude` kit, and is the agent `sbx-up` starts by default.

## Quick start

```console
sbx run ./sbx/kits/sandboxes/my-claude
```

## What it changes

- `files/home/.config/my-claude/settings.json` holds the settings: the model,
  the status line, a full-screen TUI, the telemetry and auto-update switches,
  and a small permission denylist.
- `files/home/.local/bin/statusline.sh` draws the status line.
- `agentInstructions` in `spec.yaml` adds the language preferences.

`~/.claude/settings.json` is a sandbox-reserved path, so a kit file placed
there is discarded. The kit owns a file elsewhere instead and passes it with
Claude Code's `--settings` flag, which takes an absolute path. See the comment
in `spec.yaml`.
