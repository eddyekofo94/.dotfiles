#!/usr/bin/env bash

selected=$(find ~/projects ~/work ~/code -type d -maxdepth 3 2>/dev/null | fzf --prompt="Session: ")

if [[ -z $selected ]]; then
	exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $tmux_running ]]; then
	tmux new-session -s "$selected_name" -c "$selected"
	exit 0
fi

if ! tmux has-session -t="$selected_name" 2>/dev/null; then
	tmux new-session -d -s "$selected_name" -c "$selected"
fi

tmux switch-client -t "$selected_name"
