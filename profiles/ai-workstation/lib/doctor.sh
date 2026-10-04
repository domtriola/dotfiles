# Checks for the ai-workstation profile. Sourced by doctor, which supplies
# section, ok, warn, fail, pending and have.
#
# Lives under lib/ because it is not a setup step. setup only runs files
# directly inside the profile directory and never looks into lib/.
#
# Each check reports what it found rather than only whether it passed, because
# most of the faults this machine can have are quiet ones. A GPU that fell back
# to software, a drop-in file that lost to another, and a memory limit that was
# ignored all look like a working server until the number is read.

# The API key: where it is, and model_curl, which sends it.
# shellcheck source=../commands/ai-model/lib/apikey
source "$profile_dir/commands/ai-model/lib/apikey"

# ---------------------------------------------------------------------------
section "SSH"
# ---------------------------------------------------------------------------

hardening_conf="/etc/ssh/sshd_config.d/01-hardening.conf"

if [[ -f "$hardening_conf" ]]; then
  ok "drop-in present" "$hardening_conf"
else
  fail "drop-in missing" "expected $hardening_conf"
fi

# The file on disk proves nothing. sshd keeps the FIRST value of each
# directive, and reads sshd_config.d/*.conf in lexical order, so a
# lower-numbered file wins. sshd -T is the merged result.
if sshd_effective="$(sudo sshd -T 2>/dev/null)"; then
  for directive in passwordauthentication kbdinteractiveauthentication permitrootlogin; do
    value="$(awk -v d="$directive" 'tolower($1) == d { print $2; exit }' <<<"$sshd_effective")"
    if [[ "$value" == "no" ]]; then
      ok "$directive" "no"
    else
      fail "$directive" "${value:-unset}, expected no"
    fi
  done
else
  warn "effective config unreadable" "sudo sshd -T failed"
fi

if [[ -s "$HOME/.ssh/authorized_keys" ]]; then
  key_count="$(grep -cvE '^\s*(#|$)' "$HOME/.ssh/authorized_keys")"
  ok "authorized_keys" "$key_count key(s)"
else
  fail "authorized_keys" "missing or empty, password login is off"
fi

# ---------------------------------------------------------------------------
section "Firewall"
# ---------------------------------------------------------------------------

if ufw_status="$(sudo ufw status verbose 2>/dev/null)"; then
  if grep -q '^Status: active' <<<"$ufw_status"; then
    ok "ufw" "active"
  else
    fail "ufw" "inactive"
  fi

  # The general rules are matched with a space after the port, so that an
  # interface rule ("22/tcp on wt0  ALLOW IN") is not read as one of them. The
  # overlay case is reported last because it is the narrowest, and only reached
  # when there is no general rule left to report.
  if grep -qE '^22/tcp +LIMIT' <<<"$ufw_status"; then
    ok "ssh rule" "22/tcp LIMIT"
  elif grep -qE '^22/tcp +ALLOW' <<<"$ufw_status"; then
    warn "ssh rule" "22/tcp ALLOW, not rate limited"
  elif ssh_iface_rule="$(grep -oE '^22/tcp on [a-zA-Z0-9._-]+' <<<"$ufw_status" | head -1)" &&
    [[ -n "$ssh_iface_rule" ]]; then
    ok "ssh rule" "$ssh_iface_rule, overlay only"
  else
    fail "ssh rule" "no rule for 22/tcp"
  fi

  default_in="$(sed -n 's/^Default: \([a-z]*\) (incoming).*/\1/p' <<<"$ufw_status")"
  if [[ "$default_in" == "deny" ]]; then
    ok "default incoming" "deny"
  else
    warn "default incoming" "${default_in:-unknown}, expected deny"
  fi
else
  warn "ufw" "status unreadable"
fi

# This host has a global IPv6 address, so nothing sits between it and the
# internet. An IPv4-only firewall would leave that side open.
if grep -q '^IPV6=yes' /etc/default/ufw 2>/dev/null; then
  ok "ufw IPv6" "IPV6=yes"
else
  fail "ufw IPv6" "IPV6 is not yes in /etc/default/ufw"
fi

# ---------------------------------------------------------------------------
section "Network"
# ---------------------------------------------------------------------------

if ! have ip; then
  warn "iproute2" "ip is not installed, network checks skipped"
else
  ipv4="$(ip -4 -br addr show scope global 2>/dev/null | awk '{print $3}' | paste -sd' ' -)"
  if [[ -n "$ipv4" ]]; then
    ok "IPv4 address" "$ipv4"
  else
    fail "IPv4 address" "none, the netplan drop-in may be missing"
  fi

  if ip -4 route show default 2>/dev/null | grep -q .; then
    ok "IPv4 default route" "$(ip -4 route show default | awk '{print $3; exit}')"
  else
    fail "IPv4 default route" "none"
  fi

  ipv6="$(ip -6 -br addr show scope global 2>/dev/null | awk '{print $3}' | paste -sd' ' -)"
  [[ -n "$ipv6" ]] && ok "IPv6 address" "$ipv6"
