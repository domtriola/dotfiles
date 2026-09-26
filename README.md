# My Dotfiles

Environment configurations for quick set-up of a new machine.

## Fresh system setup

1. Install git
1. Clone these dotfiles:
   `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
1. Perform steps if any in `setups/<profile>/bootstrap.md`
1. Run the setup tools, naming the profile the first time:
   1. `./sync-env --profile <name>`
   2. `./setup`

## Updates

Run `./sync-env` after a change to anything in `env/` or `packages/`. A new file, directory or package also needs a line in the `env.manifest` of every profile that wants it.

Run `./setup` after a change to anything in `setups/<profile>/`.

## Layout

| Path        | Contents                                                      |
| ----------- | ------------------------------------------------------------- |
| `env/`      | The files that are copied into `$HOME`.                       |
| `packages/` | Scripts as deep modules. See [Packages](#packages).           |
| `setups/`   | One directory per profile, holding its scripts and manifest.  |
| `lib/`      | Shell functions the top-level scripts share.                  |
| `sbx/`      | Docker Sandbox kits. See [sbx/README.md](sbx/README.md).      |
| `docs/`     | Notes and reminders. See [Further reading](#further-reading). |

## Scripts

| Script          | What it does                                                              |
| --------------- | ------------------------------------------------------------------------- |
| `./setup`       | Runs the scripts in `setups/<profile>/`, in filename order.               |
| `./sync-env`    | Copies the files that `setups/<profile>/env.manifest` lists into `$HOME`. |
| `./pull-skills` | Vendors third-party agent skills into `env/.agents/skills/`.              |
| `./sync-skills` | Copies the agent skills into the `agent-skills` kit.                      |
| `./pull-nvim`   | Copies `~/.config/nvim` back into `env/.config/nvim`.                     |
| `./doctor`      | Reports whether this machine matches what its profile intends.            |

## Packages

A command that outgrows one file becomes a package under `packages/`: an entry
point, a `lib/` of one file per step that the entry point sources, and a
`libexec/` for a helper that another process runs instead.

```text
packages/sbx-up/
  sbx-up     # the entry point, and the whole of what a reader has to know
  lib/       # one file per step, sourced
  libexec/   # helpers that are run rather than sourced
```

The `package` directive in a manifest installs one. The tree goes to
`~/.local/lib/<name>`, and `~/.local/bin/<name>` becomes a symlink to the entry
point, which resolves that symlink to find its own `lib/`.

A command that still fits in one file lives in `env/.local/bin` instead, and is
copied with the `file` directive.

## Profiles

Every machine has a profile. A profile names what the machine is **for**, not
only which operating system it runs on. It decides which scripts `./setup` runs
and which files `./sync-env` copies.

| Profile         | Machine                                      |
| --------------- | -------------------------------------------- |
| `dev-mac`       | macOS workstation                            |
| `dev-linux`     | Fedora dev box                               |
| `infosec-qubes` | Qubes appVM, minimal setup                   |
| `sbx-linux`     | Docker Sandbox, set up by the `dotfiles` kit |
| `ai-server`     | Headless model server, Ubuntu                |

Each profile owns a directory under `setups/`:

```text
setups/<profile>/
  env.manifest    # what ./sync-env copies
  bootstrap.md    # steps done by hand, if the profile has any
  00_bootstrap    # what ./setup runs, in filename order
  10_settings
  ...
  lib/            # code that is not a setup step
    doctor.sh     # the checks ./doctor runs, if the profile has any
```

`./setup` never looks inside `lib/`, and skips files that are not executable.

Profiles share no scripts. The same tool can appear in more than one profile,
and that duplication is deliberate: every machine installs what its use-case
needs, and nothing else.

## Testing changes safely

- `--dry` prints what a command would do, and changes nothing.
- `--profile <name>` previews another machine's profile from this one. A dry run
  only warns about an OS mismatch, while a real run refuses it.
- To test a real sync without touching the real home directory, point `$HOME`
  somewhere disposable:

  ```console
  mkdir -p /tmp/fakehome && HOME=/tmp/fakehome ./sync-env
  ```

## Agent skills

`env/.agents/skills/` is the one source of truth for agent skills. Skills are
authored there, on the host. These scripts move them:

| Script          | Where the skills go                                                          |
| --------------- | ---------------------------------------------------------------------------- |
| `./pull-skills` | Into `env/.agents/skills/`, from the upstreams in `env/.agents/skills.json`. |
| `./sync-env`    | Into `~/.claude/skills` and `~/.agents/skills`.                              |
| `./sync-skills` | Into the `agent-skills` kit, for sandboxes.                                  |

Vendored skills are pinned in `env/.agents/skills.lock`, which `./pull-skills`
generates. A vendored skill that was edited locally stops the next pull, rather
than being discarded.

Only the `dev-mac` and `dev-linux` manifests copy skills into `$HOME`. In a
sandbox the `agent-skills` kit delivers them instead, so the `sbx-linux`
manifest leaves them out.

`env/.agents/skills-local/` is an untracked scratch area. A skill there shadows
a tracked one of the same name, in `$HOME` and in a sandbox.

## Further reading

- [docs/dev_workflow.md](docs/dev_workflow.md): the tmux project workflow.
- [sbx/README.md](sbx/README.md): the Docker Sandboxes kits and helper commands.
