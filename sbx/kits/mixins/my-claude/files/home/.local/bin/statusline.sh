#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_TOKENS=$(echo "$input" | jq -r '.context_window.current_usage | if . then .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens else 0 end')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESETS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESETS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

bar_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$pct" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

make_bar() {
  local pct=$1
  local color; color=$(bar_color "$pct")
  local filled=$((pct / 10))
  local empty=$((10 - filled))
  printf -v fill "%${filled}s"
  printf -v pad "%${empty}s"
  printf '%b%s%s%b' "$color" "${fill// /█}${pad// /░}" "" "$RESET"
}

fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf '%d.%dM' $((n / 1000000)) $(((n % 1000000) / 100000))
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' $((n / 1000))
  else
    printf '%d' "$n"
  fi
}

reset_str() {
  local secs=$1
  if [ "$secs" -le 0 ]; then
    echo "now"
  elif [ "$secs" -lt 3600 ]; then
    echo "$((secs / 60))m"
  elif [ "$secs" -lt 86400 ]; then
    echo "$((secs / 3600))h$(((secs % 3600) / 60))m"
  else
    echo "$((secs / 86400))d$(((secs % 86400) / 3600))h"
  fi
}

MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir >/dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

echo "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"

# Memory: the cgroup v2 limit is the sandbox's allocation, not the host's.
MEM_CUR=""
MEM_MAX=""
if [ -r /sys/fs/cgroup/memory.current ] && [ -r /sys/fs/cgroup/memory.max ]; then
  MEM_CUR=$(cat /sys/fs/cgroup/memory.current)
  MEM_MAX=$(cat /sys/fs/cgroup/memory.max)
  if [ "$MEM_MAX" = "max" ]; then
    MEM_MAX=$(awk '/^MemTotal:/{print $2*1024}' /proc/meminfo)
  fi
elif [ -r /proc/meminfo ]; then
  MEM_MAX=$(awk '/^MemTotal:/{print $2*1024}' /proc/meminfo)
  MEM_CUR=$((MEM_MAX - $(awk '/^MemAvailable:/{print $2*1024}' /proc/meminfo)))
fi

MEM_SEG=""
if [ "$MEM_MAX" -gt 0 ] 2>/dev/null; then
  read -r MEM_USED_G MEM_MAX_G MEM_PCT <<<"$(awk -v c="$MEM_CUR" -v m="$MEM_MAX" \
    'BEGIN{printf "%.1f %.1f %d", c/1073741824, m/1073741824, (c*100)/m}')"
  MEM_SEG=" | $(bar_color "$MEM_PCT")mem ${MEM_USED_G}/${MEM_MAX_G}G${RESET}"
fi

LOAD_SEG=""
[ -r /proc/loadavg ] && LOAD_SEG=" | load $(awk '{print $1}' /proc/loadavg)"

# Do not use an emoji that has a variation selector (U+FE0F), such as the stopwatch.
# Programs measure those at different widths, and Claude Code repaints only the
# changed cells, so a difference puts later digits in the wrong cells.
COST_FMT=$(printf '$%.2f' "$COST")
CTX_BAR=$(make_bar "$CTX_PCT")
echo "🧠 ${CTX_BAR} $(fmt_tokens "$CTX_TOKENS") | ${YELLOW}${COST_FMT}${RESET} | ⏳ ${MINS}m ${SECS}s${MEM_SEG}${LOAD_SEG}"

if [ -n "$FIVE_H_PCT" ] && [ -n "$WEEK_PCT" ]; then
  NOW=$(date +%s)
  FIVE_H_INT=$(echo "$FIVE_H_PCT" | cut -d. -f1)
  WEEK_INT=$(echo "$WEEK_PCT" | cut -d. -f1)

  FIVE_H_BAR=$(make_bar "$FIVE_H_INT")
  WEEK_BAR=$(make_bar "$WEEK_INT")

  FIVE_H_RESET=""
  if [ -n "$FIVE_H_RESETS" ]; then
    FIVE_H_RESET=" resets $(reset_str $((FIVE_H_RESETS - NOW)))"
  fi

  WEEK_RESET=""
  if [ -n "$WEEK_RESETS" ]; then
    WEEK_RESET=" resets $(reset_str $((WEEK_RESETS - NOW)))"
  fi

  echo "---"
  echo "🪙 ${FIVE_H_BAR} ${FIVE_H_INT}%${FIVE_H_RESET} | ${WEEK_BAR} ${WEEK_INT}%${WEEK_RESET}"
fi
