# My Dotfiles

- `env` contains environment configurations. These are copied over to the system via `./dev-env`.
- `runs` contains scripts that run tool installations or system configurations. Run them with `./run`. To run just one tool, run `./run toolname`.

Both commands can be ran as dry-runs: `./run toolname --dry`

## Prerequisites

On a brand new system:

```sh
# Install xcode for git and make
xcode-select --install
```

[Set up new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Installation

Get dotfiles:

```bash
cd ~/ && git clone git@github.com:domtriola/dotfiles.git .dotfiles
```

Install:

```bash
cd ~/.dotfiles

./run --dry
./run

./dev-env --dry
./dev-env
```

## Updates

Run `./dev-env` after updating anything in `env`. Update `dev-env` first if you create a new file or directory.

Run `./run` after updating anything in `runs`.