fi

# ---------------------------------------------------------------------------
section "GPU memory"
# ---------------------------------------------------------------------------

grub_dropin="/etc/default/grub.d/99-ai-workstation.cfg"
if [[ -f "$grub_dropin" ]]; then
  ok "grub drop-in" "$grub_dropin"
else
  fail "grub drop-in" "missing, 15_gpu has not run"
fi

cmdline="$(cat /proc/cmdline)"

for param in amdgpu.gttsize ttm.pages_limit; do
  if [[ "$cmdline" == *"$param="* ]]; then
    ok "$param" "$(grep -o "$param=[^ ]*" <<<"$cmdline")"
  else
    fail "$param" "not on the running kernel command line"
  fi
done

if [[ "$cmdline" == *"amd_iommu=off"* ]]; then
  ok "iommu" "amd_iommu=off"
elif [[ "$cmdline" == *"iommu=pt"* ]]; then
  ok "iommu" "iommu=pt"
else
  warn "iommu" "neither amd_iommu=off nor iommu=pt is set"
fi

# A drop-in that was written but not applied leaves the file correct and the
# running kernel unchanged, so these two are checked separately.
if [[ -f "$grub_dropin" ]] && [[ "$cmdline" != *"amdgpu.gttsize"* ]]; then
  fail "drop-in applied" "file exists but the kernel did not get it, reboot"
fi

found_gpu=0
for d in /sys/class/drm/card*/device; do
  [[ -f "$d/mem_info_gtt_total" ]] || continue
  found_gpu=1

  gtt_gib=$(($(cat "$d/mem_info_gtt_total") / 1024 ** 3))
  vram_mib=$(($(cat "$d/mem_info_vram_total") / 1024 ** 2))

  if [[ $gtt_gib -ge 100 ]]; then
    ok "GTT pool" "${gtt_gib} GiB"
  elif [[ $gtt_gib -ge 50 ]]; then
    fail "GTT pool" "${gtt_gib} GiB, looks like the driver default of half of RAM"
  else
    fail "GTT pool" "${gtt_gib} GiB"
  fi

  # What the model holds now, against its budget. The sandboxes need about
  # 48 GB of the 128 for themselves and the system, so a model and cache that
  # grow past 70 GB take memory the agents are counting on. GTT is used by
  # nothing else on this machine.
  gtt_used_gib=$(($(cat "$d/mem_info_gtt_used") / 1024 ** 3))
  if [[ $gtt_used_gib -le 70 ]]; then
    ok "model memory" "${gtt_used_gib} GiB in use, budget 70"
  else
    warn "model memory" "${gtt_used_gib} GiB in use, over the 70 GiB budget, lower the context: ai-model ctx"
  fi

  # A small carve-out is correct. AMD recommends 512 MiB or less, because these
  # frameworks work better against GTT-backed allocations.
  if [[ $vram_mib -le 1024 ]]; then
    ok "VRAM carve-out" "${vram_mib} MiB (small is correct)"
  else
    warn "VRAM carve-out" "${vram_mib} MiB, lower it in the firmware setup"
  fi
done

if [[ $found_gpu -eq 0 ]]; then
  fail "GTT pool" "no DRM device exposes mem_info_gtt_total"
fi

if dmesg_out="$(sudo dmesg 2>/dev/null)"; then
  if grep -q 'this is unusual' <<<"$dmesg_out"; then
    fail "GTT and TTM agree" "kernel logged a size mismatch, see dmesg"
  else
    ok "GTT and TTM agree" "no mismatch logged"
  fi
else
  # Reporting ok here would claim a clean log that was never read.
  warn "GTT and TTM agree" "dmesg unreadable, mismatch not checked"
fi

# ---------------------------------------------------------------------------
section "GPU access"
# ---------------------------------------------------------------------------

render_node="/dev/dri/renderD128"
if [[ -e "$render_node" ]]; then
  render_group="$(stat -c '%G' "$render_node")"
  ok "render node" "$render_node, group $render_group"

  if id -nG "$USER" | tr ' ' '\n' | grep -qx "$render_group"; then
    ok "group membership" "$USER is in $render_group"
  else
    fail "group membership" "$USER is not in $render_group, log out and back in"
  fi
else
  fail "render node" "$render_node is missing"
fi

# The driver name is what matters. Mesa answers with llvmpipe, a software
# renderer, when it cannot open the render node, and reports a device either
# way. Counting devices would pass while everything ran on the processor.
if have vulkaninfo; then
  vk="$(vulkaninfo --summary 2>/dev/null)"
  driver="$(awk -F'= ' '/driverName/ { gsub(/ /, "", $2); print $2; exit }' <<<"$vk")"
  device="$(awk -F'= ' '/deviceName/ { sub(/^ +/, "", $2); print $2; exit }' <<<"$vk")"

  case "$driver" in
  radv) ok "vulkan driver" "$driver, $device" ;;
  llvmpipe) fail "vulkan driver" "llvmpipe, inference would run on the processor" ;;
  "") fail "vulkan driver" "no device reported" ;;
  *) warn "vulkan driver" "$driver, $device" ;;
  esac
