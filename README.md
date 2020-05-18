# My Dotfiles

## Prerequisites

On a brand new system:

```bash
# Update
sudo softwareupdate -i

# Install xcode for git and make
xcode-select --install
```

[Set up new ssh key for GitHub](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

## Installation

Get dotfiles:

```bash
mkdir -p ~/src && cd ~/src && git clone git@github.com:domtriola/dotfiles.git
```

The script should make backups of any files it replaces, but you may want to create a manual backup anyway just in case:

```bash
mkdir -p ~/custom_dotfile_backup && cp ~/.bash_profile ~/custom_dotfile_backup
```

Install:

```bash
cd ~/src/dotfiles && make
```

## Updates

To add new configs to `~/.bash_profile`:

* Add new configurations to [helpers](helpers).
* Add system specific configurations to [custom](custom).
* `source ~/.bash_profile`

To save raw dotfiles add them to [linked_configs](linked_configs) and re-run `make install`.
