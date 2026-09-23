#!/usr/bin/env zsh
set -euo pipefail

(( $+commands[tmux] )) || {
  print -u2 'aistack ai shell: tmux is required'
  exit 1
}

autocomplete_script="${0:A:h}/aistack-ai-autocomplete.zsh"
session_name="${AISTACK_AI_TMUX_SESSION:-aistack-ai}"

if tmux has-session -t "$session_name" 2>/dev/null; then
  exec tmux attach-session -t "$session_name"
fi

tmux new-session -d -s "$session_name" zsh
tmux send-keys -t "$session_name" "source ${(q)autocomplete_script}" Enter
exec tmux attach-session -t "$session_name"