# Checks for the dev-mac profile. Sourced by doctor, which supplies section,
# ok, warn, fail, pending and have.
#
# Each check asks whether a setup step or sync-env left a working result, not
# which packages it chose. macOS ships bash 3.2, so nothing here needs bash 4.

# ---------------------------------------------------------------------------
section "Toolchain"
# ---------------------------------------------------------------------------

if clt_path="$(xcode-select -p 2>/dev/null)"; then
  ok "command line tools" "$clt_path"
else
  fail "command line tools" "not installed, run setup 00_bootstrap"
fi

if have brew; then
  ok "homebrew" "$(brew --prefix)"
  # brew doctor exits non-zero for a warning as well as a fault, so a failure
  # here is a prompt to read its output rather than a broken machine.
  if brew doctor >/dev/null 2>&1; then
    ok "brew doctor" "no problems"
  else
    warn "brew doctor" "reports problems, run brew doctor"
  fi
else
  fail "homebrew" "not installed, run setup 00_bootstrap"
fi

# ---------------------------------------------------------------------------
section "Languages"
# ---------------------------------------------------------------------------

uv_bin="$(command -v uv 2>/dev/null || echo "$HOME/.local/bin/uv")"
if [[ -x "$uv_bin" ]]; then
  if python_bin="$("$uv_bin" python find 2>/dev/null)"; then
    ok "python" "$("$python_bin" --version 2>&1)"
  else
    fail "python" "uv has no Python installed, run setup 15_languages"
  fi
else
  fail "uv" "not installed, run setup 15_languages"
fi

# nvm is a shell function, so it is not loaded here. The installed versions
# are read from its directory instead.
node_versions="$(ls "${NVM_DIR:-$HOME/.nvm}/versions/node" 2>/dev/null | tr '\n' ' ')"
if [[ -n "$node_versions" ]]; then
  ok "node" "$node_versions"
else
  fail "node" "no version installed with nvm, run setup 15_languages"
fi

# ---------------------------------------------------------------------------
section "Claude Code policy"
# ---------------------------------------------------------------------------

policy_src="$profile_dir/lib/managed-settings.json"
policy_dest="/Library/Application Support/ClaudeCode/managed-settings.json"

if [[ ! -f "$policy_dest" ]]; then
  fail "managed settings" "missing, run setup 30_setup"
elif cmp -s "$policy_src" "$policy_dest"; then
  ok "managed settings" "matches the checkout"
else
  warn "managed settings" "differs from the checkout, run setup 30_setup"
fi

# ---------------------------------------------------------------------------
section "Environment"
# ---------------------------------------------------------------------------

if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  ok "PATH" "holds ~/.local/bin"
else
  fail "PATH" "does not hold ~/.local/bin, so the installed commands are not found"
fi

checkout_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/checkout"
recorded="$(cat "$checkout_file" 2>/dev/null || true)"
if [[ "$recorded" == "$dotfiles_dir" ]]; then
  ok "checkout" "$recorded"
elif [[ -z "$recorded" ]]; then
  fail "checkout" "not recorded, run sync-env"
else
  warn "checkout" "installed from $recorded, not $dotfiles_dir"
fi

# A package that differs from the checkout means an edit that sync-env has not
# installed yet.
while read -r directive name prefix _; do
  [[ "$directive" == "package" ]] || continue
  prefix="${prefix//\$HOME/$HOME}"

  if [[ ! -L "$prefix/bin/$name" || ! -d "$prefix/lib/$name" ]]; then
    fail "$name" "not installed, run sync-env"
  elif diff -rq "$dotfiles_dir/packages/$name" "$prefix/lib/$name" >/dev/null 2>&1; then
    ok "$name" "matches the checkout"
  else
    warn "$name" "differs from the checkout, run sync-env"
  fi
done <"$profile_dir/env.manifest"
