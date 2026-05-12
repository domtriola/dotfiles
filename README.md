# My Dotfiles

- `env` contains environment configurations. These are copied over to the system via `./dev-env`.
- `runs` contains scripts that run tool installations or system configurations. Run them with `./run`. To run just one tool, run `./run toolname`.

Both commands can be ran as dry-runs: `./run toolname --dry`

## Fresh System Setup

1. Install git:
    1. MacOS: `xcode-select --install`
    1. Linux: often included by default. If not, [install with distribution's package manager](https://git-scm.com/install/linux).
2. [Set up new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
3. Clone the repo: `cd ~/src/personal && git clone git@github.com:domtriola/dotfiles.git && cd dotfiles`
4. Run the setup tools:
    1. `./dev-env`
    2. `./run`

## Updates

Run `./dev-env` after updating anything in `env`. Update `dev-env` first if you create a new file or directory.

Run `./run` after updating anything in `runs`.
