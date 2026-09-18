# Dotfiles

Environment configurations for quick set-up of a new machine.

## Layout

| Path      | Contents                                                      |
| --------- | ------------------------------------------------------------- |
| `env/`    | The files that are copied into `$HOME`.                       |
| `setups/` | One directory per profile, holding its scripts and manifest.  |
| `sbx/`    | Docker Sandbox kits. See [sbx/README.md](sbx/README.md).      |
| `docs/`   | Notes and reminders. See [Further reading](#further-reading). |

## Scripts

| Script          | What it does                                                              |
| --------------- | ------------------------------------------------------------------------- |
| `./setup`       | Runs the scripts in `setups/<profile>/`, in filename order.               |
| `./sync-env`    | Copies the files that `setups/<profile>/env.manifest` lists into `$HOME`. |
| `./pull-skills` | Vendors third-party agent skills into `env/.agents/skills/`.              |
| `./sync-skills` | Copies the agent skills into the `agent-skills` kit.                      |
| `./pull-nvim`   | Copies `~/.config/nvim` back into `env/.config/nvim`.                     |

`./setup` also accepts a pattern to run only scripts that match:

```console
./setup packages
```

Every script accepts `--dry`, which prints the actions and changes nothing.

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

Each profile owns a directory under `setups/`:

```text
setups/dev-mac/
  env.manifest    # what ./sync-env copies
  00_bootstrap    # what ./setup runs, in filename order
  10_settings
  ...
```

Profiles share no scripts. The same tool can appear in more than one profile,
and that duplication is deliberate: every machine installs what its use-case
needs, and nothing else.

### Choosing the profile

Name the profile once. It is saved to
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile` and reused after that:

```console
./setup --profile dev-mac
```

With no `--profile` and no saved profile, a real run detects one and asks for
confirmation. `$DOTFILES_PROFILE` overrides the saved profile for a single run,
and is never saved.

## Fresh dev system setup

1. Install git:
   1. macOS: `xcode-select --install`
   2. Linux: often included by default. If not,
      [install it with the distribution's package manager](https://git-scm.com/install/linux).
2. [Set up a new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
3. Clone the repo:
   `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
4. Run the setup tools, naming the profile the first time:
   1. `./sync-env --profile <name>`
   2. `./setup`

Some steps cannot or have not be scripted. See [docs/manual_steps.md](docs/manual_steps.md).

## Updates

Run `./sync-env` after a change to anything in `env/`. A new file or directory
also needs a line in the `env.manifest` of every profile that wants it.

Run `./setup` after a change to anything in `setups/<profile>/`.

### Testing a change safely

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
authored there, on the host. Three scripts move them:

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
- [docs/manual_steps.md](docs/manual_steps.md): setup steps that haven't been automated.
- [docs/app_configs/README.md](docs/app_configs/README.md): installation notes for GUI applications.
- [sbx/README.md](sbx/README.md): the Docker Sandboxes kits and helper commands.
