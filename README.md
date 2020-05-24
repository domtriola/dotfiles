# My Dotfiles

Dotfiles are linked from [linked](linked). Bash configs (aliases, functions, path extensions, etc.) are found in [helpers](helpers). Custom bash configs that should not be shared with other devices are stored in [custom](custom).

* Fresh install: `make`
* Update packages: `make update`
* Install tools: `make tools`
* Update symlinks: `make links`

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
cd ~/ && git clone git@github.com:domtriola/dotfiles.git .dotfiles
```

Stow will not overwrite any existing files, so move all existing files to a backup folder:

```bash
BACKUPS_DIR="dotfile_backups"
BACKUP=`date +"%Y-%m-%d_%H-%M-%S"`
mkdir -p ~/$BACKUPS_DIR/$BACKUP
mv ~/.bash_profile ~/.aws/config ~/$BACKUPS_DIR/$BACKUP
```

Install:

```bash
cd ~/.dotfiles && make
```

## Updates

### Bash Configs

To add new configs to `~/.bash_profile`:

* Add new configurations to [helpers](helpers).
* Add system specific configurations to [custom](custom).
* `source ~/.bash_profile`

### Linked Dotfiles

To save raw dotfiles add them to [linked](linked) run `make link`.
