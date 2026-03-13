#!/bin/bash
# Claude Code Status Line
# Shows: model | $sess $today (Nx value) | tokens (msgs, avg/msg) | +lines | ctx%
#        vs 7d avg indicator
#
# Receives JSON session data on stdin from Claude Code
# Tracks: message count, daily cost ledger, persistent analytics, session duration
# Adapted for Windows (Git Bash)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYTICS_DIR="${SCRIPT_DIR}/analytics"
mkdir -p "$ANALYTICS_DIR"

input=$(cat)

# --- Extract data ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
if [ "${ANTHROPIC_MODEL:-}" = "opusplan" ]; then
  MODEL="${MODEL} (OpusPlan)"
fi
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf '%.2f' "$COST")
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Tokens are under context_window
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# --- Track message count per session ---
COUNTER_FILE="/tmp/cc-statusline-${SESSION_ID}"
if [ -f "$COUNTER_FILE" ]; then
  MSG_COUNT=$(cat "$COUNTER_FILE")
  MSG_COUNT=$((MSG_COUNT + 1))
else
  MSG_COUNT=1
fi
echo "$MSG_COUNT" > "$COUNTER_FILE"

# --- Track session start time ---
START_FILE="/tmp/cc-session-start-${SESSION_ID}"
if [ ! -f "$START_FILE" ]; then
  date +%s > "$START_FILE"
fi
SESSION_START=$(cat "$START_FILE")
SESSION_SECS=$(( $(date +%s) - SESSION_START ))
SESSION_MINS=$((SESSION_SECS / 60))
if [ "$SESSION_MINS" -ge 60 ]; then
  DURATION_FMT="$((SESSION_MINS / 60))h$((SESSION_MINS % 60))m"
else
  DURATION_FMT="${SESSION_MINS}m"
fi

# --- Track peak context % and compactions ---
PEAK_FILE="/tmp/cc-peak-ctx-${SESSION_ID}"
COMPACT_FILE="/tmp/cc-compactions-${SESSION_ID}"
LAST_CTX_FILE="/tmp/cc-last-ctx-${SESSION_ID}"

PEAK_CTX=0
if [ -f "$PEAK_FILE" ]; then
  PEAK_CTX=$(cat "$PEAK_FILE")
fi
if [ "$CTX_PCT" -gt "$PEAK_CTX" ]; then
  PEAK_CTX="$CTX_PCT"
  echo "$PEAK_CTX" > "$PEAK_FILE"
fi

# Detect compaction: context drops by 20%+ from last check
COMPACTIONS=0
if [ -f "$COMPACT_FILE" ]; then
  COMPACTIONS=$(cat "$COMPACT_FILE")
fi
if [ -f "$LAST_CTX_FILE" ]; then
  LAST_CTX=$(cat "$LAST_CTX_FILE")
  DROP=$((LAST_CTX - CTX_PCT))
  if [ "$DROP" -ge 20 ]; then
    COMPACTIONS=$((COMPACTIONS + 1))
    echo "$COMPACTIONS" > "$COMPACT_FILE"
  fi
fi
echo "$CTX_PCT" > "$LAST_CTX_FILE"

# --- Daily ledger (cost, tokens, lines per session) ---
TODAY=$(date +%Y-%m-%d)
DAILY_LEDGER="/tmp/cc-daily-ledger-${TODAY}"

# Format: session_id cost tokens lines_added lines_removed
if [ -f "$DAILY_LEDGER" ]; then
  grep -v "^${SESSION_ID} " "$DAILY_LEDGER" > "${DAILY_LEDGER}.tmp" 2>/dev/null || true
  mv "${DAILY_LEDGER}.tmp" "$DAILY_LEDGER"
fi
echo "${SESSION_ID} ${COST} ${TOTAL_TOKENS} ${LINES_ADDED} ${LINES_REMOVED}" >> "$DAILY_LEDGER"

# Sum daily metrics
DAILY_COST=$(awk '{sum += $2} END {printf "%.2f", sum}' "$DAILY_LEDGER" 2>/dev/null || echo "0.00")
DAILY_TOKENS=$(awk '{sum += $3} END {printf "%d", sum}' "$DAILY_LEDGER" 2>/dev/null || echo "0")
DAILY_LINES_ADD=$(awk '{sum += $4} END {printf "%d", sum}' "$DAILY_LEDGER" 2>/dev/null || echo "0")
DAILY_LINES_REM=$(awk '{sum += $5} END {printf "%d", sum}' "$DAILY_LEDGER" 2>/dev/null || echo "0")
DAILY_SESSIONS=$(wc -l < "$DAILY_LEDGER" | tr -d ' ')

