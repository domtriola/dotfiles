# Commands

Each directory here is one command that `sync-env` puts on PATH. A command lives
here when it works on this checkout, or when it outgrows one file.

| Command       | What it does                                                                |
| ------------- | --------------------------------------------------------------------------- |
| `setup`       | Runs the setup steps in `profiles/<profile>/`, in filename order.           |
| `sync-env`    | Copies the files that `profiles/<profile>/env.manifest` lists into `$HOME`. |
| `doctor`      | Reports whether this machine matches what its profile intends.              |
| `sync-skills` | Copies the agent skills into the `agent-skills` kit.                        |
| `pull-nvim`   | Copies `~/.config/nvim` back into `env/.config/nvim`.                       |
| `sbx-up`      | Starts a Docker sandbox for the current project. See `sbx-up --help`.       |
| `sbx-shell`   | Opens a shell into a sandbox. See `sbx-shell --help`.                       |
| `sbx-token`   | Gives a sandbox a GitHub token for its repositories only. See `--help`.     |

## Layout

A command directory holds an entry point with the command's name. A command
that outgrows one file adds a `lib/` of one file per step that the entry point
sources, and a `libexec/` for a helper that another process runs instead.

```text
commands/<name>/
  <name>     # the entry point, and the whole of what a reader has to know
  lib/       # one file per step, sourced
  libexec/   # helpers that are run rather than sourced
```

A command that fits in one file and does not use the checkout lives in
`env/.local/bin` instead, and is copied with the `file` directive.

## Install

The `command` directive in a manifest installs one. The tree is copied to
`~/.local/lib/<name>`, and `~/.local/bin/<name>` becomes a symlink to the entry
point.

Because it is a copy, the command on PATH does not see an edit here until the
next `sync-env`. To try an edit before that, run the entry point from the
checkout, for example `commands/setup/setup --dry`.

## Finding the checkout

The commands that work on the checkout (all except the `sbx-` ones) look for
it in this order:

1. `$DOTFILES_DIR`.
2. The checkout that holds the file, when it is run from `commands/`.
3. The path in `~/.config/dotfiles/checkout`. `sync-env` writes it on every
   real run, so it names the checkout that the installed copies came from.

`sbx-up` finds the checkout in a different way. See `sbx-up --help`.

`sbx-shell`'s `sbx-wait` reads only the output style (`lib/style.sh`) from the
checkout, in the same order. Without a checkout, it prints its results without
color.

## Tests

The tests in `tests/` run each command through its command line, with fakes
for `sbx`, `tmux`, the GitHub API, the OS secret stores and `gh` first on
PATH. Run them with `./test` from the checkout root. Arguments go to bats,
for example `./test tests/sbx-token.bats` or `./test --filter mint`.
