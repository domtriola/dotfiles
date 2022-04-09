for HELPER in `find ~/.dotfiles/helpers`; do
  [ -f "$HELPER" ] && source "$HELPER"
done

for BASH_HELPER in `find ~/.dotfiles/helpers_bash`; do
  [ -f "$BASH_HELPER" ] && source "$BASH_HELPER"
done

for CUSTOM in `find ~/.dotfiles/custom`; do
  [ -f "$CUSTOM" ] && source "$CUSTOM"
done

# Initialize pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init --path)"
fi


# Python
##################################
# Enable virtualenv auto-activation
if which pyenv-virtualenv-init > /dev/null; then
  eval "$(pyenv virtualenv-init -)";
fi

# JavaScript
##################################
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Java
##################################
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

# CLI Tools
##################################
# Autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
