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
# kamaji needs both owners, domtriola and Fernata-Studio. The host runs the
# runtime clone, which kamaji-update keeps at the reviewed main, and never the
# development checkout, which the kamaji sandbox can write to. Until the
# runtime clone exists, nothing else here applies.
kamaji_runtime="$HOME/.local/share/kamaji"
if [[ ! -d "$kamaji_runtime/.git" ]]; then
  pending "kamaji" "not installed, see bootstrap.md"
else
  if [[ -n "$(git -C "$kamaji_runtime" status --porcelain 2>/dev/null)" ]]; then
    warn "kamaji runtime" "has local changes, which the host runs, see kamaji-update"
  else
    ok "kamaji runtime" "$(git -C "$kamaji_runtime" log -1 --format='%h %cs' 2>/dev/null), update with kamaji-update"
  fi

  # In clone mode (product I4), the kamaji sandbox reads the snapshot through
  # a read-only view of this checkout. Mounted read and write, the sandbox
  # could write .git/config or a hook that the host's git then runs.
  if [[ -d "$HOME/src/personal/kamaji" ]]; then
    if jq -e '.clone == false' "$HOME/src/personal/kamaji/.sbx.json" >/dev/null 2>&1; then
      fail "kamaji checkout" ".sbx.json sets \"clone\": false, so the sandbox can write it, remove that"
    else
      ok "kamaji checkout" "~/src/personal/kamaji"
    fi
  else
    warn "kamaji checkout" "not cloned, so the kamaji sandbox gets no snapshot, see bootstrap.md"
  fi

  kamaji_path="$(command -v kamaji 2>/dev/null || true)"
  if [[ "$kamaji_path" == "$HOME/.local/bin/kamaji" ]]; then
    ok "kamaji command" "runs the runtime clone"
  elif [[ -z "$kamaji_path" ]]; then
    fail "kamaji command" "not installed, run sync-env"
  else
    fail "kamaji command" "$kamaji_path comes first on PATH, so the runtime clone does not run, remove it"
  fi
  unset kamaji_path

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
fi
unset kamaji_runtime token_installs

# ---------------------------------------------------------------------------
section "Secret store"
# ---------------------------------------------------------------------------

for tool in age age-plugin-yubikey; do
  if have "$tool"; then
    ok "$tool" "$(command -v "$tool")"
  else
    fail "$tool" "not installed, run setup 20_packages"
  fi
done
unset tool

# The store holds only ciphertext, but the scopes and the key names in it are
# for this user only. A scope in a git working tree can be pushed by mistake,
# and kept in its history after a rekey.
# shellcheck source=../../../commands/secrets/lib/store.sh
source "$dotfiles_dir/commands/secrets/lib/store.sh"
store="$(secrets_home)"

# recipients_check <label> <file> reports how many recipients a file has. A
# project's own file replaces the shared one, so each needs a backup.
recipients_check() {
  local count
  count="$(grep -c '^age1' "$2" 2>/dev/null || true)"
  if [[ "${count:-0}" -ge 2 ]]; then
    ok "$1" "$count, with a backup"
  elif [[ "${count:-0}" -eq 1 ]]; then
    warn "$1" "1, with no backup, run secrets init with the backup YubiKey"
  else
    fail "$1" "none in $2, run secrets init with a YubiKey inserted"
  fi
}

if [[ ! -d "$store" ]]; then
  pending "secret store" "not set up, see bootstrap.md"
else
  problems=""
  [[ -n "$(find "$store" -maxdepth 0 -perm 700 2>/dev/null)" ]] || problems="the store is not mode 700"
  readable="$(find "$store" -mindepth 1 \( -perm -040 -o -perm -004 \) 2>/dev/null | sed "s|^$store/||" | paste -sd ' ' -)"
  [[ -z "$readable" ]] || problems="${problems:+$problems, }others can read $readable"
  if [[ -z "$problems" ]]; then
    ok "store permissions" "only you can read it"
  else
    fail "store permissions" "$problems, run chmod 700 $store && chmod -R go-rwx $store"
  fi

  recipients_check "recipients" "$store/recipients.txt"
  for project_recipients in "$store"/*/recipients.txt; do
    [[ -f "$project_recipients" ]] || continue
    project="${project_recipients%/recipients.txt}"
    recipients_check "recipients of ${project##*/}" "$project_recipients"
  done

  tracked=""
  while IFS= read -r scope_file; do
    if git -C "$(dirname "$scope_file")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      tracked="${tracked:+$tracked }${scope_file#"$store"/}"
    fi
  done < <(find "$store" -name '*.age' 2>/dev/null)
  if [[ -z "$tracked" ]]; then
    ok "store location" "no scope is in a git working tree"
  else
    fail "store location" "in a git working tree: $tracked, move the store out of it"
  fi
  unset problems readable project_recipients project tracked scope_file
fi
unset store
unset -f recipients_check

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
