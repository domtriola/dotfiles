# Docker Sandbox

This folder holds the custom Docker Sandboxes kits. Each kit has its own README.

| Kit                                                                  | What it is                                                                                  |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [`kits/sandboxes/my-claude`](kits/sandboxes/my-claude/README.md)     | Claude Code with custom settings. The default agent.                                        |
| [`kits/sandboxes/pi-ailo`](kits/sandboxes/pi-ailo/README.md)         | The pi agent, pointed at a self-hosted model server. No hosted model and no API credential. |
| [`kits/mixins/agent-skills`](kits/mixins/agent-skills/README.md)     | Ships the personal agent skills into the sandbox.                                           |
| [`kits/mixins/dotfiles`](kits/mixins/dotfiles/README.md)             | Clones this repo into the sandbox and applies it with the `sbx-linux` profile.              |
| [`kits/mixins/playwright-cli`](kits/mixins/playwright-cli/README.md) | Installs `playwright-cli` and Chromium, for projects that opt in.                           |

## Commands

`sync-env` installs these commands into `~/.local/bin` for the `dev-mac` and
`dev-linux` profiles.

| Command      | What it does                                               | Reference           |
| ------------ | ---------------------------------------------------------- | ------------------- |
| `sbx-up`     | Starts a sandbox for the current project and branch.       | `sbx-up --help`     |
| `sbx-shell`  | Opens a shell into a sandbox, in a new tmux window.        | `sbx-shell --help`  |
| `sbx-token`  | Gives a sandbox a GitHub token for its repositories only.  | `sbx-token --help`  |
| `sbx-policy` | Answers sandbox approvals and manages local network rules. | `sbx-policy --help` |
| `sbx-pull`   | Fetches commits made inside a `--clone` sandbox.           | its header comment  |

`sbx-up`, `sbx-shell`, `sbx-token` and `sbx-policy` are command directories in
`commands/`.
`sbx-shell` has a `libexec/` holding `sbx-wait`, which the shell window runs
rather than sources. `sbx-pull` is a single file in `env/.local/bin`.

### Inside a sandbox

The `sbx-linux` profile installs this command in every sandbox.

| Command           | What it does                                                                    | Reference                |
| ----------------- | ------------------------------------------------------------------------------- | ------------------------ |
| `sbx-compose-run` | Runs one command in a Compose service, quietly, and gives its files to `agent`. | `sbx-compose-run --help` |

It is a single file in `env/.local/bin`. The `my-claude` kit's agent instructions
name it, for projects that run their tooling in Docker Compose.

## Starting a sandbox

Run `sbx-up` anywhere inside a project. The sandbox is named after the project
directory and the checked-out branch, and any existing sandbox of that name is
removed first, so every start begins from fresh state.

Inside tmux it opens an `sbx` window, which runs the agent. The window name
carries the branch as a suffix, unless the branch is the default one.
Outside tmux, `sbx-up` runs the sandbox in the current terminal.

`sbx-up` opens no shell window, in either workspace mode (see
[Opening a shell](#opening-a-shell)). The sandbox has its own GitHub token (see
`sbx-token --help`), so the agent commits and pushes its work itself.

`sbx-up` also runs `sync-skills` before it starts the sandbox, so the
`agent-skills` kit ships the skills that are on disk at that moment.

## Opening a shell

`sbx-shell <name>` opens a window, `shell-<name>`, which holds a plain shell
into the sandbox (`sbx exec -it <name> -- bash -l`), for editing files or
running git commands without going through the agent. `sbx ls` lists the
names.

The window runs the command's `sbx-wait` helper first, which draws the wait
and names the step it is on. When the `dotfiles` kit is still configuring the
sandbox, it waits for the kit too. Outside tmux, the shell runs in the current
terminal.

## Network access

The sandbox firewall blocks a destination that no rule allows. When a policy
asks for approval, the blocked request waits as a pending approval.
`sbx-policy` answers them by sandbox and host, so there is no approval ID to
copy:

```console
sbx-policy pending my-sandbox
sbx-policy approve my-sandbox api.example.com
```

It also adds, lists and removes the local network rules (`sbx-policy allow`,
`ls`, `rm`). See `sbx-policy --help`.

## Per-project settings

Drop a `.sbx.json` at the project root to choose the agent, the kits, the
memory limit, the size of the Docker disk, and whether the sandbox gets its own
clone. Every key is optional, and `sbx-up --help` lists them with their
defaults.

The Docker disk (`/var/lib/docker`) holds the images, containers, and volumes
that the agent makes. Its default is the `sbx` setting
`sandbox.disk.dockerVolume`, which `setup` sets to 30g. A project that builds
big images can ask for more:

```json
{ "disk": "60g" }
```

The size is a limit, not space that is kept: a sandbox uses only the space that
it writes. The size applies only when a sandbox is made. `sbx-up` makes the
sandbox again on each start, so a new size applies at the next start.

Naming an agent on the command line overrides the file for one run:

```console
sbx-up pi-ailo
```

## Kit arguments

A kit declares the inputs it needs in an `args:` block, and references them as
`${{ kit.args.<name> }}` anywhere in its `spec.yaml`. Some of those values
belong to a machine rather than to this repository, such as the address of a
private server, so they are kept outside it:

```console
mkdir -p ~/.config/sbx
printf 'modelHost=%s\n' '<host>' >~/.config/sbx/kit.args
```

`sbx-up` passes that file with `--kit-args-file` when, and only when, the agent
kit declares arguments. `sbx` rejects an argument that no kit declares, so
passing it to every sandbox would break the ones that take none.

`$SBX_KIT_ARGS_FILE` names a different file. A sandbox kit given as a URL or a
zip is left alone, because the check reads the kit's spec from disk; supply its
arguments with `--kit-arg` by hand.

Only `pi-ailo` takes arguments today. Its README says what they mean.

## Git identity

No kit here sets the git identity, because `sbx` does it. When it creates a
sandbox for a v2 kit, it copies `user.name` and `user.email` from the host's
git config for the project into the sandbox's `~/.gitconfig`. A repository's
own config still overrides them. If the host has no identity, `git commit` in
the sandbox fails with "Author identity unknown". Set it on the host and
recreate the sandbox.

A v3 kit gets the identity only when it declares the
`com.docker.sandbox/git-identity@1` capability. Declare it when you migrate
`my-claude` to v3. Do not pass the identity as a kit argument: the kit spec
says that the runtime selects it.

## Pulling changes from a `--clone` sandbox

`sbx-up` gives a project in git its own clone unless its `.sbx.json` sets
`"clone": false`, because a sandbox that mounts the host worktree can write
files that the host runs later, such as `.git/hooks`. A `--clone` sandbox is a
standalone git clone, so commits made inside it do not reach the host until
they are fetched. Run `sbx-pull` from the same project root
and branch that started the sandbox: it fetches from the sandbox's
`sandbox-<name>` remote and fast-forwards the current branch. Pass `--rebase`
when the branch has moved on the host as well.

The remote is served by the sandbox, so this only works while the sandbox still
runs.
