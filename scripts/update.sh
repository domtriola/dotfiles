#!/bin/bash

set -eo pipefail

# Update App Store apps
sudo softwareupdate -i

# Update Homebrew (Cask) & packages
brew update
brew upgrade

# Update npm & packages
npm install npm -g
npm update -g
