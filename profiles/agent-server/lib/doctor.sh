# Checks for the agent-server profile. Sourced by doctor, which supplies
# section, ok, warn, fail, pending and have.
#
# Lives under lib/ because it is not a setup step. setup only runs files
# directly inside the profile directory and never looks into lib/.
#
# Most checks hold an invariant of docs/threat-model/profile-agent-server.md,
# named in the comment above it. Every check only reads.

# ---------------------------------------------------------------------------
section "SSH"
# ---------------------------------------------------------------------------

user="$(id -un)"
hardening_conf="/etc/ssh/sshd_config.d/01-hardening.conf"
authorized_keys="$HOME/.ssh/authorized_keys"

if [[ -f "$hardening_conf" ]]; then
  ok "drop-in" "$hardening_conf"
else
  fail "drop-in" "$hardening_conf is missing, run setup 05_hardening"
fi

# agent-server-I1 and I3. sshd keeps the FIRST value of each directive, so the
# file proves nothing. sshd -T is the merged result.
if sshd_effective="$(sudo sshd -T 2>/dev/null)"; then
  for pair in passwordauthentication=no kbdinteractiveauthentication=no permitrootlogin=no \
    pubkeyauthoptions=verify-required \
    pubkeyacceptedalgorithms=sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com \
    authorizedkeysfile=.ssh/authorized_keys allowagentforwarding=no; do
    directive="${pair%%=*}"
    want="${pair#*=}"
    value="$(awk -v d="$directive" 'tolower($1) == d { print $2; exit }' <<<"$sshd_effective")"
    if [[ "$value" == "$want" ]]; then
      ok "$directive" "$value"
    else
      fail "$directive" "${value:-unset}, expected $want"
    fi
  done
else
  warn "effective config unreadable" "sudo sshd -T failed"
fi

# agent-server-I1: only security keys can log in. The key type is the first
# field that looks like one, because options can come before it. A comment
# that holds "sk-" must not count.
if [[ -s "$authorized_keys" ]]; then
  key_types="$(awk '!/^[[:space:]]*(#|$)/ {
    for (i = 1; i <= NF; i++) if ($i ~ /^(sk-|ssh-|ecdsa-)/) { print $i; next }
    print "unknown"
  }' "$authorized_keys")"
  total="$(grep -c . <<<"$key_types" || true)"
  other_keys="$(grep -cvx 'sk-ssh-ed25519@openssh.com' <<<"$key_types" || true)"
  if [[ -z "$key_types" ]]; then
    fail "authorized_keys" "no keys, password login is off"
  elif [[ "$other_keys" -gt 0 ]]; then
    fail "authorized_keys" "$other_keys key(s) that are not YubiKey keys (sk-ssh-ed25519), remove them"
  else
    ok "authorized_keys" "$total YubiKey key(s)"
  fi
else
  fail "authorized_keys" "missing or empty, password login is off"
fi

if [[ -e "$HOME/.ssh/authorized_keys2" ]]; then
  fail "authorized_keys2" "present, remove it"
fi

# ---------------------------------------------------------------------------
section "sudo"
# ---------------------------------------------------------------------------

# agent-server-I4. sudo -l needs no password when a rule has NOPASSWD, and it
# fails with -n when it needs one. So a failure here means that there is no
# such rule. With a cached password, the rules are listed and read.
if sudo_rules="$(sudo -n -l 2>/dev/null)"; then
  if grep -q 'NOPASSWD' <<<"$sudo_rules"; then
    fail "password" "a NOPASSWD rule applies to $user, remove it from /etc/sudoers.d"
  else
    ok "password" "every rule asks for it"
  fi
else
  ok "password" "sudo asks for it"
fi

# ---------------------------------------------------------------------------
section "Firewall"
# ---------------------------------------------------------------------------

# agent-server-I2: SSH and mosh on wt0 only, and no other port open.
if ufw_status="$(sudo ufw status verbose 2>/dev/null)"; then
  if grep -q '^Status: active' <<<"$ufw_status"; then
    ok "ufw" "active"
  else
    fail "ufw" "inactive"
  fi

  default_in="$(sed -n 's/^Default: \([a-z]*\) (incoming).*/\1/p' <<<"$ufw_status")"
  if [[ "$default_in" == "deny" ]]; then
    ok "default incoming" "deny"
  else
    fail "default incoming" "${default_in:-unknown}, expected deny"
  fi

  # A general rule is "22/tcp" (or "22/tcp (v6)") and then spaces. The
  # overlay rule is "22/tcp on wt0".
  general="$(grep -cE '^22/tcp( \(v6\))? +(ALLOW|LIMIT)' <<<"$ufw_status" || true)"
  overlay="$(grep -cE '^22/tcp( \(v6\))? on wt0 +ALLOW' <<<"$ufw_status" || true)"
  if [[ "$overlay" -gt 0 && "$general" -eq 0 ]]; then
    ok "ssh rule" "22/tcp on wt0 only"
  elif [[ "$overlay" -gt 0 ]]; then
    fail "ssh rule" "22/tcp is open on every interface too, run setup 25_network"
  elif [[ "$general" -gt 0 ]]; then
    warn "ssh rule" "22/tcp on every interface until setup 25_network runs"
  else
    fail "ssh rule" "no rule for 22/tcp"
  fi

  # mosh is optional, but only on wt0. A general rule for its ports counts as
  # one of the other rules below.
  mosh_rule='^60000:61000/udp( \(v6\))? on wt0 +ALLOW'
  if grep -qE "$mosh_rule" <<<"$ufw_status"; then
    ok "mosh rule" "60000:61000/udp on wt0 only"
  else
    warn "mosh rule" "no rule for 60000:61000/udp on wt0, run setup 25_network"
  fi

  other_rules="$(sed -n '/^--/,$p' <<<"$ufw_status" | grep -E 'ALLOW|LIMIT' | grep -vE '^22/tcp' | grep -cvE "$mosh_rule" || true)"
  if [[ "$other_rules" -gt 0 ]]; then
    fail "other rules" "$other_rules rule(s) other than 22/tcp and 60000:61000/udp on wt0, see sudo ufw status"
  else
    ok "other rules" "none"
  fi
