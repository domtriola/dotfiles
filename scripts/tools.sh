#!/bin/bash

set -eo pipefail

# HTTP
brew install wget || brew upgrade wget

# Images
brew install imagemagick || brew upgrade imagemagick

# JS
brew install node || brew upgrade node
brew install nvm || brew upgrade nvm

# Python
brew install pyenv || brew upgrade pyenv

# Terraform
brew install terraform || brew upgrade terraform

# JSON
brew install jq || brew upgrade jq

# Terminal Workflow
brew install tmux || brew upgrade tmux
brew install tree || brew upgrade tree
brew install stow || brew upgrade stow

# Future additions?
# brew cask install visual-studio-code || brew upgrade visual-studio-code
# brew cask install firefox || brew upgrade firefox
# brew cask install google-chrome || brew upgrade google-chrome
# brew cask install spotify || brew upgrade spotify
# brew cask install vlc || brew upgrade vlc
