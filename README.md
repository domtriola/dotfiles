# My Dotfiles

- `env/` contains environment configurations. These are copied over to the system via `./sync-env`.
- `setups/` contains scripts that run tool installations or system configurations. Run them with `./setup`. To run just one tool, run `./setup toolname`.

Both commands can be ran as dry-runs: `./setup toolname --dry`

## Fresh System Setup

1. Install git:
    1. MacOS: `xcode-select --install`
    1. Linux: often included by default. If not, [install with distribution's package manager](https://git-scm.com/install/linux).
2. [Set up new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
3. Clone the repo: `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
4. Run the setup tools:
    1. `./sync-env`
    2. `./setup`

## Updates

Run `./sync-env` after updating anything in `env/`. Update `sync-env` first if you create a new file or directory.

Run `./setup` after updating anything in `setups/`.