else
  fail "vulkaninfo" "not installed, 10_packages has not run"
fi

# ---------------------------------------------------------------------------
section "Performance profile"
# ---------------------------------------------------------------------------

if have tuned-adm; then
  if systemctl is-active --quiet tuned; then
    ok "tuned service" "active"
  else
    fail "tuned service" "not active"
  fi

  active_profile="$(tuned-adm active 2>/dev/null | sed -n 's/.*: //p')"
  if [[ "$active_profile" == "accelerator-performance" ]]; then
    ok "tuned profile" "$active_profile"
  else
    warn "tuned profile" "${active_profile:-none}, expected accelerator-performance"
  fi
else
  fail "tuned" "not installed, 10_packages has not run"
fi

# ---------------------------------------------------------------------------
section "Model server"
# ---------------------------------------------------------------------------

# llama-server is not on PATH. It lives beside its shared libraries, which it
# finds through RUNPATH=$ORIGIN, so it is checked by path.
llama_bin="/opt/llama.cpp/current/llama-server"
swap_bin="/opt/llama-swap/current/llama-swap"
swap_config="/etc/llama-swap/config.yaml"
swap_unit="/etc/systemd/system/llama-swap.service"
models_dir="/var/lib/llama/models"

# Run it rather than test for it. A binary whose shared libraries are missing
# is present, executable, and useless, and reports as installed to every check
# that only looks at the file.
if [[ -x "$llama_bin" ]]; then
  llama_ver="$(basename "$(readlink -f /opt/llama.cpp/current)")"
  if llama_out="$("$llama_bin" --version 2>&1)"; then
    ok "llama-server" "$llama_ver runs"
  else
    fail "llama-server" "$llama_ver installed but will not run: $(head -1 <<<"$llama_out")"
  fi
else
  pending "llama-server" "not installed, 20_llama has not run"
fi

if [[ -x "$swap_bin" ]]; then
  ok "llama-swap binary" "$(basename "$(readlink -f /opt/llama-swap/current)")"
else
  pending "llama-swap binary" "not installed"
fi

for helper in ai-model; do
  if [[ -x "/usr/local/bin/$helper" ]]; then
    ok "$helper helper" "/usr/local/bin/$helper"
  else
    pending "$helper helper" "not installed"
  fi
done

# Models are counted two ways, because the two can disagree. The configuration
# is what llama-swap serves. The directory is what is on disk. A file added
# without a later setup shows up here rather than being silently unserved.
# An unreadable models directory reports the same as an empty one, so it is
# checked before anything is counted. A home made by `useradd --create-home`
# gets HOME_MODE from /etc/login.defs, which is 0700 or 0750 on Ubuntu, and
# then nothing below it can be seen.
models_readable=1
if [[ ! -d "$models_dir" ]]; then
  models_probe="$models_dir"
  while [[ ! -e "$models_probe" && "$models_probe" != "/" ]]; do
    models_probe="$(dirname "$models_probe")"
  done
  if [[ ! -x "$models_probe" ]]; then
    models_readable=0
    fail "models directory" "$models_probe is not traversable by $USER"
  fi
fi

gguf_count=0
if [[ -d "$models_dir" ]]; then
  # Shards of a split model count once, the same way 20_llama configures them.
  # Keep a file when it is not a shard, or when it is the first shard.
  gguf_count="$(find "$models_dir" -maxdepth 1 -type f -name '*.gguf' -printf '%f\n' 2>/dev/null |
    awk '!/-[0-9]{5}-of-[0-9]{5}\.gguf$/ || /-00001-of-/' |
    wc -l)"
fi

# A split model loads only when every shard is present, and llama-server is
# given the first one. The expected count is in the file name, so an
# interrupted download is detectable without opening anything.
incomplete=()
while IFS= read -r first; do
  [[ -n "$first" ]] || continue
  prefix="${first%-00001-of-*}"
  total="${first##*-of-}"
  total="${total%.gguf}"
  present="$(find "$models_dir" -maxdepth 1 -type f \
    -name "$prefix-[0-9][0-9][0-9][0-9][0-9]-of-$total.gguf" 2>/dev/null | wc -l)"
  # 10# forces base ten: a count such as 00008 is not octal.
  if [[ "$present" -ne "$((10#$total))" ]]; then
    incomplete+=("$prefix ($present of $((10#$total)) shards)")
  fi
done < <(find "$models_dir" -maxdepth 1 -type f -name '*-00001-of-*.gguf' -printf '%f\n' 2>/dev/null)

# Shards with no first shard cannot be loaded at all, and no configuration
# entry is written for them, so they would otherwise sit unreported.
orphans="$(find "$models_dir" -maxdepth 1 -type f -name '*-[0-9][0-9][0-9][0-9][0-9]-of-*.gguf' -printf '%f\n' 2>/dev/null |
  sed -E 's/-[0-9]{5}-of-([0-9]{5})\.gguf$/-00001-of-\1.gguf/' | sort -u |
  while IFS= read -r f; do [[ -e "$models_dir/$f" ]] || echo "$f"; done | wc -l)"

