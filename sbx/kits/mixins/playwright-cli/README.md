# playwright-cli

A mixin kit that installs [`playwright-cli`](https://github.com/microsoft/playwright-cli)
and Chromium in the sandbox, so the agent can open the app in a browser and
take screenshots. It is for projects that run their commands in Docker Compose:
the app's published port is reachable on `localhost` from the sandbox.

## Quick start

The kit is not in the default kit list. A project opts in with `kits` in its
`.sbx.json`. That list replaces the default, so name the default kits too:

```json
{ "kits": ["agent-skills", "dotfiles", "playwright-cli"] }
```

Or with `sbx` directly:

```console
sbx run claude --kit ./sbx/kits/mixins/playwright-cli
```

## What it installs

The install script is `files/home/.local/libexec/playwright-cli-kit/install`.
It installs these, all for the agent user:

| What           | Where                                                                    |
| -------------- | ------------------------------------------------------------------------ |
| Node           | `~/.local/share/playwright-cli-kit/node`, from nodejs.org, checksummed.  |
| playwright-cli | The latest `@playwright/cli`, into that Node.                            |
| Chromium       | `~/.cache/ms-playwright`, with its system packages from apt (with sudo). |
| The wrapper    | `~/.local/bin/playwright-cli`, written last.                             |

The wrapper puts the kit's Node first on `PATH` for the CLI alone, so the
`node` on the agent's `PATH` does not change. It also sets
`PLAYWRIGHT_MCP_BROWSER=chromium`, because the CLI's own default is Chrome,
which has no arm64 build.

The kit does not install the project's dependencies, and writes nothing in the
workspace. It reads the workspace only to choose the Node version:

1. `.nvmrc`, then `.node-version`, then `engines.node` in `package.json`.
2. With none of them, the newest LTS.

A major (`20`, `^20.1`, `20.x`) gets the newest release of that major, and a
lower bound (`>=20`) gets the newest LTS. The comment above `resolve_node` in
the script lists every form.

## Knowing when it has finished

The startup hook returns at once, so the agent starts without a wait. The
install runs in the background and takes a minute or two on a cold start, most
of it the Chromium download and its apt packages.

These files under `$HOME` report the state:

| File                           | Meaning                                               |
| ------------------------------ | ----------------------------------------------------- |
| `~/.playwright-cli-kit.log`    | Everything the install printed. Rewritten each start. |
| `~/.playwright-cli-kit.status` | The current step, then `ready` or `failed`.           |

The agent instructions tell the agent to wait for `ready`. Until then,
`playwright-cli` is not on `PATH`.

To check by hand, use the absolute path, since a `~` in an `sbx exec` command
is expanded by the host shell:

```console
sbx exec <name> -- cat /home/agent/.playwright-cli-kit.log
```

## Notes

- **A failure does not stop the sandbox.** The status file reads `failed`, and
  the log holds the reason.
- **Every start installs again.** A restart replaces Node and reinstalls
  `@playwright/cli`, which takes a few seconds. Chromium and its packages are
  already there, so they cost nothing.
- **The network allow list** has only the install's hosts: nodejs.org, the npm
  registry, the Playwright browser CDN and its mirror, and the Ubuntu apt
  mirrors.
