# dotfiles

A mixin kit that clones this dotfiles repo into the sandbox and applies it, so a
sandbox shell looks like every other machine of mine.

## What it does

1. **Once, at creation, as root.** Installs `git` if the image does not have it.
   `git` is not part of the kit tool floor, and the clone below needs it.
2. **On every start, as the agent user.** Shallow-clones the repo to
   `~/src/personal/dotfiles` (or fetches into the existing clone), then runs
   `./sync-env` and `./setup` with the `sbx-linux` profile.

`sbx-linux` is the minimal profile: it copies the shell, tmux, nvim and git
configuration, and installs jq, fzf, ripgrep, tree, neovim, tmux and starship
with apt. It leaves `~/.claude` alone, because the sandbox runtime and the
`my-claude` kit own that.

## Settings

| Variable           | Default                                 | Meaning                     |
| ------------------ | --------------------------------------- | --------------------------- |
| `DOTFILES_REPO`    | `https://github.com/domtriola/dotfiles` | Clone source.               |
| `DOTFILES_REF`     | `main`                                  | Branch or tag to check out. |
| `DOTFILES_PROFILE` | `sbx-linux`                             | Profile the setup runs as.  |

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

## Notes

- **A failure stops the sandbox.** A sandbox that starts silently without the
  dotfiles is harder to diagnose than one that refuses to start.
- **Do not commit from the clone.** It is shallow, the checkout is detached,
  and every start resets it. Edit the dotfiles in their own project instead.
- Both `./sync-env` and `./setup` are idempotent, so a restart costs little:
  the packages are already there, and the files are copied again.

## Quick start

```console
sbx run claude --kit ./sbx/kits/mixins/dotfiles
```
