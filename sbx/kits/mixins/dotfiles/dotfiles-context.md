My dotfiles are cloned to ~/src/personal/dotfiles and applied on every
sandbox start, with the `sbx-linux` profile ($DOTFILES_PROFILE).

- `sync-env` copies the files listed in
  `profiles/sbx-linux/env.manifest` into $HOME.
- `setup` runs the setup steps in `profiles/sbx-linux/`, which install a small
  CLI set with apt.
- All of this runs in the background while you start, so for about the
  first twenty seconds the dotfiles and these tools may not be there yet.
  Until `~/.dotfiles-kit.status` reads `ready`, the kit is still working.
- The nvim plugins are then installed in the background. Until
  `~/.dotfiles-kit.nvim-status` reads `ready`, the install is not complete.

The state of the last start is in `~/.dotfiles-kit.log` and
`~/.dotfiles-kit.status`.

The checkout is shallow and detached, and it is replaced on every start.
Do not commit from it.
