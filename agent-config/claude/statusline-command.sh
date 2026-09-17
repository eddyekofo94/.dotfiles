#!/bin/bash
# Claude Code statusline: model (colour by tier), cwd, branch, context, session and weekly allowance.
# Tracked in ~/.dotfiles/agent-config/claude and linked by agent-config/install.sh.

input=$(cat)

model_name=$(echo "$input" | jq -r '.model.display_name // "unknown"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
transcript=$(echo "$input" | jq -r '.transcript_path // ""')

# Context tokens in use, so a session nearing the window is visible before
# it compacts. Colours match Pi's catppuccin-mocha footer: green below 70%,
# yellow 70-84%, red at 85% or higher.
# The window comes from Claude's own input when present; otherwise a [1m]
# model id means 1M tokens, and anything else the standard 200k.
window=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -z "$window" ]; then
  case "$model_id" in
    *"[1m]"*) window=1000000 ;;
    *)        window=200000 ;;
  esac
fi
tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tokens=$(python3 "$(dirname -- "$0")/statusline-tokens.py" "$transcript" "$window" 2>/dev/null)
fi
token_color="38;2;166;227;161"
case "$tokens" in
  *"/"1[0-9][0-9]"%"|*"/"9[0-9]"%"|*"/"8[5-9]"%") token_color="38;2;243;139;168" ;;
  *"/"7[0-9]"%"|*"/"8[0-4]"%") token_color="38;2;249;226;175" ;;
esac

# Session (five-hour) and weekly allowance left, coloured like Pi: muted above
# 20%, yellow at 20% and below, maroon at 10% and below. Claude.ai plans only;
# each half is absent when Claude does not report that window.
allowance_left() {
  used=$(echo "$input" | jq -r "$1 // empty")
  [ -n "$used" ] || return 0
  awk -v u="$used" 'BEGIN { r = 100 - int(u + 0.5); print (r < 0 ? 0 : r > 100 ? 100 : r) }'
}
allowance_color() {
  if [ "$1" -le 10 ]; then echo "38;2;235;160;172"
  elif [ "$1" -le 20 ]; then echo "38;2;249;226;175"
  else echo "38;2;127;132;156"
  fi
}
# Countdown to a window's reset, "Xh" at an hour or more, else "Xm" (floored
# to 1m so a live reset never reads "0m"). Pure arithmetic, no subprocess.
time_left() {
  diff=$(( $1 - $(date +%s) ))
  [ "$diff" -gt 0 ] || { echo "now"; return; }
  hours=$(( diff / 3600 ))
  if [ "$hours" -ge 1 ]; then echo "${hours}h"; else
    minutes=$(( (diff % 3600) / 60 ))
    echo "$(( minutes > 0 ? minutes : 1 ))m"
  fi
}
allowance=""
for pair in "S five_hour" "W seven_day"; do
  label=${pair% *}
  window=".rate_limits.${pair#* }"
  left=$(allowance_left "$window.used_percentage")
  [ -n "$left" ] || continue
  resets=$(echo "$input" | jq -r "$window.resets_at // empty")
  segment="$label: $left%"
  [ -z "$resets" ] || segment="$segment ($(time_left "$resets"))"
  [ -z "$allowance" ] || allowance="$allowance "
  allowance="$allowance\033[$(allowance_color "$left")m$segment\033[0m"
done


# Color-code the model name so a tier change is immediately obvious.
tier=$(echo "${model_id:-$model_name}" | tr "[:upper:]" "[:lower:]")
case "$tier" in
  *opus*)   model_color="35" ;; # magenta
  *sonnet*) model_color="36" ;; # cyan
  *haiku*)  model_color="32" ;; # green
  *fable*)  model_color="33" ;; # yellow
  *)        model_color="37" ;; # white
esac

dir_basename=$(basename "$cwd")

branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi

printf "\033[1;%sm%s\033[0m \033[2m|\033[0m %s" "$model_color" "$model_name" "$dir_basename"
if [ -n "$branch" ]; then
  printf " \033[2m|\033[0m \033[2m%s\033[0m" "$branch"
fi
if [ -n "$tokens" ]; then
  printf " \033[2m|\033[0m \033[%sm%s\033[0m" "$token_color" "$tokens"
fi
if [ -n "$allowance" ]; then
  printf " \033[2m|\033[0m %b" "$allowance"
fi
printf "\n"