# --- Persist daily snapshot to analytics file ---
ANALYTICS_FILE="${ANALYTICS_DIR}/daily.jsonl"
if [ -f "$ANALYTICS_FILE" ]; then
  grep -v "\"date\":\"${TODAY}\"" "$ANALYTICS_FILE" > "${ANALYTICS_FILE}.tmp" 2>/dev/null || true
  mv "${ANALYTICS_FILE}.tmp" "$ANALYTICS_FILE"
fi
printf '{"date":"%s","cost":%.2f,"tokens":%d,"lines_added":%d,"lines_removed":%d,"sessions":%d,"peak_ctx":%d}\n' \
  "$TODAY" "$DAILY_COST" "$DAILY_TOKENS" "$DAILY_LINES_ADD" "$DAILY_LINES_REM" "$DAILY_SESSIONS" "$PEAK_CTX" \
  >> "$ANALYTICS_FILE"

# --- Load 7-day average from cache (updated in background) ---
AVG_CACHE="/tmp/cc-7d-avg-cache"
AVG_7D="0"
if [ -f "$AVG_CACHE" ]; then
  AVG_7D=$(cat "$AVG_CACHE")
fi

# Background: recalculate 7-day average (non-blocking)
(
  if [ -f "$ANALYTICS_FILE" ]; then
    WEEK_TOTAL=0
    WEEK_DAYS=0
    for i in $(seq 1 7); do
      PAST_DATE=$(date -d "-${i} days" +%Y-%m-%d 2>/dev/null)
      DAY_COST=$(grep "\"date\":\"${PAST_DATE}\"" "$ANALYTICS_FILE" 2>/dev/null | python3 -c "import json,sys; [print(json.loads(l).get('cost',0)) for l in sys.stdin]" 2>/dev/null | head -1)
      if [ -n "$DAY_COST" ] && [ "$DAY_COST" != "0" ]; then
        WEEK_TOTAL=$(python3 -c "print($WEEK_TOTAL + $DAY_COST)")
        WEEK_DAYS=$((WEEK_DAYS + 1))
      fi
    done
    if [ "$WEEK_DAYS" -gt 0 ]; then
      python3 -c "print($WEEK_TOTAL / $WEEK_DAYS)" > "$AVG_CACHE"
    fi
  fi
) &>/dev/null &

# --- Format helpers ---
fmt_tokens() {
  local t=$1
  if [ "$t" -ge 1000000 ]; then
    printf '%.1fM' "$(python3 -c "print($t / 1000000)")"
  elif [ "$t" -ge 1000 ]; then
    printf '%.1fk' "$(python3 -c "print($t / 1000)")"
  else
    printf '%s' "$t"
  fi
}

TOKENS_FMT=$(fmt_tokens "$TOTAL_TOKENS")

# --- Avg tokens per message ---
if [ "$MSG_COUNT" -gt 0 ] && [ "$TOTAL_TOKENS" -gt 0 ]; then
  AVG_TOKENS=$((TOTAL_TOKENS / MSG_COUNT))
  AVG_FMT=$(fmt_tokens "$AVG_TOKENS")
else
  AVG_FMT="—"
fi

# --- Lines today ---
LINES_FMT="+${DAILY_LINES_ADD}/-${DAILY_LINES_REM}"

# --- ANSI colors ---
RST="\033[0m"
DIM="\033[37m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
BLUE="\033[34m"
MAGENTA="\033[35m"
WHITE="\033[37m"

# --- Context color + blink warning ---
BLINK="\033[5m"
CTX_WARN=""
if [ "$CTX_PCT" -ge 80 ]; then
  CTX_COLOR="$RED"
  CTX_WARN=" ${BLINK}${RED}⚠${RST}"
elif [ "$CTX_PCT" -ge 70 ]; then
  CTX_COLOR="$YELLOW"
  CTX_WARN=" ${BLINK}${YELLOW}⚠${RST}"
elif [ "$CTX_PCT" -ge 50 ]; then
  CTX_COLOR="$YELLOW"
else
  CTX_COLOR="$GREEN"
fi

# --- Session cost color ---
COST_INT=$(printf '%.0f' "$COST")
if [ "$COST_INT" -ge 20 ]; then COST_COLOR="$RED"
elif [ "$COST_INT" -ge 5 ]; then COST_COLOR="$YELLOW"
else COST_COLOR="$GREEN"; fi

# --- Daily cost color ---
DAILY_INT=$(printf '%.0f' "$DAILY_COST")
if [ "$DAILY_INT" -ge 75 ]; then DAILY_COLOR="$RED"
elif [ "$DAILY_INT" -ge 25 ]; then DAILY_COLOR="$YELLOW"
else DAILY_COLOR="$GREEN"; fi

