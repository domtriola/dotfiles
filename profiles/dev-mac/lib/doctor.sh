# Checks for the dev-mac profile. Sourced by doctor, which supplies section,
# ok, warn, fail, pending, tunable and have.
#
# Each check asks whether a setup step or sync-env left a working result, not
# which packages it chose. macOS ships bash 3.2, so nothing here needs bash 4.

# ---------------------------------------------------------------------------
section "Toolchain"
# ---------------------------------------------------------------------------

if clt_path="$(xcode-select -p 2>/dev/null)"; then
  ok "command line tools" "$clt_path"
else
  fail "command line tools" "not installed, run setup 00_preflight"
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
  fail "homebrew" "not installed, run setup 00_preflight"
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
  fail "managed settings" "missing, run setup 30_tools"
elif cmp -s "$policy_src" "$policy_dest"; then
  ok "managed settings" "matches the checkout"
else
  warn "managed settings" "differs from the checkout, run setup 30_tools"
fi

# ---------------------------------------------------------------------------
section "SSH key"
# ---------------------------------------------------------------------------

# Columns: Key Type, Public Key Hash, Prot, Label. A key with none protection
# (SSH_KEY_PROT=none) can be used by any process without Touch ID. It is a
# known failure until a YubiKey replaces it.
key_prot="$(sc_auth list-ctk-identities 2>/dev/null | awk '$4 == "ssh" { print $3 }')"
if [[ -z "$key_prot" ]]; then
  fail "secure enclave key" "missing, run setup 40_ssh_key"
elif [[ "$key_prot" == "bio" ]]; then
  ok "secure enclave key" "present, needs Touch ID"
elif [[ "$key_prot" == "none" ]]; then
  fail "secure enclave key" "present, but has no Touch ID, so any process can use it"
else
  fail "secure enclave key" "not a single key with bio or none protection, see sc_auth list-ctk-identities"
fi

if [[ -f "$HOME/.ssh/id_ecdsa_sk" && -f "$HOME/.ssh/id_ecdsa_sk.pub" ]]; then
  ok "key reference" "$HOME/.ssh/id_ecdsa_sk"
else
  fail "key reference" "missing, run setup 40_ssh_key"
fi

if [[ "$(git config --global gpg.format 2>/dev/null)" == "ssh" &&
  "$(git config --global user.signingkey 2>/dev/null)" == "$HOME/.ssh/id_ecdsa_sk" ]]; then
  ok "git signing" "secure enclave key"
else
  fail "git signing" "not set to the secure enclave key, run setup 40_ssh_key"
fi

# ssh -G prints the config that ssh uses for a host, after every Include and
# Match, so this reads the result and not the file. ssh stops trying its
# default key files as soon as any IdentityFile is set.
ssh_effective="$(ssh -G github.com 2>/dev/null || true)"
if grep -qE "^identityfile (~|$HOME)/\.ssh/id_ecdsa_sk$" <<<"$ssh_effective"; then
  ok "ssh config" "offers the secure enclave key"
else
  fail "ssh config" "does not offer ~/.ssh/id_ecdsa_sk, run setup 40_ssh_key"
fi

# macOS asks the terminal for "access data from other apps" each time a
# process opens a socket in another app's container.
if [[ "${SSH_AUTH_SOCK:-}" == "$HOME/Library/Containers/"* ]]; then
  warn "SSH_AUTH_SOCK" "points into an app container: $SSH_AUTH_SOCK"
fi
identity_agent="$(awk '$1 == "identityagent" { print $2 }' <<<"$ssh_effective")"
if [[ "$identity_agent" == *"/Library/Containers/"* ]]; then
  warn "ssh IdentityAgent" "points into an app container: $identity_agent"
fi

# A private key file on disk can be read by any process that runs as you,
# without Touch ID.
for old_key in id_rsa id_ecdsa id_ed25519 id_dsa; do
  if [[ -f "$HOME/.ssh/$old_key" ]]; then
    warn "old ssh key" "~/.ssh/$old_key is a private key on disk, remove it from GitHub and delete it"
  fi
done

# ---------------------------------------------------------------------------
section "GitHub CLI"
# ---------------------------------------------------------------------------

if have gh; then
  if [[ "$(gh config get git_protocol 2>/dev/null)" == "ssh" ]]; then
    ok "gh git protocol" "ssh"
  else
    fail "gh git protocol" "not ssh, run setup 30_tools"
  fi

  # Any process that runs as you can read the stored token, so it must be a
  # fine-grained token with small permissions. Other token types (gho_, ghp_)
  # can have access to every repository.
  gh_token="$(gh auth token 2>/dev/null || true)"
  if [[ -z "$gh_token" ]]; then
    pending "gh token" "none stored, see bootstrap.md"
  elif [[ "$gh_token" == github_pat_* ]]; then
    ok "gh token" "fine-grained"
  else
    warn "gh token" "not fine-grained, run gh auth logout and see bootstrap.md"
  fi
  unset gh_token
