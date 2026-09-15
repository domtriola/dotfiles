# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# Environment file for Docker Sandbox
# https://docs.docker.com/ai/sandboxes/customize/kit-examples/#customize-the-shell-environment
# Never source completion scripts from sandbox-persistent.sh: they break every later command.
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
