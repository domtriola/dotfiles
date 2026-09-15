# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# Docker Sandbox: the runtime keeps its environment in this file and expects
# every shell to load it. This file replaces the one the sandbox ships, so it
# has to keep that behaviour. Never source completion scripts from there: they
# break every later command.
if [ -f /etc/sandbox-persistent.sh ]; then
  . /etc/sandbox-persistent.sh
  export BASH_ENV=/etc/sandbox-persistent.sh
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc
