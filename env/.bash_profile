# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# User specific environment and startup programs
####################################################

##################################
# Security
##################################
command -v tirith >/dev/null && eval "$(tirith init --shell bash)"

##################################
# CLI Defaults
##################################

export EDITOR=vim
# Enables colorization for ls
export CLICOLOR=1

##################################
# Language Setups
##################################

# Go
########################
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/home/user/go/bin

# JavaScript
########################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

##################################
# Starship
# (Keep at bottom)
##################################
command -v starship >/dev/null && eval "$(starship init bash)"
