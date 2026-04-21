#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

fmt_remaining() {
  local reset="$1"
  [ -z "$reset" ] && return
  local reset_epoch
  case "$reset" in
    ''|*[!0-9]*)
      local clean_iso="${reset%.*}"
      case "$clean_iso" in *Z) ;; *) clean_iso="${clean_iso}Z" ;; esac
      reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_iso" "+%s" 2>/dev/null) || \
        reset_epoch=$(date -d "$reset" "+%s" 2>/dev/null)
      ;;
    *)
      reset_epoch="$reset"
      ;;
  esac
  [ -z "$reset_epoch" ] && return
  local now diff h m
  now=$(date "+%s")
  diff=$((reset_epoch - now))
  [ "$diff" -le 0 ] && { printf "0m"; return; }
  h=$((diff / 3600))
  m=$(((diff % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf "%dh %dm" "$h" "$m"
  else printf "%dm" "$m"; fi
}

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
if [ -n "$FIVE_H" ]; then
  LINE2="${LINE2} | 5h $(make_bar "$FIVE_H" "$PASTEL_CYAN")"
  FIVE_H_LEFT=$(fmt_remaining "$FIVE_H_RESET")
  [ -n "$FIVE_H_LEFT" ] && LINE2="${LINE2} (${FIVE_H_LEFT})"
fi
if [ -n "$WEEK" ]; then
  LINE2="${LINE2} | 7d $(make_bar "$WEEK" "$PASTEL_ORANGE")"
  WEEK_LEFT=$(fmt_remaining "$WEEK_RESET")
  [ -n "$WEEK_LEFT" ] && LINE2="${LINE2} (${WEEK_LEFT})"
fi

echo "${LINE2}"
