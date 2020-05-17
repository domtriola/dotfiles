for HELPER in `find ~/src/dotfiles/helpers`; do
  [ -f "$HELPER" ] && source "$HELPER"
done

for CUSTOM in `find ~/src/dotfiles/custom`; do
  [ -f "$CUSTOM" ] && source "$CUSTOM"
done
