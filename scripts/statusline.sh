#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
RESET='\033[0m'
PASTEL_CYAN='\033[38;5;117m'; PASTEL_ORANGE='\033[38;5;216m'
PASTEL_YELLOW='\033[38;5;222m'; PASTEL_RED='\033[38;5;210m'

make_bar() {
  local pct="$1" base_color="$2"
  local color
  if [ "$pct" -ge 90 ]; then color="$PASTEL_RED"
  elif [ "$pct" -ge 70 ]; then color="$PASTEL_YELLOW"
  else color="$base_color"; fi
  local filled=$((pct / 10)) empty=$((10 - pct / 10))
  local bar
  bar=$(printf "%${filled}s" | tr ' ' '█')$(printf "%${empty}s" | tr ' ' '░')
  printf '%s%s%s %s%%' "$color" "$bar" "$RESET" "$pct"
}

if [ "$PCT" -ge 90 ]; then CTX_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

CTX_FILLED=$((PCT / 10)); CTX_EMPTY=$((10 - CTX_FILLED))
CTX_BAR=$(printf "%${CTX_FILLED}s" | tr ' ' '█')$(printf "%${CTX_EMPTY}s" | tr ' ' '░')

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

printf "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH\n"

LINE2="ctx ${CTX_COLOR}${CTX_BAR}${RESET} ${PCT}%"
[ -n "$FIVE_H" ] && LINE2="${LINE2} | 5h $(make_bar "$FIVE_H" "$PASTEL_CYAN")"
[ -n "$WEEK" ]   && LINE2="${LINE2} | 7d $(make_bar "$WEEK" "$PASTEL_ORANGE")"

echo -e "${LINE2}"
