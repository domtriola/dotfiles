# my-claude

A mixin for the Claude Code agent with custom settings. It goes on the
published `claude` kit (`docker.io/sbx/claude-kit`, from
[docker/sbx-kits-contrib](https://github.com/docker/sbx-kits-contrib/tree/main/claude)),
and is the agent `sbx-up` starts by default.

`sbx` no longer has a built-in `claude` agent, and a kit cannot extend a
published kit, so this kit is a mixin and not a sandbox kit. `sbx-up` pins the
`claude` kit by digest in `commands/sbx-up/lib/config`, and Renovate opens a PR
when its `latest` tag moves. The kit goes in place of the agent name: the
bare name `claude` now resolves to the v3 kit `docker.io/sbx/claude`, and
`sbx` does not put v2 mixins such as this one on a v3 kit.

## Quick start

```console
sbx run docker.io/sbx/claude-kit:latest --kit ./sbx/kits/mixins/my-claude
```

## What it changes

- `files/home/.config/my-claude/settings.json` holds the settings: the model,
  the status line, a full-screen TUI, bypass permissions mode with no prompt
  at startup, the error-reporting, feedback and auto-update switches, and a
  small permission denylist. The kit sets `defaultMode` itself: if only the
  sandbox's `~/.claude/settings.json` sets it, Claude Code asks at each start
  if auto mode is to be the default.
- `environment.variables` in `spec.yaml` sets `DISABLE_TELEMETRY` to `0`. The
  published claude kit sets it to `1`, but any telemetry opt-out also turns
  off feature flags, and without them `/remote-control` is not available.
- `/remote-control` also needs the host setting `claude.remoteControl`. Without
  it, Remote Control connects and then keeps disconnecting. The `dev-mac` and
  `agent-server` setup steps set it, and `doctor` checks it.
- `files/home/.local/bin/statusline.sh` draws the status line.
- `files/home/.claude/CLAUDE.md` holds the agent instructions, such as the
  language preferences. A mixin's `agentInstructions` go to a file that the
  agent reads only when it needs it, so the kit uses Claude Code's user memory,
  which it always loads.
- `setup.install` in `spec.yaml` installs a pinned `gh` release over the old
  `gh` that the image ships. Renovate opens a PR when a new `gh` comes out.

`~/.claude/settings.json` is a sandbox-reserved path, so a kit file placed
there is discarded. A mixin cannot set the launch command, so Claude Code's
`--settings` flag is not available either. An install step copies the settings
to `/etc/claude-code/managed-settings.json`, which Claude Code reads on each
start. Managed settings have the highest precedence, so nothing in the sandbox
can override them. See the comment in `spec.yaml`.