if [[ ${#incomplete[@]} -gt 0 ]]; then
  fail "split models complete" "${incomplete[*]}"
elif [[ "$orphans" -gt 0 ]]; then
  fail "split models complete" "$orphans set(s) missing their first shard"
fi

configured_count=0
if [[ -f "$swap_config" ]]; then
  # Only entries under `models:` are counted. Matching indented quotes across
  # the whole file also matches the `macros:` block, which reported one model
  # on a machine that had none.
  configured_count="$(awk '
    /^models:/ { in_models = 1; next }
    /^[^[:space:]]/ { in_models = 0 }
    in_models && /^  "/ { n++ }
    END { print n + 0 }
  ' "$swap_config")"

  if [[ "$models_readable" -eq 0 ]]; then
    : # already reported above; counting would be meaningless
  elif [[ "$configured_count" -eq 0 && "$gguf_count" -eq 0 ]]; then
    pending "models" "none in $models_dir"
  elif [[ "$configured_count" -eq "$gguf_count" ]]; then
    ok "models" "$configured_count configured"
  else
    warn "models" "$gguf_count file(s) in $models_dir, $configured_count configured, run setup"
  fi
else
  pending "llama-swap config" "not written"
fi

# The unit is checked by file path. `systemctl list-unit-files` needs systemd to
# answer and its column layout to hold, and neither is worth depending on for a
# question a file test settles.
if [[ -f "$swap_unit" ]]; then
  unit_state="$(systemctl is-enabled llama-swap 2>/dev/null || echo unknown)"

  if systemctl is-active --quiet llama-swap 2>/dev/null; then
    ok "llama-swap service" "active, $unit_state"

    # The only check that proves the whole chain, so it is worth the request.
    #
    # The address comes from systemd and not from the unit file, so that a
    # drop-in that changed it is followed rather than missed.
    listen="$(systemctl show -p Environment --value llama-swap 2>/dev/null |
      tr ' ' '\n' | sed -n 's/^LLAMA_SWAP_LISTEN=//p' | tail -1)"
    listen="${listen:-127.0.0.1:8080}"
    listen_host="${listen%:*}"
    listen_port="${listen##*:}"
    # 0.0.0.0 is every address rather than one to connect to.
    [[ -z "$listen_host" || "$listen_host" == "0.0.0.0" ]] && listen_host="127.0.0.1"

    if served="$(model_curl -fsS --max-time 5 "http://${listen_host}:${listen_port}/v1/models" 2>/dev/null)"; then
      served_count="$(grep -o '"id"' <<<"$served" | wc -l)"
      ok "API answers" "$listen_host:$listen_port, $served_count model(s)"
    else
      fail "API answers" "no reply with the key on $listen_host:$listen_port"
    fi

    # The other half of the key: a request without it has to be refused. A
    # server that answers both is a server with no authentication, and that
    # looks exactly like a working one from every other check.
    no_key_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
      "http://${listen_host}:${listen_port}/v1/models" 2>/dev/null)"
    case "$no_key_code" in
    401) ok "API refuses no key" "401 on $listen_host:$listen_port" ;;
    200) fail "API refuses no key" "answered 200 without a key, apiKeys is not in effect" ;;
    *) warn "API refuses no key" "unexpected reply ${no_key_code:-none} on $listen_host:$listen_port" ;;
    esac
  elif [[ "$configured_count" -eq 0 ]]; then
    # Not a fault. 20_llama installs and enables the service, and leaves it
    # stopped until there is something for it to serve.
    pending "llama-swap service" "$unit_state, not started until a model exists"
  else
    fail "llama-swap service" "$configured_count model(s) configured but not active"
  fi
else
  pending "llama-swap service" "not installed"
fi

# The key file is read by systemd as root. Any wider mode means an agent's
# account, or any other local account, could read the key.
if sudo test -s "$api_key_file" 2>/dev/null; then
  key_mode="$(sudo stat -c '%a %U' "$api_key_file" 2>/dev/null)"
  if [[ "$key_mode" == "600 root" ]]; then
    ok "API key file" "$api_key_file, 600 root"
  else
    fail "API key file" "$api_key_file is ${key_mode:-unreadable}, expected 600 root"
  fi
elif [[ -f "$swap_unit" ]]; then
  fail "API key file" "$api_key_file is missing or empty, run setup 20_llama"
else
  pending "API key file" "not written, 20_llama has not run"
fi