else
  warn "ufw" "status unreadable"
fi

if grep -q '^IPV6=yes' /etc/default/ufw 2>/dev/null; then
  ok "ufw IPv6" "IPV6=yes"
else
  fail "ufw IPv6" "IPV6 is not yes in /etc/default/ufw"
fi

# ---------------------------------------------------------------------------
section "NetBird"
# ---------------------------------------------------------------------------

if have netbird; then
  # The JSON is read rather than the human summary, whose wording changes
  # between releases.
  nb_json="$(netbird status --json 2>/dev/null)" || nb_json=""
  if [[ -n "$nb_json" ]] && have jq; then
    if [[ "$(jq -r '.management.connected // false' <<<"$nb_json")" == "true" ]]; then
      ok "netbird" "connected as $(jq -r '.fqdn // "unknown"' <<<"$nb_json")"
    else
      fail "netbird" "the management service is not connected, so SSH may not answer"
    fi
    status info "address" "$(jq -r '.netbirdIp // "unknown"' <<<"$nb_json")"
  else
    warn "netbird" "status unreadable"
  fi
else
  fail "netbird" "not installed, run setup 25_network"
fi

# ---------------------------------------------------------------------------
section "Disk"
# ---------------------------------------------------------------------------

# agent-server-I7. lsblk -s lists the device under / and the devices that it
# sits on. One of them is the LUKS container.
root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
if [[ "$root_source" == /dev/* ]] && lsblk -s -n -o TYPE "$root_source" 2>/dev/null | grep -qx crypt; then
  ok "encryption" "/ is on LUKS"
else
  fail "encryption" "no LUKS device under / (${root_source:-unknown})"
fi

avail_gib="$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')"
if [[ -z "$avail_gib" ]]; then
  warn "free space" "could not read /"
elif [[ "$avail_gib" -ge 50 ]]; then
  ok "free space" "${avail_gib} GiB on /"
elif [[ "$avail_gib" -ge 10 ]]; then
  warn "free space" "${avail_gib} GiB on /"
else
  fail "free space" "${avail_gib} GiB on /, sandboxes can fail to start"
fi

if have vgs; then
  vg_free_gib="$(sudo vgs --noheadings --units g -o vg_free 2>/dev/null | tr -dc '0-9.' | cut -d. -f1)"
  if [[ -n "$vg_free_gib" && "$vg_free_gib" -ge 10 ]]; then
    warn "unallocated LVM space" "${vg_free_gib} GiB unused, run setup 12_storage"
  elif [[ -n "$vg_free_gib" ]]; then
    ok "unallocated LVM space" "${vg_free_gib} GiB"
  fi
fi

# ---------------------------------------------------------------------------
section "Kernel"
# ---------------------------------------------------------------------------

# agent-server-I6. ai-server turns the IOMMU off on its own drive, for the
# GPU. Here it stays on, so a device on a USB4 port cannot read the memory.
if grep -qE '(^| )(amd_)?iommu=off( |$)' /proc/cmdline 2>/dev/null; then
  fail "iommu" "off on the kernel command line, remove it"
else
  ok "iommu" "not turned off"
fi

# ---------------------------------------------------------------------------
section "Updates"
# ---------------------------------------------------------------------------

# agent-server-I11. Updates install by themselves and never reboot, so the
# operator reboots by hand, at home, where the LUKS prompt can be answered.
if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q 'ok installed'; then
  ok "unattended-upgrades" "installed"
else
  fail "unattended-upgrades" "not installed, run setup 05_hardening"
fi

reboot_value="$(apt-config dump 2>/dev/null |
  sed -n 's/^Unattended-Upgrade::Automatic-Reboot "\(.*\)";$/\1/p' | tail -1)"
if [[ "$reboot_value" == "false" ]]; then
  ok "automatic reboot" "off"
else
  fail "automatic reboot" "${reboot_value:-unset}, expected false, run setup 05_hardening"
fi

reboot_marker="${REBOOT_REQUIRED_FILE:-/var/run/reboot-required}"
if [[ -f "$reboot_marker" ]]; then
  pkgs="$(paste -sd' ' "$reboot_marker.pkgs" 2>/dev/null || true)"
  warn "reboot" "required${pkgs:+ by $pkgs}, reboot when you are at the box"
else
  ok "reboot" "not required"
fi

# ---------------------------------------------------------------------------
section "Power"
# ---------------------------------------------------------------------------

# agent-server-I12.
unmasked=()
for target in sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target; do
  [[ "$(systemctl is-enabled "$target" 2>/dev/null)" == "masked" ]] || unmasked+=("$target")
done
if [[ ${#unmasked[@]} -eq 0 ]]; then
  ok "sleep" "every sleep target is masked"
else
  fail "sleep" "not masked: ${unmasked[*]}, run setup 05_hardening"
fi

# ---------------------------------------------------------------------------
section "pnpm"
# ---------------------------------------------------------------------------

pnpm_bin="$HOME/.local/share/pnpm/bin/pnpm"

if have node; then
  ok "node" "$(node --version 2>/dev/null || echo 'version unknown')"
else
  fail "node" "not installed, run setup 10_packages"
fi

if [[ -x "$pnpm_bin" ]]; then
  ok "pnpm" "$("$pnpm_bin" --version 2>/dev/null || echo 'version unknown')"
else
  fail "pnpm" "not installed, run setup 15_pnpm"
fi

# agent-server-I16. pnpm reads the value from ~/.config/pnpm/config.yaml.
if [[ -x "$pnpm_bin" ]]; then
  release_age="$(cd "$HOME" && "$pnpm_bin" config get minimumReleaseAge 2>/dev/null | tr -dc '0-9')"
  if [[ -n "$release_age" && "$release_age" -ge 10080 ]]; then
    ok "minimum release age" "$release_age minutes"
  else
    fail "minimum release age" "${release_age:-unset}, expected at least 10080, run sync-env"
  fi
fi

# ---------------------------------------------------------------------------
section "Sandboxes"
# ---------------------------------------------------------------------------

if have sbx; then
  ok "sbx" "$(sbx version 2>/dev/null | head -1 || echo 'version unknown')"
else
  fail "sbx" "not installed, run setup 22_sandboxes"
fi

if have sbx; then
  if [[ "$(sbx settings get claude.remoteControl 2>/dev/null)" == "true" ]]; then
    ok "remote control" "on"
  else
    warn "remote control" "off, /remote-control disconnects, run setup 22_sandboxes"
  fi
fi

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  ok "kvm" "/dev/kvm is usable"
else
  fail "kvm" "/dev/kvm is not usable by $user, check the kvm group and log in again"
fi

if [[ "$(loginctl show-user "$user" -p Linger --value 2>/dev/null)" == "yes" ]]; then
  ok "linger" "on"
else
  fail "linger" "off, sandboxes stop when you log out, run setup 22_sandboxes"
fi

# agent-server-I5. The App key is in a file, and the config names that store,
# so that the sbx daemon's renewal finds it.
token_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sbx-token"
token_config="$token_dir/config.json"
key_file="$token_dir/private-key"
if [[ ! -f "$token_config" ]]; then
  pending "App key" "not imported, see profiles/agent-server/bootstrap.md"
elif [[ "$(jq -r '.store // empty' "$token_config" 2>/dev/null)" != "file" ]]; then
  fail "App key" "not in the file store, renewals fail, import it again with SBX_TOKEN_STORE=file"
elif [[ ! -f "$key_file" ]]; then
  fail "App key" "$key_file is missing"
else
  # The same test as sbx-token: no bit for the group or others.
  key_mode="$(stat -c '%a' "$key_file" 2>/dev/null)"
  if [[ "$key_mode" =~ ^[0-7]+$ ]] && (((8#$key_mode & 8#177) == 0)); then
    ok "App key" "$key_file, mode $key_mode"
  else
    fail "App key" "$key_file has mode $key_mode, run chmod 600 $key_file"
  fi
fi

# agent-server-I14. git on the box gets read-only tokens from the App.
git_helper="$(git config --global --get-all credential.https://github.com.helper 2>/dev/null || true)"
if [[ "$git_helper" == "$HOME/.local/bin/sbx-token credential" &&
  "$(git config --global --get credential.https://github.com.useHttpPath 2>/dev/null)" == "true" ]]; then
  ok "git credentials" "sbx-token, read-only"
else
  fail "git credentials" "git cannot clone private repositories, run setup 30_git"
fi

# sbx copies the identity into each sandbox. Without it, git commit fails in
# the sandbox, but nothing on the box breaks.
for key in user.name user.email; do
  if value="$(git config --global --get "$key")"; then
    ok "git $key" "$value"
  else
    warn "git $key" "not set, sandboxes cannot commit, run setup 30_git"
  fi
done
