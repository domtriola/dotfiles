# Packages

Each directory here is one command that `sync-env` puts on PATH. A command is a
package when it works on this checkout, or when it outgrows one file.

| Command       | What it does                                                              |
| ------------- | ------------------------------------------------------------------------- |
| `setup`       | Runs the scripts in `setups/<profile>/`, in filename order.               |
| `sync-env`    | Copies the files that `setups/<profile>/env.manifest` lists into `$HOME`. |
| `doctor`      | Reports whether this machine matches what its profile intends.            |
| `pull-skills` | Vendors third-party agent skills into `env/.agents/skills/`.              |
| `sync-skills` | Copies the agent skills into the `agent-skills` kit.                      |
| `pull-nvim`   | Copies `~/.config/nvim` back into `env/.config/nvim`.                     |
| `sbx-up`      | Starts a Docker sandbox for the current project. See `sbx-up --help`.     |

## Layout

A package holds an entry point with the package's name. A package that
outgrows one file adds a `lib/` of one file per step that the entry point
sources, and a `libexec/` for a helper that another process runs instead.

```text
packages/sbx-up/
  sbx-up     # the entry point, and the whole of what a reader has to know
  lib/       # one file per step, sourced
  libexec/   # helpers that are run rather than sourced
```

A command that fits in one file and does not use the checkout lives in
`env/.local/bin` instead, and is copied with the `file` directive.

## Install

The `package` directive in a manifest installs one. The tree is copied to
`~/.local/lib/<name>`, and `~/.local/bin/<name>` becomes a symlink to the entry
point.

Because it is a copy, the command on PATH does not see an edit here until the
next `sync-env`. To try an edit before that, run the entry point from the
checkout, for example `packages/setup/setup --dry`.

## Finding the checkout

The commands that work on the checkout (all except `sbx-up`) look for it in
this order:

1. `$DOTFILES_DIR`.
2. The checkout that holds the file, when it is run from `packages/`.
3. The path in `~/.config/dotfiles/checkout`. `sync-env` writes it on every
   real run, so it names the checkout that the installed copies came from.

`sbx-up` finds the checkout in a different way. See `sbx-up --help`.