# When memory runs out, the kernel kills the process with the highest score.
# This one holds the model, so without the adjustment it is always first. Read
# from the running process when there is one, because a unit file changed
# without a restart has no effect.
if [[ -f "$swap_unit" ]]; then
  oom_unit="$(systemctl show -p OOMScoreAdjust --value llama-swap 2>/dev/null)"
  swap_pid="$(systemctl show -p MainPID --value llama-swap 2>/dev/null)"
  oom_live=""
  [[ -n "$swap_pid" && "$swap_pid" != "0" ]] && oom_live="$(cat "/proc/$swap_pid/oom_score_adj" 2>/dev/null)"

  if [[ -n "$oom_live" && "$oom_live" -lt 0 ]]; then
    ok "OOM order" "oom_score_adj $oom_live, a sandbox is killed first"
  elif [[ -z "$oom_live" && -n "$oom_unit" && "$oom_unit" -lt 0 ]]; then
    pending "OOM order" "unit sets $oom_unit, the service is not running"
  else
    fail "OOM order" "oom_score_adj ${oom_live:-${oom_unit:-0}}, the model server is killed first"
  fi
fi

# ---------------------------------------------------------------------------
section "Storage"
# ---------------------------------------------------------------------------
#
# Models are tens of gigabytes and every sandbox holds a disk image, so free
# space is a working part of this machine rather than housekeeping.

# Models, sandbox disk images and the system share one volume. When it fills,
# everything stops together, so use is warned about well before that.
# `ai-model add` already refuses a model that would not fit, so the usual cause
# is sandboxes: `sbx ls`, then `sbx rm <name>` for the ones that are finished.
space_target="/"

use_pct="$(df --output=pcent "$space_target" 2>/dev/null | tail -1 | tr -dc '0-9')"
avail_gib="$(df -BG --output=avail "$space_target" 2>/dev/null | tail -1 | tr -dc '0-9')"
if [[ -z "$use_pct" ]]; then
  warn "disk use" "could not read $space_target"
elif [[ "$use_pct" -ge 95 ]]; then
  fail "disk use" "${use_pct}% of $space_target, ${avail_gib} GiB free, remove finished sandboxes: sbx ls"
elif [[ "$use_pct" -ge 85 ]]; then
  warn "disk use" "${use_pct}% of $space_target, ${avail_gib} GiB free, remove finished sandboxes: sbx ls"
else
  ok "disk use" "${use_pct}% of $space_target, ${avail_gib} GiB free"
fi

