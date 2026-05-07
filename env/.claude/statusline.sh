#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESETS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESETS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

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

COST_FMT=$(printf '$%.2f' "$COST")
CTX_BAR=$(make_bar "$CTX_PCT")
echo "🧠 ${CTX_BAR} ${CTX_PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"

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
