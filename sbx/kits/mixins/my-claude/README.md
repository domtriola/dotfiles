# my-claude

A v3 mixin for the Claude Code agent with custom settings. It goes on Docker's
Claude Code workload, `docker.io/docker/sbx-kit-claude`, and is the agent
`sbx-up` starts by default.

`sbx-up` pins the workload by version tag and digest in
`commands/sbx-up/lib/config`. The workload is the base image of the sandbox,
so the digest pins the image too. Renovate opens a PR that moves the tag and
the digest together. The bare name `claude` resolves to
`docker.io/sbx/claude:latest`, which moves, so `sbx-up` names the workload
instead.

## Quick start

```console
sbx run docker.io/docker/sbx-kit-claude:<version>@sha256:<digest> --kit ./sbx/kits/mixins/my-claude
```

`sbx` builds the mixin with Buildx when it creates the sandbox.

## What it changes

`my-claude.dockerfile` puts every file outside `/home/agent`. The workload
writes `~/.claude/settings.json` in an install hook, and the runtime manages
`~/.claude/CLAUDE.md`, so a kit file there can be replaced.

- `files/settings.json` goes to `/etc/claude-code/managed-settings.json`. It
  holds the settings: the model, the status line, a full-screen TUI, bypass
  permissions mode with no prompt at startup, and the error-reporting,
  feedback and auto-update switches. Claude Code reads it on each start.
  Managed settings have the highest precedence, so nothing in the sandbox can
  override them. The kit does not set `DISABLE_TELEMETRY`: any telemetry
  opt-out also turns off feature flags, and without them `/remote-control` is
  not available. The kit sets `defaultMode` itself: if only the sandbox's
  `~/.claude/settings.json` sets it, Claude Code asks at each start if auto
  mode is to be the default.
- `/remote-control` also needs the host setting `claude.remoteControl`. Without
  it, Remote Control connects and then keeps disconnecting. The `dev-mac` and
  `agent-server` setup steps set it, and `doctor` checks it.
- `files/CLAUDE.md` goes to `/etc/claude-code/CLAUDE.md`, Claude Code's managed
  memory, which it always loads. It holds the agent instructions, such as the
  language preferences. A v3 kit's context file is one the agent reads only
  when it needs it, so the kit does not use one.
- `files/statusline.sh` goes to `/usr/local/libexec/my-claude/statusline.sh`
  and draws the status line. It shows the memory use against the sandbox's
  cgroup limit, and the 1-minute load average. It replaces the workload's
  status line command, which feeds the Docker desktop app's session view.
- A pinned `gh` release goes to `/usr/local/bin/gh`, ahead of the workload's
  own `gh` on PATH. A build stage downloads it and checks it against the
  release's checksum file. Renovate opens a PR when a new `gh` comes out.

`my-claude.yaml` declares:

- `credential@1` for the `github` service, and the GitHub hosts in its network
  allow list. `$GH_TOKEN` holds a sentinel, and the proxy puts the sandbox's
  `github` secret on requests to those hosts. See
  [GitHub access](../../../README.md#github-access).
- `git-identity@1`, so commits carry the host's git identity. See
  [Git identity](../../../README.md#git-identity).
