# my-claude

A sandbox kit for the Claude Code agent with custom settings. It extends the
upstream `claude` kit, and is the agent `sbx-up` starts by default.

## Quick start

```console
sbx run ./sbx/kits/sandboxes/my-claude
```

## What it changes

- `files/home/.config/my-claude/settings.json` holds the settings: the model,
  the status line, a full-screen TUI, bypass permissions mode with no prompt
  at startup, the error-reporting, feedback and auto-update switches, and a
  small permission denylist. The kit does not set `DISABLE_TELEMETRY`: any
  telemetry opt-out also turns off feature flags, and without them
  `/remote-control` is not available. The kit sets `defaultMode` itself: if only the sandbox's
  `~/.claude/settings.json` sets it, Claude Code asks at each start if auto
  mode is to be the default.
- `/remote-control` also needs the host setting `claude.remoteControl`. Without
  it, Remote Control connects and then keeps disconnecting. The `dev-mac` and
  `agent-server` setup steps set it, and `doctor` checks it.
- `files/home/.local/bin/statusline.sh` draws the status line.
- `agentInstructions` in `spec.yaml` adds the language preferences.
- `setup.install` in `spec.yaml` installs a pinned `gh` release over the old
  `gh` that the image ships. Renovate opens a PR when a new `gh` comes out.

`~/.claude/settings.json` is a sandbox-reserved path, so a kit file placed
there is discarded. The kit owns a file elsewhere instead and passes it with
Claude Code's `--settings` flag, which takes an absolute path. See the comment
in `spec.yaml`.
