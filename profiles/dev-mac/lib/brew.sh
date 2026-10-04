#!/usr/bin/env bash
#
# Homebrew helpers shared by the dev-mac scripts.

# Install a package unless it is already present.
#
# brew install can exit non-zero for a package that is already up to date,
# which would stop a set -e script on every re-run. brew list covers both
# formulae and casks, and exits non-zero only when the package is missing.
#
# Usage: brew_install [--cask] <name>
brew_install() {
  local name="${*: -1}"

  # brew list wants the bare name: docker/tap/sbx -> sbx
  name="${name##*/}"

  if brew list "$name" &>/dev/null; then
    echo "Already installed: $name"
    return
  fi

  brew install "$@"
}

# Trust a third-party tap, which Homebrew 6 needs before it will evaluate the
# tap's Ruby. Call it before any install from that tap.
# See https://docs.brew.sh/Tap-Trust
brew_trust() {
  brew trust "$1" 2>/dev/null || true
}