fi

# ---------------------------------------------------------------------------
section "Sandbox GitHub tokens"
# ---------------------------------------------------------------------------

if have sbx-token; then
  token_args=()
  [[ "$doctor_offline" == "1" ]] && token_args=(--offline)
  token_status=0
  token_out="$(sbx-token check ${token_args[@]+"${token_args[@]}"} 2>&1)" || token_status=$?
  token_out="${token_out#sbx-token: }"
  case "$token_status" in
  0) ok "sandbox token App" "$token_out" ;;
  3) pending "sandbox token App" "not set up, see bootstrap.md" ;;
  4) warn "sandbox token App" "$token_out" ;;
  *) fail "sandbox token App" "$token_out" ;;
  esac
  # The accounts that the App is installed on, for the kamaji section. Only an
  # online check names them.
  token_installs=""
  if [[ "$token_status" == "0" && "$token_out" == *", installed on "* ]]; then
    token_installs="${token_out#*, installed on }"
    token_installs="${token_installs%% (*}"
  fi
  unset token_args token_status token_out
else
  fail "sbx-token" "not installed, run sync-env"
fi

# A sandbox-scoped secret overrides a global one, so a global github secret
# reaches every sandbox that has no token of its own: those started with
# sbx-up --no-gh, and those started with sbx run.
if have sbx; then
  if [[ -n "$(sbx secret ls --global --service github --quiet 2>/dev/null)" ]]; then
    warn "global github secret" "reaches every sandbox without its own token, run sbx secret rm github"
  else
    ok "global github secret" "none"
  fi

  if [[ "$(sbx settings get claude.remoteControl 2>/dev/null)" == "true" ]]; then
    ok "remote control" "on"
  else
    warn "remote control" "off, /remote-control disconnects, run setup 30_tools"
  fi
fi

# ---------------------------------------------------------------------------
section "kamaji"
# ---------------------------------------------------------------------------

# kamaji reads the backlogs of every project in its list. It runs here, not in
# a sandbox, because a token reaches the repositories of one owner only, and
# kamaji needs both. Its checkout is cloned by hand, so until it is, nothing
# else here applies.
kamaji_dir="$HOME/src/personal/kamaji"
kamaji_job="com.domtriola.kamaji-refresh"
if [[ ! -d "$kamaji_dir" ]]; then
  pending "kamaji" "not cloned, see bootstrap.md"
else
  ok "kamaji" "~/src/personal/kamaji"

  if have kamaji; then
    ok "kamaji command" "$(command -v kamaji)"
  else
    warn "kamaji command" "not installed, run pnpm link --global in ~/src/personal/kamaji"
  fi

  if [[ -n "${token_installs:-}" ]]; then
    missing=""
    for owner in domtriola Fernata-Studio; do
      [[ ", $token_installs, " == *", $owner, "* ]] || missing="${missing:+$missing, }$owner"
    done
    if [[ -z "$missing" ]]; then
      ok "kamaji owners" "domtriola, Fernata-Studio"
    else
      warn "kamaji owners" "the App is not installed on $missing, install it there, then run sbx-token expect <owner>"
    fi
    unset missing owner
  else
    pending "kamaji owners" "needs an online sbx-token check"
  fi

  if have launchctl; then
    job_status=0
    job_out="$(launchctl print "gui/$(id -u)/$kamaji_job" 2>/dev/null)" || job_status=$?
    last_exit="$(sed -n 's/^[[:space:]]*last exit code = //p' <<<"$job_out" | head -1)"
    if [[ "$job_status" -ne 0 ]]; then
      warn "kamaji refresh job" "not loaded, run launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$kamaji_job.plist"
    elif [[ -z "$last_exit" || "$last_exit" == "0" || "$last_exit" == "(never exited)" ]]; then
      ok "kamaji refresh job" "loaded, refreshes every 15 minutes"
    else
      warn "kamaji refresh job" "last refresh exited $last_exit, see ~/Library/Logs/kamaji-refresh.log"
    fi
    unset job_status job_out last_exit
  fi
fi
unset kamaji_dir kamaji_job token_installs

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

# A command that differs from the checkout means an edit that sync-env has not
# installed yet.
while read -r directive name prefix _; do
  [[ "$directive" == "command" ]] || continue
  prefix="${prefix//\$HOME/$HOME}"

  if [[ ! -L "$prefix/bin/$name" || ! -d "$prefix/lib/$name" ]]; then
    fail "$name" "not installed, run sync-env"
  elif diff -rq "$dotfiles_dir/commands/$name" "$prefix/lib/$name" >/dev/null 2>&1; then
    ok "$name" "matches the checkout"
  else
    warn "$name" "differs from the checkout, run sync-env"
  fi
done <"$profile_dir/env.manifest"
