# Keypress
############

# Set KeyRepeat to fastest setting exposed by the settings UI
# (can be made faster here if desired - 0 is the fastest possible)
defaults write NSGlobalDomain KeyRepeat -int 2

# Finder
############

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Dock
############

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true
