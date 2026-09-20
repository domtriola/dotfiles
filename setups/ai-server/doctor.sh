# Checks for the ai-server profile. Sourced by ./doctor, which supplies
# section, ok, warn, fail, pending and have.
#
# No execute bit: ./setup runs every executable file in this directory, and
# these are not setup steps.
#
# Each check reports what it found rather than only whether it passed, because
# most of the faults this machine can have are quiet ones. A GPU that fell back
# to software, a drop-in file that lost to another, and a memory limit that was
# ignored all look like a working server until the number is read.

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

  if grep -qE '^22/tcp .*LIMIT' <<<"$ufw_status"; then
    ok "ssh rule" "22/tcp LIMIT"
  elif grep -qE '^22/tcp .*ALLOW' <<<"$ufw_status"; then
    warn "ssh rule" "22/tcp ALLOW, not rate limited"
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

grub_dropin="/etc/default/grub.d/99-ai-server.cfg"
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

# Not built yet. These report as pending rather than failing, so the summary
# distinguishes "broken" from "not reached yet".
if have llama-server; then
  ok "llama-server" "$(command -v llama-server)"
else
  pending "llama-server" "not installed, 20_llama is not written"
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^llama-swap'; then
  if systemctl is-active --quiet llama-swap; then
    ok "llama-swap service" "active"
  else
    fail "llama-swap service" "installed but not active"
  fi
else
  pending "llama-swap service" "not installed"
fi

# ---------------------------------------------------------------------------
section "Overlay network"
# ---------------------------------------------------------------------------

if have netbird; then
  if netbird status 2>/dev/null | grep -qi 'management: connected'; then
    ok "netbird" "connected"
  else
    warn "netbird" "installed but not connected"
  fi
else
  pending "netbird" "not installed, 25_netbird is not written"
fi

if ! have ip; then
  warn "wt0 interface" "ip is not installed, not checked"
elif ip link show wt0 >/dev/null 2>&1; then
  ok "wt0 interface" "up"
else
  pending "wt0 interface" "absent until netbird registers"
fi
