##################################
# CLI Defaults
##################################

# Enables colorization for ls
export CLICOLOR=1


##################################
# Aliases
##################################

# Core
########################
alias ll="ls -hal"

# Git
########################
alias g="git status"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset - %C(bold blue)<%an> %Cgreen(%cr)%C(yellow)%d%Creset %s %Creset' --abbrev-commit"


##################################
# Functions
##################################

# `addToPath` prepends a directory to $PATH if it exists and isn't already in $PATH
function addToPath() {
  [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"
}

# waitforinput blocks the process until any 1 character input is received
function waitforinput() {
  read -sr -n 1
}

# now prints the current time in the format YEAR-MON-DAY HOUR:MIN:SEC
function now() {
  date +"%Y-%m-%d %H:%M:%S"
}

function nowiso() {
  date +"%Y-%m-%dT%H:%M:%SZ"
}

function nowutc() {
  date -u +"%Y-%m-%d %H:%M:%S"
}

# timestamp prints the current Epoch time
function timestamp() {
  date +%s
}

# `recentmods n m` returns all files in n path that were modified within m days
# e.g. to find all documents modified within 10 days:
# recentmods ~/Documents 10
function recentmods() {
  find "$1" -type f -mtime -"$2" -exec ls -l {} \;
}


##################################
# Language Setups
##################################

# Rust
########################
source "$HOME/.cargo/env"

# JavaScript
########################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

##################################
# CLI Tools
##################################
# autojump
if [[ "$OSTYPE" == darwin* ]]; then
  [ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
else
  # Fedora
  [ -f /usr/share/autojump/autojump.zsh ] && . /usr/share/autojump/autojump.zsh
fi
# fzf fuzzy finder
source <(fzf --zsh)


##################################
# Custom binaries
##################################
addToPath "$HOME/.local/bin"


##################################
# Vi Mode
##################################
bindkey -v
KEYTIMEOUT=1

# Make backspace/delete behave predictably in vi insert mode.
# Without this, delete stops at boundary of insert buffer.
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^[[3~' delete-char


##################################
# Starship
# (Keep at bottom)
##################################
eval "$(starship init zsh)"

# Override Starship's zle-keymap-select to add cursor shape changes.
# Defined after starship init so it takes precedence.
# Calls `zle reset-prompt` to keep Starship's prompt redraw on mode switch.
#
# This also fixes recursive call conflict between vi mode and zle-keymap-select:
# `starship_zle-keymap-select-wrapped:1: maximum nested function level reached; increase FUNCNEST?`
# See issues linked in https://github.com/starship/starship/pull/6398 for more details.
zle-keymap-select() {
  case $KEYMAP in
    vicmd)      printf '\e[2 q' ;; # block cursor  — normal mode
    viins|main) printf '\e[6 q' ;; # beam cursor   — insert mode
  esac
  zle reset-prompt
}
zle -N zle-keymap-select

# Beam cursor on new prompt / after accepting a line
zle-line-init() { printf '\e[6 q' }
zle -N zle-line-init
