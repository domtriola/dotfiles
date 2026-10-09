# My Dotfiles

Dotfiles, commands, and setup steps that make a new machine ready for its profile.

## Fresh system setup

1. Install git
1. Clone these dotfiles:
   `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
1. Perform steps if any in `profiles/<profile>/bootstrap.md`
1. Run the commands from the checkout, naming the profile the first time:
   1. `./commands/sync-env/sync-env --profile <name>`
   2. `./commands/setup/setup`
1. Open a new shell. The commands are now on PATH, so later runs need no path.
1. Run `doctor` to verify final system state

## Updates

Run `sync-env` after a change to anything in `env/` or `commands/`. A new file, directory or command also needs a line in the `env.manifest` of every profile that wants it.

Before `sync-env` overwrites drift (a change in `$HOME` since the last sync), it shows the diff and asks. `sync-env --dry` and `doctor` show the drift without a change.

Run `setup` after a change to anything in `profiles/<profile>/`.

## Layout

| Path        | Contents                                                      |
| ----------- | ------------------------------------------------------------- |
| `env/`      | The files that are copied into `$HOME`.                       |
| `commands/` | The commands. See [commands/README.md](commands/README.md).   |
| `profiles/` | One directory per profile: its setup steps and manifest.      |
| `lib/`      | Shell functions the commands share.                           |
| `sbx/`      | Docker Sandbox kits. See [sbx/README.md](sbx/README.md).      |
| `docs/`     | Notes and reminders. See [Further reading](#further-reading). |

## Commands

[commands/README.md](commands/README.md) describes every command.

## Profiles

Every machine has a profile. A profile names what the machine is **for**, not
only which operating system it runs on. It decides which setup steps `setup`
runs and which dotfiles `sync-env` copies.

| Profile         | Machine                                      |
| --------------- | -------------------------------------------- |
| `dev-mac`       | macOS workstation                            |
| `dev-linux`     | Fedora dev box                               |
| `infosec-qubes` | Qubes appVM, minimal setup                   |
| `sbx-linux`     | Docker Sandbox, set up by the `dotfiles` kit |
| `ai-server`     | Headless model server, Ubuntu                |

Each profile owns a directory under `profiles/`:

```text
profiles/<profile>/
  env.manifest    # what sync-env copies
  bootstrap.md    # steps done by hand, if the profile has any
  00_preflight    # what setup runs, in filename order
  10_settings
  ...
  lib/            # code that is not a setup step
    doctor.sh     # the checks doctor runs, if the profile has any
```

`setup` never looks inside `lib/`, and skips files that are not executable.

Profiles share no setup steps. The same package can appear in more than one
profile, and that duplication is deliberate: every machine installs what its
use-case needs, and nothing else.

## Testing changes safely

- `--dry` prints what a command would do, and changes nothing.
- `--profile <name>` previews another machine's profile from this one. A dry run
  only warns about an OS mismatch, while a real run refuses it.
- To test a real sync without touching the real home directory, point `$HOME`
  somewhere disposable:

  ```console
  mkdir -p /tmp/fakehome && HOME=/tmp/fakehome ./commands/sync-env/sync-env
  ```

## Agent skills

`env/.agents/skills/` is the one source of truth for agent skills. Each imported skill holds a `LICENSE` that keeps the original copyright. For how
the skills fit together, see [Agent workflow](docs/agent-workflow.md).

These scripts move the skills:

| Command       | Where the skills go                             |
| ------------- | ----------------------------------------------- |
| `sync-env`    | Into `~/.claude/skills` and `~/.agents/skills`. |
| `sync-skills` | Into the `agent-skills` kit, for sandboxes.     |

Only the `dev-mac` and `dev-linux` manifests copy skills into `$HOME`. In a
sandbox the `agent-skills` kit delivers them instead, so the `sbx-linux`
manifest leaves them out.

`env/.agents/skills-local/` is an untracked scratch area. A skill there shadows
a tracked one of the same name, in `$HOME` and in a sandbox.

`.claude/skills/` holds skills that apply only to this repo, such as
`author-sbx-kit`. The scripts do not copy them. Claude Code loads them when it
runs in this repo.

## Further reading

- [docs/dev-workflow.md](docs/dev-workflow.md): the tmux project workflow.
- [docs/agent-workflow.md](docs/agent-workflow.md): how the agent skills fit together.
- [docs/design.md](docs/design.md): the design priorities and color rules for command output.
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md): where specs and tickets live (GitHub issues).
- [docs/research/](docs/research/): cited findings behind past decisions.
- [sbx/README.md](sbx/README.md): the Docker Sandboxes kits and the sandbox commands.
