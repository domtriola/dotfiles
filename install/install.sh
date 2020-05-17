#!/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Set MacOS defaults
source $DIR/macos_settings.sh

# Install Brew & Cask
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap caskroom/cask
brew tap caskroom/versions

# Create config symlinks
for CONFIG in `find ~/src/dotfiles/linked_configs`; do
  [ -f "$CONFIG" ] && ln -sv "$CONFIG" ~/
done

source ~/.bash_profile