# The Ubuntu Server installer builds a volume group across the whole disk and
# then gives the root volume about 100 GB, leaving the rest unallocated. The
# machine looks full while most of the disk was never handed out.
if have vgs; then
  vg_free_gib="$(sudo vgs --noheadings --units g -o vg_free 2>/dev/null |
    tr -dc '0-9.' | cut -d. -f1)"
  # The logical volume behind the filesystem, named the way lvextend wants it,
  # so the reported fix can be pasted rather than worked out.
  #
  # df resolves the filesystem that contains a path. `findmnt SOURCE <path>`
  # does not: it answers only for an exact mountpoint, and the models directory
  # is not one, so it returned nothing.
  lv_path="$(df --output=source "$space_target" 2>/dev/null | tail -1)"
  [[ -n "$lv_path" && "$lv_path" == /dev/* ]] || lv_path="<logical-volume>"

  if [[ -z "$vg_free_gib" ]]; then
    warn "unallocated LVM space" "could not read vgs"
  elif [[ "$vg_free_gib" -ge 10 ]]; then
    fail "unallocated LVM space" \
      "${vg_free_gib} GiB unused: sudo lvextend -l +100%FREE -r $lv_path"
  else
    ok "unallocated LVM space" "${vg_free_gib} GiB, the volume group is handed out"
  fi
else
  pending "unallocated LVM space" "no lvm2 tools, not an LVM system"
fi

# ---------------------------------------------------------------------------
section "Overlay network"
# ---------------------------------------------------------------------------

#
# The overlay is how this machine is reached, and it is also what limits who
# reaches the model API. Each part is reported on its own, because the client
# can be connected while the firewall still drops the traffic, and from the
# other end both look the same: nothing answers.

overlay_iface="wt0"

if have netbird; then
  # The JSON is read rather than the human summary, whose wording changes
  # between releases.
  nb_json="$(netbird status --json 2>/dev/null)" || nb_json=""

  if [[ -n "$nb_json" ]] && have jq; then
    if [[ "$(jq -r '.management.connected // false' <<<"$nb_json")" == "true" ]]; then
      ok "netbird" "connected as $(jq -r '.fqdn // "unknown"' <<<"$nb_json")"
    else
      warn "netbird" "installed, the management service is not connected"
    fi

    peers_total="$(jq -r '.peers.total // 0' <<<"$nb_json")"
    peers_up="$(jq -r '.peers.connected // 0' <<<"$nb_json")"
    if [[ "$peers_up" -gt 0 ]]; then
      ok "peers" "$peers_up of $peers_total connected"
    else
      # Not a fault. The client is not always switched on.
      pending "peers" "$peers_up of $peers_total connected"
    fi
  elif netbird status 2>/dev/null | grep -qi 'management: connected'; then
    ok "netbird" "connected"
  else
    warn "netbird" "installed but not connected"
  fi
else
  pending "netbird" "not installed, run setup 25_network"
fi

overlay_ip=""
if ! have ip; then
  warn "$overlay_iface interface" "ip is not installed, not checked"
else
  overlay_ip="$(ip -4 -br addr show "$overlay_iface" 2>/dev/null |
    awk '{print $3}' | cut -d/ -f1)"
  if [[ -n "$overlay_ip" ]]; then
    ok "$overlay_iface interface" "$overlay_ip"
  elif ip link show "$overlay_iface" >/dev/null 2>&1; then
    fail "$overlay_iface interface" "up with no IPv4 address"
  else
    pending "$overlay_iface interface" "absent until the machine registers"
  fi
fi

# Where the model is served decides how much the firewall has to carry.
# llama-swap belongs on loopback, and the overlay reaches it through a proxy
# that listens on the overlay address alone. On every address, the firewall and
# the key would be the only controls in front of the local network and the
# global IPv6 address.
#
# Read from the kernel, not from the units. A setting the binary ignores, or a
# process started before the unit changed, is invisible to anything that reads
# the intent.
swap_intent="$(systemctl show -p Environment --value llama-swap 2>/dev/null |
  tr ' ' '\n' | sed -n 's/^LLAMA_SWAP_LISTEN=//p' | tail -1)"

if [[ -z "$swap_intent" ]]; then
  pending "model server bind" "llama-swap is not installed"
else
  swap_port="${swap_intent##*:}"

  # Every listener on the port, because two are expected: llama-swap itself,
  # and the proxy socket on the overlay address.
  port_listeners=""
  if have ss; then
    port_listeners="$(sudo ss -tlnH 2>/dev/null |
      awk -v p=":$swap_port" '$4 ~ p"$" { print $4 }' | sort -u)"
  fi

  if ! have ss; then
    warn "model server bind" "ss is not installed, the sockets were not read"
  elif [[ -z "$port_listeners" ]]; then
    fail "model server bind" "nothing is listening on port $swap_port"
  else
    if grep -qxF "$swap_intent" <<<"$port_listeners"; then
      case "${swap_intent%:*}" in
      127.* | localhost | "[::1]") ok "model server bind" "$swap_intent, loopback" ;;
      *) warn "model server bind" "$swap_intent, not loopback, sandboxes reach the host on loopback" ;;
      esac
    else
      fail "model server bind" "the unit says $swap_intent, and nothing listens there"
    fi

    if grep -qE "^(0\.0\.0\.0|\*|\[::\]):${swap_port}$" <<<"$port_listeners"; then
      fail "every-address bind" "port $swap_port is open on every interface"
    fi
  fi

  # The overlay proxy. FreeBind lets the socket hold the overlay address before
  # wt0 has it, so a listener here can exist while the overlay is down.
  case "${AI_WORKSTATION_SERVE_OVERLAY:-yes}" in
  no | false | 0)
    pending "overlay proxy" "AI_WORKSTATION_SERVE_OVERLAY is no, served on loopback only"
    ;;
  *)
    if ! systemctl cat llama-swap-overlay.socket >/dev/null 2>&1; then
      pending "overlay proxy" "not installed, run setup 25_network"
    elif ! systemctl is-active --quiet llama-swap-overlay.socket; then
      fail "overlay proxy" "llama-swap-overlay.socket is not active"
    else
      proxy_listen="$(systemctl show -p Listen --value llama-swap-overlay.socket 2>/dev/null |
        awk '{print $1; exit}')"
      if [[ -n "$overlay_ip" && "$proxy_listen" != "$overlay_ip:$swap_port" ]]; then
        fail "overlay proxy" "listens on ${proxy_listen:-nothing}, wt0 is $overlay_ip, run setup 25_network"
      else
        ok "overlay proxy" "${proxy_listen:-active}"
      fi

      # Through the proxy, with the key: the same request a peer makes.
      if [[ -n "$overlay_ip" ]]; then
        if model_curl -fsS --max-time 5 -o /dev/null "http://$overlay_ip:$swap_port/v1/models" 2>/dev/null; then
          ok "API on the overlay" "$overlay_ip:$swap_port answers with the key"
        else
          fail "API on the overlay" "no reply on $overlay_ip:$swap_port"
        fi

        # And without it, as a peer with no key would ask. The proxy forwards
        # bytes, so this proves the key is enforced on this path as well.
        overlay_no_key="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          "http://$overlay_ip:$swap_port/v1/models" 2>/dev/null)"
        case "$overlay_no_key" in
        401) ok "overlay refuses no key" "401 on $overlay_ip:$swap_port" ;;
        200) fail "overlay refuses no key" "answered 200 without a key" ;;
        *) warn "overlay refuses no key" "unexpected reply ${overlay_no_key:-none}" ;;
        esac
      fi
    fi
    ;;
  esac

  if ufw_overlay="$(sudo ufw status 2>/dev/null)"; then
    if grep -qE "^${swap_port}/tcp on ${overlay_iface} +ALLOW" <<<"$ufw_overlay"; then
      ok "model port rule" "${swap_port}/tcp on $overlay_iface"
    elif grep -qE "^${swap_port}/tcp +ALLOW" <<<"$ufw_overlay"; then
      fail "model port rule" "${swap_port}/tcp is open on every interface"
    else
      pending "model port rule" "none, peers cannot reach the model API"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "Sandboxes"
# ---------------------------------------------------------------------------
#
# The agents run here. Each check is one thing that stops a sandbox from
# starting, or stops it from outliving the SSH session that started it.

if have sbx; then
  ok "sbx" "$(sbx version 2>/dev/null | head -1 || echo installed)"
else
  pending "sbx" "not installed, run setup 22_sandboxes"
fi

if [[ -e /dev/kvm ]]; then
  kvm_group="$(stat -c '%G' /dev/kvm)"
  # `id -nG` with no name reads this session, and with a name reads the group
  # file. In the file and not in the session means the change came after this
  # login.
  if id -nG | tr ' ' '\n' | grep -qx "$kvm_group"; then
    ok "kvm access" "$USER is in $kvm_group"
  elif id -nG "$USER" | tr ' ' '\n' | grep -qx "$kvm_group"; then
    fail "kvm access" "$USER was added to $kvm_group after this login, log out and back in"
  else
    fail "kvm access" "$USER is not in $kvm_group, run setup 10_packages"
  fi
else
  fail "kvm access" "/dev/kvm is missing, turn on SVM in the firmware setup"
fi

linger="$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)"
if [[ "$linger" == "yes" ]]; then
  ok "linger" "on, agents outlive the SSH session"
else
  fail "linger" "${linger:-unknown}, run setup 22_sandboxes"
fi

# The path that pi agents use: from inside a sandbox, through the sbx proxy, to
# loopback on this machine. Only a running sandbox can test it, and starting
# one here would take minutes, so the check runs when one is named:
#
#   AI_WORKSTATION_PROBE_SANDBOX=<sandbox name> doctor
#
# The reply code says where the request stopped. 403 is the sbx proxy, 401 is
# llama-swap without the key, and 200 is the whole path working.
probe_sandbox="${AI_WORKSTATION_PROBE_SANDBOX:-}"
probe_port="${AI_WORKSTATION_MODEL_PORT:-8080}"
if [[ -z "$probe_sandbox" ]]; then
  pending "sandbox to model" "name a running pi-ailo sandbox in AI_WORKSTATION_PROBE_SANDBOX"
elif ! have sbx; then
  fail "sandbox to model" "sbx is not installed"
else
  # The header carries the sentinel the kit puts in the sandbox. The proxy
  # replaces it with the real key on its way out.
  probe_code="$(timeout 30 sbx exec "$probe_sandbox" -- sh -c \
    "curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H \"Authorization: Bearer \${MODEL_API_KEY:-none}\" http://host.docker.internal:$probe_port/v1/models" \
    2>/dev/null)"
  case "$probe_code" in
  200) ok "sandbox to model" "$probe_sandbox reaches host.docker.internal:$probe_port with the key" ;;
  401) fail "sandbox to model" "reached llama-swap without the key, check the model-server secret" ;;
  403) fail "sandbox to model" "the sbx proxy refused it, allow localhost:$probe_port (bootstrap.md)" ;;
  "") fail "sandbox to model" "could not run curl in $probe_sandbox" ;;
  *) fail "sandbox to model" "reply $probe_code from host.docker.internal:$probe_port" ;;
  esac
fi

# ---------------------------------------------------------------------------
section "Power"
# ---------------------------------------------------------------------------
#
# A machine that sleeps drops every SSH session and stops every agent.

for target in sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target; do
  target_state="$(systemctl is-enabled "$target" 2>/dev/null)"
  if [[ "$target_state" == "masked" ]]; then
    ok "$target" "masked"
  else
    fail "$target" "${target_state:-unknown}, run setup 05_hardening"
  fi
done

# ---------------------------------------------------------------------------
section "Updates"
# ---------------------------------------------------------------------------
#
# The pinned versions are read out of 20_llama rather than repeated here, so
# there is one place to change when a pin moves.
#
# Upgrading is manual on purpose: a new llama.cpp build can change inference
# behaviour, so it is raised deliberately rather than picked up by a package
# manager. These checks are what make "manual" mean "decided" rather than
# "forgotten".

# The root filesystem is unlocked by a person at the console, so a reboot that
# nobody asked for leaves the machine down until someone is at the keyboard.
# apt-config prints the merged value, which is the one unattended-upgrades
# reads, whatever file set it.
if have apt-config; then
  auto_reboot="$(apt-config dump 2>/dev/null |
    sed -n 's/^Unattended-Upgrade::Automatic-Reboot "\(.*\)";$/\1/p' | tail -1)"
  case "$auto_reboot" in
  false) ok "unattended reboot" "off" ;;
  "") warn "unattended reboot" "not set, the package default applies, run setup 05_hardening" ;;
  *) fail "unattended reboot" "$auto_reboot, the machine can restart into a locked disk" ;;
  esac
fi

# Matches the default in a line such as:
#   llama_build="${LLAMA_CPP_BUILD:-b11057}"
pin_from_20_llama() {
  sed -n "s/^$1=.*:-\([^}]*\)}.*/\1/p" "$profile_dir/20_llama" 2>/dev/null | head -1
}

llama_pinned="$(pin_from_20_llama llama_build)"
swap_pinned="$(pin_from_20_llama swap_version)"

# What is on disk, which is the version actually serving requests. It can
# differ from the pin when the pin moved and setup has not run since.
llama_installed=""
[[ -L /opt/llama.cpp/current ]] &&
  llama_installed="$(basename "$(readlink -f /opt/llama.cpp/current)")"

swap_installed=""
[[ -L /opt/llama-swap/current ]] &&
  swap_installed="$(basename "$(readlink -f /opt/llama-swap/current)")"

# Pin against installed. A difference here is fixed by running setup, and
# needs no network, so it is reported before the upstream comparison.
if [[ -n "$llama_installed" && -n "$llama_pinned" && "$llama_installed" != "$llama_pinned" ]]; then
  warn "llama.cpp pin" "20_llama pins $llama_pinned, $llama_installed installed, run setup"
fi
if [[ -n "$swap_installed" && -n "$swap_pinned" && "$swap_installed" != "$swap_pinned" ]]; then
  warn "llama-swap pin" "20_llama pins $swap_pinned, $swap_installed installed, run setup"
fi

# Installed against upstream. A warning here is a decision to make, not a
# fault: the machine works, and a newer build may or may not be worth taking.
check_release "llama.cpp" ggml-org/llama.cpp "${llama_installed:-$llama_pinned}" b
check_release "llama-swap" mostlygeek/llama-swap "${swap_installed:-$swap_pinned}" v

# ---------------------------------------------------------------------------
section "Tunables"
# ---------------------------------------------------------------------------
#
# Choices, not results. Everything above answers "is this working"; this
# answers "what did I decide, and what could I decide instead".
#
# The machine's settings come from the same table `ai-workstation` reads, so a knob
# added there appears here with no change. The per-model rows come from the
# registry `ai-model` writes.

ai_workstation_pkg="$profile_dir/commands/ai-workstation"
ai_model_pkg="$profile_dir/commands/ai-model"

# The machine's answers, so the values below are the ones in effect rather than
# the owning script's fallbacks.
if [[ -r "$profile_dir/lib/config.sh" ]]; then
  # shellcheck source=../lib/config.sh
  source "$profile_dir/lib/config.sh"
  ai_workstation_config_load
fi

if [[ -r "$ai_workstation_pkg/lib/keys" ]]; then
  # shellcheck source=../commands/ai-workstation/lib/keys
  source "$ai_workstation_pkg/lib/keys"

  for knob in "${knob_order[@]}"; do
    knob_value="${!knob_var[$knob]:-}"
    printf -v knob_detail '%-10s  %s' "${knob_value:--}" "${knob_accepts[$knob]}"
    tunable "$knob" "$knob_detail"
  done

  echo
  printf '  %-7s %-34s %s\n' "" "" "ai-workstation set <name> <value>"
  echo
else
  pending "machine settings" "the ai-workstation command is missing, run setup 30_tools"
fi

# Per-model context and cache. A model is only listed when it is on disk: an
# entry left behind for a model that is gone is a stale setting, not a choice.
if [[ -r "$ai_model_pkg/lib/registry" ]]; then
  settings_file="/var/lib/llama/settings.json"
  # shellcheck source=../commands/ai-model/lib/registry
  source "$ai_model_pkg/lib/registry"

  model_rows=0
  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    model_rows=$((model_rows + 1))

    model_ctx="$(registry_get "$model" ctx "<unset>")"
    model_trained="$(registry_get "$model" trained_ctx 0)"
    model_cache="$(registry_get "$model" cache_type "-")"

    # A model copied in by hand has no repository to ask, so its ceiling is
    # unknown rather than absent. Said plainly, because a context cannot be
    # checked against a number nobody has.
    if [[ "$model_trained" == "0" ]]; then
      model_ceiling="trained max unknown"
    else
      model_ceiling="of $model_trained trained"
    fi

    printf -v model_detail '%-10s  %s, cache %s' "$model_ctx" "$model_ceiling" "$model_cache"
    tunable "${model:0:32}" "$model_detail"
  done < <(find /var/lib/llama/models -maxdepth 1 -type f -name '*.gguf' -printf '%f\n' 2>/dev/null |
    sed -E 's/-[0-9]{5}-of-[0-9]{5}\.gguf$//; s/\.gguf$//' | sort -u)

  if [[ "$model_rows" -gt 0 ]]; then
    echo
    printf '  %-7s %-34s %s\n' "" "" "ai-model ctx <model> [tokens|--measure]"
    printf '  %-7s %-34s %s\n' "" "" "ai-model cache <model> <type>"
  fi
fi
