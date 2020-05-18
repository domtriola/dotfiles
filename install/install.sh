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
source $DIR/tools.sh
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Linking dotfiles"
BACKUP=`date +"%Y-%m-%d_%H-%M-%S"`
mkdir -p ~/$BACKUPS_DIR/$BACKUP
for CONFIG in `find ~/src/dotfiles/linked_configs`; do
  FILENAME=`basename $CONFIG`
  [ -f ~/"$FILENAME" ] && \
    cp -r ~/"$FILENAME" ~/$BACKUPS_DIR/$BACKUP && \
    echo "backup created: ~/$BACKUPS_DIR/$BACKUP/$FILENAME"

  [ -f "$CONFIG" ] && ln -sfv "$CONFIG" ~/
done
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Initializing ~/.bash_profile"
source ~/.bash_profile

echo "Done!"
