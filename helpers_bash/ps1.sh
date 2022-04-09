# Modified from:
# https://coderwall.com/p/pn8f0g/show-your-git-status-and-branch-in-color-at-the-command-prompt
# https://gist.github.com/frnhr/dba7261bcb6970cf6121

COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_GREEN="\033[0;32m"
COLOR_OCHRE="\033[38;5;95m"
COLOR_RESET="\033[0m"

function git_color {
  local git_status="$(git status 2>/dev/null)"

  if [[ ! $git_status =~ "working tree clean" ]]; then
    echo -e $COLOR_RED
  elif [[ $git_status =~ "Your branch is ahead of" ]]; then
    echo -e $COLOR_YELLOW
  elif [[ $git_status =~ "nothing to commit" ]]; then
    echo -e $COLOR_GREEN
  else
    echo -e $COLOR_OCHRE
  fi
}

function git_branch {
  local git_status="$(git status 2>/dev/null)"
  local on_branch="On branch ([^[:space:]]*)"
  local on_commit="HEAD detached at ([^[:space:]]*)"

  if [[ $git_status =~ $on_branch ]]; then
    local branch=${BASH_REMATCH[1]}
    echo "$branch"
  elif [[ $git_status =~ $on_commit ]]; then
    local commit=${BASH_REMATCH[1]}
    echo "$commit"
  fi
}

function pyenv_color {
  local global_name="$(pyenv global)"
  local venv_name="$(pyenv version-name)"

  # non-global version
  color="$COLOR_GREEN"

  # global version
  [[ $venv_name == $global_name ]] && color="$COLOR_OCHRE"

  echo -e $color
}

function pyenv_name {
  echo "$(pyenv version-name)"
}

# Initialize
PS1=""

# Pyenv indicator
if [ -n "$COLORIZE_PYENV_PROMPT" ]; then
  export PYENV_VIRTUALENV_DISABLE_PROMPT=1
  PS1+="\[\$(pyenv_color)\]"
  PS1+="(\$(pyenv_name))"
  PS1+="\[$COLOR_RESET\]"
  PS1+=" "
fi

# User and directory info
PS1+="\h:\W"
PS1+=" "

# Git indicator
PS1+="\[\$(git_color)\]"
PS1+="(\$(git_branch))"
PS1+="\[$COLOR_RESET\]"

# Suffix
PS1+="\$ "

export PS1
