# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# User specific environment and startup programs
####################################################

##################################
# CLI Defaults
##################################

# Enables colorization for ls
export CLICOLOR=1

##################################
# Language Setups
##################################

# Rust
########################
source "$HOME/.cargo/env"

# JavaScript
########################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

##################################
# Custom binaries
##################################
addToPath "$HOME/.local/bin"

##################################
# Starship
# (Keep at bottom)
##################################
eval "$(starship init bash)"
