# dotfiles

A mixin kit that clones this dotfiles repo into the sandbox and applies it, so a
sandbox shell looks like every other machine of mine.

## What it does

1. **Once, at creation, as root.** Installs `git` if the image does not have it.
   `git` is not part of the kit tool floor, and the clone below needs it.
2. **On every start, as the agent user.** Shallow-clones the repo to
   `~/src/personal/dotfiles` (or fetches into the existing clone), then runs
   `./sync-env` and `./setup` with the `sbx-linux` profile.
3. **In the background, after step 2.** Installs the nvim plugins.

`sbx-linux` is the minimal profile: it copies the shell, tmux, nvim and git
configuration, and installs jq, fzf, ripgrep, tree, neovim, tmux, starship and
gcc with apt. (`gcc` is for nvim-treesitter, which compiles every parser it
installs; the image ships no compiler.) It leaves `~/.claude` alone, because
the sandbox runtime and the `my-claude` kit own that.

## The nvim plugins

LazyVim clones about forty plugins, roughly 370 MB, the first time nvim starts.
The kit does that itself so the first real nvim start is not a multi-minute
wait, and it does it in the background so nothing waits for it either: the
ready sentinel is written first, so the shell window waits only for the
packages.

`~/.dotfiles-kit.nvim-status` reads `installing the nvim plugins` until it
reads `ready` or `failed`, and `sbx-wait` repeats that when it is not ready
yet. An nvim opened during the warm-up still works, but it competes with the
background install for the same plugin directory, so it is worth the wait.

Set `DOTFILES_NVIM_PREWARM=0` in `spec.yaml` to skip it.

LSP servers and formatters are a separate matter: mason.nvim fetches those from
npm, PyPI and the Go module proxy, none of which the network policy below
allows. They fail, and nothing else is affected.

## Settings

| Variable                | Default                                 | Meaning                              |
| ----------------------- | --------------------------------------- | ------------------------------------ |
| `DOTFILES_REPO`         | `https://github.com/domtriola/dotfiles` | Clone source.                        |
| `DOTFILES_REF`          | `main`                                  | Branch or tag to check out.          |
| `DOTFILES_PROFILE`      | `sbx-linux`                             | Profile the setup runs as.           |
| `DOTFILES_NVIM_PREWARM` | `1`                                     | Set to `0` to skip the nvim warm-up. |

A raw commit SHA does not work as `DOTFILES_REF`: the clone is shallow, and
`--branch` takes a branch or a tag.

## Testing a branch before it merges

The kit is loaded from this working tree, so change `DOTFILES_REF` in
`spec.yaml` and start a sandbox:

```console
sbx run ./sbx/kits/sandboxes/my-claude --kit ./sbx/kits/mixins/dotfiles
```

## Network

The kit allows only what it uses: `github.com` for the clone, and the Ubuntu
mirrors for apt. The mirror differs by architecture, so all three are listed
(`ports.ubuntu.com` serves arm64, `archive.ubuntu.com` and
`security.ubuntu.com` serve amd64).

## Knowing when it has finished

The hook takes about twenty seconds: a clone, then roughly 150 MB of packages.
A shell opened before it finishes has the dotfiles but not yet the tools.

Four files under `$HOME` report the state:

| File                          | Meaning                                               |
| ----------------------------- | ----------------------------------------------------- |
| `~/.dotfiles-kit.log`         | Everything the hook printed. Rewritten on each start. |
| `~/.dotfiles-kit.status`      | The current step, then `ready` or `failed`.           |
| `~/.dotfiles-kit.done`        | Written only after the last step succeeds.            |
| `~/.dotfiles-kit.nvim-status` | The background plugin install, with its own `ready`.  |

The status file exists so that a wait is not a blank screen: `sbx-wait` polls it
and names the step it is waiting on, and stops early on `failed` rather than
running out its timeout. The step names are short phrases meant to be read in
a progress line, not parsed.

To check by hand, use the absolute path, since a `~` in an `sbx exec` command is
expanded by the host shell and never reaches the container:

```console
sbx exec <name> -- cat /home/agent/.dotfiles-kit.log
sbx exec <name> -- cat /home/agent/.dotfiles-kit.nvim.log
```

## Notes

- **A failure does not stop the sandbox.** The engine starts it anyway, so the
  hook has to leave its own evidence: the log, and `failed` in the status file.
  `sbx-wait` reads both and prints the end of the log rather than opening a
  shell on a silently unconfigured sandbox.
- **Do not commit from the clone.** It is shallow, the checkout is detached,
  and every start resets it. Edit the dotfiles in their own project instead.
- Both `./sync-env` and `./setup` are idempotent, so a restart costs little:
  the packages are already there, and the files are copied again.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/dotfiles
```
