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
brew install pyenv-virtualenv || brew upgrade pyenv-virtualenv

# Java
brew install jenv || brew upgrade jenv
brew install maven || brew upgrade maven

# JSON
brew install jq || brew upgrade jq

# Terminal Workflow
brew install starship || brew upgrade starship
brew install tmux || brew upgrade tmux
brew install tree || brew upgrade tree
brew install stow || brew upgrade stow
brew install autojump || brew upgrade autojump
brew install ripgrep || brew upgrade ripgrep

# Performance Profiling
brew install cpulimit || brew upgrade cpulimit
brew install graphviz || brew upgrade graphviz

# Misc
# GNU core utilities; enter `info coreutils` to see all commands
brew install coreutils || brew upgrade coreutils
# Needed for matplotlib
brew install libmagic || brew upgrade libmagic
# "Pretty Good Privacy" tools
# https://gnupg.org/documentation/guides.html
brew install gnupg || brew upgrade gnupg
