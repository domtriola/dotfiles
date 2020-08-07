#!/bin/bash

set -eo pipefail

# HTTP
brew install wget || brew upgrade wget

# Images
# Installs the `magick` command
# Example usage: `magick ./image.heic ./image.jpeg`
brew install imagemagick || brew upgrade imagemagick

# JS
brew install node || brew upgrade node
brew install nvm || brew upgrade nvm

# Python
brew install pyenv || brew upgrade pyenv
brew install pipenv || brew upgrade pipenv

# Terraform
brew install terraform || brew upgrade terraform

# JSON
brew install jq || brew upgrade jq

# Terminal Workflow
brew install tmux || brew upgrade tmux
brew install tree || brew upgrade tree
brew install stow || brew upgrade stow

# Misc
# GNU core utilities; enter `info coreutils` to see all commands
brew install coreutils || brew upgrade coreutils
brew install cpulimit || brew upgrade cpulimit

# Future additions?
# brew cask install visual-studio-code || brew upgrade visual-studio-code
# brew cask install firefox || brew upgrade firefox
# brew cask install google-chrome || brew upgrade google-chrome
# brew cask install spotify || brew upgrade spotify
# brew cask install vlc || brew upgrade vlc
