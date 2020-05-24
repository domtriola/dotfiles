for HELPER in `find ~/.dotfiles/helpers`; do
  [ -f "$HELPER" ] && source "$HELPER"
done

for CUSTOM in `find ~/.dotfiles/custom`; do
  [ -f "$CUSTOM" ] && source "$CUSTOM"
done
