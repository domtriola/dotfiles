# My Dotfiles

- `env/` contains environment configurations. These are copied over to the system via `./sync-env`.
- `setups/` contains scripts that run tool installations or system configurations. Run them with `./setup`. To run just one tool, run `./setup toolname`.

Both commands can be ran as dry-runs: `./setup toolname --dry`

## Profiles

Every machine has a profile. A profile names what the machine is **for**, not just
which operating system it runs. It decides which scripts `./setup` runs and
which files `./sync-env` copies.

| Profile         | Machine                                      |
| --------------- | -------------------------------------------- |
| `dev-mac`       | macOS workstation                            |
| `dev-linux`     | Fedora dev box                               |
| `infosec-qubes` | Qubes appVM, minimal, installs nothing       |
| `sbx-linux`     | Docker Sandbox, set up by the `dotfiles` kit |

Each profile owns a directory under `setups/`:

```
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

With no `--profile` and no saved profile, a real run detects one and asks you to
confirm it. `$DOTFILES_PROFILE` overrides the saved profile for a single run,
and is never saved.

## Fresh Dev System Setup

1. Install git:
   1. MacOS: `xcode-select --install`
   1. Linux: often included by default. If not, [install with distribution's package manager](https://git-scm.com/install/linux).
2. [Set up new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
3. Clone the repo: `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
4. Run the setup tools, naming the profile the first time:
   1. `./sync-env --profile <name>`
   2. `./setup`

## Updates

Run `./sync-env` after updating anything in `env/`. If you create a new file or
directory, add it to the `env.manifest` of every profile that wants it first.

Run `./setup` after updating anything in `setups/<profile>/`.

### Testing a change safely

- `--dry` prints what either command would do, and changes nothing.
- `--profile <name>` previews another machine's profile from this one. A dry run
  only warns about an OS mismatch, while a real run refuses it.
- To test a real sync without touching your home directory, point `$HOME`
  somewhere disposable:

  ```console
  mkdir -p /tmp/fakehome && HOME=/tmp/fakehome ./sync-env
  ```

## Agent skills

`env/.agents/skills/` is the one source of truth for agent skills. Three scripts manage them:

| Script          | What it does                                                 |
| --------------- | ------------------------------------------------------------ |
| `./pull-skills` | Pulls vendored skills from `env/.agents/skills.json`         |
| `./sync-skills` | Copies skills into the `agent-skills` kit for sandboxes      |
| `./sync-env`    | Copies skills into `~/.claude/skills` and `~/.agents/skills` |

Vendored skills are pinned in `env/.agents/skills.lock`.

`env/.agents/skills-local/` is an untracked scratch area. A skill there shadows
a tracked one of the same name.
