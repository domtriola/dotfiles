#!/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BACKUPS_DIR="dotfile_backups"

echo "Setting MacOS defaults"
source $DIR/macos_settings.sh
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Installing tools"
make tools
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Linking dotfiles"

BACKUP=`date +"%Y-%m-%d_%H-%M-%S"`
mkdir -p ~/$BACKUPS_DIR/$BACKUP

create_symlinks() {
  path="${1}"

  for CONFIG in `find $path -depth 1`; do
    FILENAME=`basename $CONFIG`
    [ -f ~/"$FILENAME" ] || [ -d ~/"$FILENAME" ] && \
      cp -r ~/"$FILENAME" ~/$BACKUPS_DIR/$BACKUP && \
      echo "backup created: ~/$BACKUPS_DIR/$BACKUP/$FILENAME"

    [ -f "$CONFIG" ] && ln -sfv "$CONFIG" ~/
    [ -d "$CONFIG" ] && ln -sFiv "$CONFIG" ~/
  done
}

create_symlinks ~/src/dotfiles/linked_configs
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Initializing ~/.bash_profile"
source ~/.bash_profile

echo "Done!"