# --- Value multiplier ---
MAX_MONTHLY=200
DAYS_IN_MONTH=$(python3 -c "import calendar, datetime; t=datetime.date.today(); print(calendar.monthrange(t.year, t.month)[1])")
DAILY_SUB_COST=$(python3 -c "print($MAX_MONTHLY / $DAYS_IN_MONTH)")

if [ "$(python3 -c "print(1 if $DAILY_COST > 0 else 0)")" -eq 1 ]; then
  VALUE_MULT=$(python3 -c "print($DAILY_COST / $DAILY_SUB_COST)")
  VALUE_FMT=$(printf '%.1fx' "$VALUE_MULT")
else
  VALUE_FMT="—"
fi

# --- 7-day trend indicator ---
TREND=""
if [ -n "$AVG_7D" ] && [ "$(python3 -c "print(1 if float('$AVG_7D') > 0 else 0)" 2>/dev/null)" = "1" ]; then
  RATIO=$(python3 -c "print($DAILY_COST / $AVG_7D)" 2>/dev/null || echo "1")
  if [ "$(python3 -c "print(1 if $RATIO > 2.0 else 0)" 2>/dev/null)" = "1" ]; then
    TREND=" ${RED}▲▲${RST}"
  elif [ "$(python3 -c "print(1 if $RATIO > 1.3 else 0)" 2>/dev/null)" = "1" ]; then
    TREND=" ${YELLOW}▲${RST}"
  elif [ "$(python3 -c "print(1 if $RATIO < 0.5 else 0)" 2>/dev/null)" = "1" ]; then
    TREND=" ${GREEN}▼${RST}"
  fi
fi

# --- Output (multi-line) ---
LINE0=$(printf "${BOLD}${MAGENTA}%s${RST}" "$MODEL")

# --- Duration color (green < 30m, yellow < 60m, red >= 60m) ---
if [ "$SESSION_MINS" -ge 60 ]; then DUR_COLOR="$RED"
elif [ "$SESSION_MINS" -ge 30 ]; then DUR_COLOR="$YELLOW"
else DUR_COLOR="$GREEN"; fi

LINE1=$(printf "${DIM}session summary:${RST} ${DUR_COLOR}%s${RST} ${DIM}·${RST} ${BLUE}%s${RST} ${DIM}msgs ·${RST} ${CYAN}~%s${RST} ${DIM}tokens/msg${RST}" \
  "$DURATION_FMT" "$MSG_COUNT" "$AVG_FMT")

LINE2=$(printf "${DIM}session cost:${RST} ${COST_COLOR}\$%s${RST} ${DIM}·${RST} ${CYAN}%s${RST} ${DIM}tokens${RST}" \
  "$COST_FMT" "$TOKENS_FMT")

DAILY_TOKENS_FMT=$(fmt_tokens "$DAILY_TOKENS")

LINE3=$(printf "${DIM}session costs:${RST} ${DAILY_COLOR}\$%s${RST} ${DIM}·${RST} ${CYAN}%s${RST} ${DIM}tokens (today)${RST}%s" \
  "$DAILY_COST" "$DAILY_TOKENS_FMT" "$TREND")

LINE4=$(printf "${DIM}value gained:${RST} ${GREEN}%s with \$%.0f/mo sub${RST}" \
  "$VALUE_FMT" "$MAX_MONTHLY")

COMPACT_STR=""
if [ "$COMPACTIONS" -gt 0 ]; then
  COMPACT_STR=$(printf " ${DIM}· %s compaction%s${RST}" "$COMPACTIONS" "$([ "$COMPACTIONS" -ne 1 ] && echo 's')")
fi

if [ -n "$CTX_WARN" ]; then
  LINE5=$(printf "${BLINK}${CTX_COLOR}context: %s%% (peak %s%%) ⚠${RST}%b" \
    "$CTX_PCT" "$PEAK_CTX" "$COMPACT_STR")
else
  LINE5=$(printf "${DIM}context:${RST} ${CTX_COLOR}%s%%${RST} ${DIM}(peak %s%%)${RST}%b" \
    "$CTX_PCT" "$PEAK_CTX" "$COMPACT_STR")
fi

LINE6=$(printf "${DIM}today's effort:${RST} ${WHITE}%s${RST} ${DIM}lines changed${RST}" "$LINES_FMT")

printf "\n%b\n%b\n%b\n%b\n%b\n%b\n%b" "$LINE0" "$LINE1" "$LINE2" "$LINE3" "$LINE4" "$LINE5" "$LINE6"
