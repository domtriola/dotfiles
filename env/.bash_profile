# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# User specific environment and startup programs
####################################################

# Hand it off to zsh:
# This is a workaround for systems with non-persistent /etc configs
# So instead of overriding the shell with chsh, just redirect to zsh
# at runtime:
if [ -z "${ZSH_VERSION:-}" ] && [ -x /usr/bin/zsh ]; then
  exec /usr/bin/zsh -l
fi
