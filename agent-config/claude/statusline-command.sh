#!/bin/bash
# Claude Code statusline: model (colour by tier), cwd, branch, context, weekly allowance.
# Tracked in ~/.dotfiles/agent-config/claude and linked by agent-config/install.sh.

input=$(cat)

model_name=$(echo "$input" | jq -r '.model.display_name // "unknown"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
transcript=$(echo "$input" | jq -r '.transcript_path // ""')

# Context tokens in use, so a session nearing the window is visible before
# it compacts. Colours match Pi's catppuccin-mocha footer: green below 70%,
# yellow 70-84%, red at 85% or higher.
tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tokens=$(python3 "$HOME/.claude/statusline-tokens.py" "$transcript" 2>/dev/null)
fi
token_color="38;2;166;227;161"
case "$tokens" in
  *"/"1[0-9][0-9]"%"|*"/"9[0-9]"%"|*"/"8[5-9]"%") token_color="38;2;243;139;168" ;;
  *"/"7[0-9]"%"|*"/"8[0-4]"%") token_color="38;2;249;226;175" ;;
esac

# Weekly allowance left, coloured like Pi: muted above 20%, yellow at 20% and
# below, maroon at 10% and below. Claude.ai plans only; absent otherwise.
weekly=""
weekly_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$weekly_used" ]; then
  weekly=$(awk -v u="$weekly_used" 'BEGIN { r = 100 - int(u + 0.5); print (r < 0 ? 0 : r > 100 ? 100 : r) }')
fi
weekly_color="38;2;127;132;156"
if [ -n "$weekly" ]; then
  if [ "$weekly" -le 10 ]; then weekly_color="38;2;235;160;172"
  elif [ "$weekly" -le 20 ]; then weekly_color="38;2;249;226;175"
  fi
fi


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
if [ -n "$weekly" ]; then
  printf " \033[2m|\033[0m \033[%smweekly %s%% left\033[0m" "$weekly_color" "$weekly"
fi
printf "\n"
