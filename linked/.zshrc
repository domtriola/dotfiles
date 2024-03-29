##################################
# Custom scripts
##################################
for HELPER in `find ~/.dotfiles/helpers`; do
  [ -f "$HELPER" ] && source "$HELPER"
done

for CUSTOM in `find ~/.dotfiles/custom`; do
  [ -f "$CUSTOM" ] && source "$CUSTOM"
done


# JavaScript
##################################
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion


# Python
##################################
# pyenv
# From https://stackoverflow.com/questions/45577194/failed-to-activate-virtualenv-with-pyenv
# to fix not being able to activate virtualenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
# TODO: Use ifs for these commands for better cross-system fallback behavior
# if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
eval "$(pyenv virtualenv-init -)"


# Java
##################################
# jenv
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"


# CLI Tools
##################################
# autojump
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh


###############################################
# Starship
# (Keep at bottom)
###############################################
eval "$(starship init zsh)"
