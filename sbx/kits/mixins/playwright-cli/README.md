# playwright-cli

A mixin kit that installs [`playwright-cli`](https://github.com/microsoft/playwright-cli)
and Chromium in the sandbox.

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
| playwright-cli | `@playwright/cli`, at the version that `spec.yaml` pins, into that Node. |
| Chromium       | `~/.cache/ms-playwright`, with its system packages from apt (with sudo). |
| The proxy CA   | `~/.pki/nssdb`, with `certutil` from apt (`libnss3-tools`).              |
| The wrapper    | `~/.local/bin/playwright-cli`, written last.                             |

The wrapper puts the kit's Node first on `PATH` for the CLI alone, so the
`node` on the agent's `PATH` does not change. It also sets
`PLAYWRIGHT_MCP_BROWSER=chromium`, because the CLI's own default is Chrome,
which has no arm64 build.

The sandbox proxy intercepts TLS with its own CA. Chromium on Linux does not
read the system CA bundle, only the NSS database in `~/.pki/nssdb`. So the kit
adds the proxy's CA (`/usr/local/share/ca-certificates/proxy-ca.crt`) there.
Without it, every HTTPS page fails with `ERR_CERT_AUTHORITY_INVALID`.

The kit does not install the project's dependencies, and writes nothing in the
workspace. It reads the workspace only to choose the Node version:

1. `.nvmrc`, then `.node-version`, then `engines.node` in `package.json`.
2. With none of them, the newest LTS.

A major (`20`, `^20.1`, `20.x`) gets the newest release of that major, and a
lower bound (`>=20`) gets the newest LTS. The comment above `resolve_node` in
the script lists every form.

## Knowing when it has finished

The startup hook returns at once, so the agent starts without a wait. The
install runs in the background and takes a minute or two on a cold start. Most
of this time is for the Chromium download and its apt packages.

These files under `$HOME` report the state:

| File                           | Meaning                                               |
| ------------------------------ | ----------------------------------------------------- |
| `~/.playwright-cli-kit.log`    | Everything the install printed. Rewritten each start. |
| `~/.playwright-cli-kit.status` | The current step, then `ready` or `failed`.           |

The agent instructions tell the agent to wait for `ready`. Until then,
`playwright-cli` is not on `PATH`.

To check by hand, use the absolute path, because a `~` in an `sbx exec` command
is expanded by the host shell:

```console
sbx exec <name> -- cat /home/agent/.playwright-cli-kit.log
```

## Notes

- **A failure does not stop the sandbox.** The status file reads `failed`, and
  the log holds the reason.
- **Every start installs again.** A restart replaces Node and installs
  `@playwright/cli` again, which takes a few seconds. Chromium and its packages
  are already there, so the install skips them.
- **The `@playwright/cli` version is pinned** in the startup hook, and Renovate
  bumps it after a 7-day release age. The Node version is not pinned, because
  the project chooses it. Its checksum comes from nodejs.org, the same host as
  the tarball.
- **The network allow list** has only the install's hosts: nodejs.org, the npm
  registry, the Playwright browser CDN and its mirror, and the Ubuntu apt
  mirrors.
