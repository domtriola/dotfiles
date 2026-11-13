`playwright-cli` drives a headless Chromium. See `playwright-cli --help`.

- It is installed in the background after the sandbox starts, which takes
  a minute or two. Before your first `playwright-cli` command, wait until
  `~/.playwright-cli-kit.status` reads `ready`. If it reads `failed`, the
  reason is in `~/.playwright-cli-kit.log`.
- When the app runs in Docker Compose, open it on
  `http://localhost:<published port>`. `docker compose ps` shows the
  published ports.
- It writes its snapshots to `.playwright-cli/` in the current directory.
  Do not commit them.
- It has its own Node, in `~/.local/share/playwright-cli-kit`. It does not
  change the `node` on PATH, and it installs nothing in the project.
