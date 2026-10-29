# The standalone pnpm from profiles/agent-server/15_languages, and the tools
# that `pnpm add --global` installs next to it.
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
