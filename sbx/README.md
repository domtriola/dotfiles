# Docker Sandbox

This folder holds the custom Docker Sandboxes kits. Each kit has its own README.

| Kit                                                              | What it is                                                                                  |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| [`kits/sandboxes/my-claude`](kits/sandboxes/my-claude/README.md) | Claude Code with custom settings. The default agent.                                        |
| [`kits/sandboxes/local-pi`](kits/sandboxes/local-pi/README.md)   | The pi agent, pointed at a self-hosted model server. No hosted model and no API credential. |
| [`kits/mixins/agent-skills`](kits/mixins/agent-skills/README.md) | Ships the personal agent skills into the sandbox.                                           |
| [`kits/mixins/dotfiles`](kits/mixins/dotfiles/README.md)         | Clones this repo into the sandbox and applies it with the `sbx-linux` profile.              |

## Commands

`./sync-env` installs three helper commands into `~/.local/bin` for the
`dev-mac` and `dev-linux` profiles.

| Command    | What it does                                                      | Reference          |
| ---------- | ----------------------------------------------------------------- | ------------------ |
| `sbx-up`   | Starts a sandbox for the current project and branch.              | `sbx-up --help`    |
| `sbx-wait` | Waits for a sandbox to be usable, and names the step it waits on. | its header comment |
| `sbx-pull` | Fetches commits made inside a `--clone` sandbox.                  | its header comment |

`sbx-up` is a package in `packages/sbx-up`: an entry point, and a `lib/` of one
file per step. The other two are single files in `env/.local/bin`.

## Starting a sandbox

Run `sbx-up` anywhere inside a project. The sandbox is named after the project
directory and the checked-out branch, and any existing sandbox of that name is
removed first, so every start begins from fresh state.

Inside tmux it opens an `sbx` window, which runs the agent.

A `--clone` sandbox gets a second window, `shell`, which holds a plain shell
into the same sandbox (`sbx exec -it <name> -- bash -l`), for editing files or
running git commands without going through the agent. It runs `sbx-wait` first,
because the `dotfiles` kit configures the sandbox after it starts.

A sandbox that shares the host worktree gets no `shell` window: its files are
already on the host, where an ordinary window reaches them.

Both window names carry the branch as a suffix, unless the branch is the
default one.

`sbx-up` also runs `./sync-skills` before it starts the sandbox, so the
`agent-skills` kit ships the skills that are on disk at that moment.

Outside tmux, `sbx-up` runs the sandbox in the current terminal and opens no
shell window.

## Per-project settings

Drop a `.sbx.json` at the project root to choose the agent, the kits, the
memory limit, and whether the sandbox gets its own clone. Every key is
optional, and `sbx-up --help` lists them with their defaults.

Naming an agent on the command line overrides the file for one run:

```console
sbx-up local-pi
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

`$SBX_KIT_ARGS_FILE` names a different file. An agent kit given as a URL or a
zip is left alone, because the check reads the kit's spec from disk; supply its
arguments with `--kit-arg` by hand.

Only `local-pi` takes arguments today. Its README says what they mean.

## Pulling changes from a `--clone` sandbox

A `--clone` sandbox is a standalone git clone, so commits made inside it do not
reach the host until they are fetched. Run `sbx-pull` from the same project root
and branch that started the sandbox: it fetches from the sandbox's
`sandbox-<name>` remote and fast-forwards the current branch. Pass `--rebase`
when the branch has moved on the host as well.

The remote is served by the sandbox, so this only works while the sandbox still
runs.
