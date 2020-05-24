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
make links
echo "+++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "Initializing ~/.bash_profile"
source ~/.bash_profile

echo "Done!"
