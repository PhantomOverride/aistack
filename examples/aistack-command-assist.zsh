# Source from .zshrc after loading ZLE: source /path/to/aistack-command-assist.zsh

_aistack_command_assist_tab() {
  emulate -L zsh

  if [[ "$BUFFER" != *'#'* ]]; then
    local tab_widget
    case "$KEYMAP" in
      viins) tab_widget=_aistack_command_assist_viins_tab ;;
      *) tab_widget=_aistack_command_assist_emacs_tab ;;
    esac
    zle "$tab_widget"
    return
  fi

  if (( ! $+commands[curl] || ! $+commands[jq] )); then
    zle -M 'aistack command assist requires curl and jq'
    return 1
  fi

  local api_base="${AISTACK_API_BASE:-http://127.0.0.1:1337/v1}"
  local model="${AISTACK_MODEL:-default}"
  local api_key="${AISTACK_API_KEY:-not-needed-for-loopback}"
  local timeout="${AISTACK_AI_TIMEOUT:-60}"
  local request response command error_message
  local curl_status
  local -a curl_args

  request="$(jq -n \
    --arg model "$model" \
    --arg line "$BUFFER" \
    '{model: $model, messages: [
      {role: "system", content: "Convert shell command annotations into one executable Zsh command. The user places their intent after #. Return only the command, with no Markdown, explanation, comments, or surrounding quotes. Preserve relevant arguments before # when appropriate."},
      {role: "user", content: $line}
    ], stream: false}')" || {
      zle -M 'aistack command assist could not build the request'
      return 1
    }

  curl_args=(--fail --silent --show-error --max-time "$timeout"
    -H 'content-type: application/json'
    -H "authorization: Bearer $api_key"
    -d "$request"
    "$api_base/chat/completions")
  zle -M 'aistack: generating command...'
  zle -R
  response="$(curl "${curl_args[@]}" 2>&1)"
  curl_status=$?
  if (( curl_status != 0 )); then
    error_message="${response//$'\n'/ }"
    zle -M "aistack: ${error_message:-request failed}"
    return 1
  fi

  command="$(jq -er '.choices[0].message.content | select(type == "string" and length > 0)' <<<"$response")" || {
    zle -M 'aistack: response contained no command'
    return 1
  }

  BUFFER="$command"
  CURSOR=${#BUFFER}
  zle -M ''
  zle -R
}

_aistack_command_assist_save_tab_widget() {
  emulate -L zsh
  local keymap="$1" saved_widget="$2" current_widget

  (( $+widgets[$saved_widget] )) && return
  current_widget="${${(z)$(bindkey -M "$keymap" '^I')}[2]}"
  if [[ -z "$current_widget" || "$current_widget" == _aistack_command_assist_tab ]]; then
    current_widget=.expand-or-complete
  fi
  zle -A "$current_widget" "$saved_widget"
}

zle -N _aistack_command_assist_tab
_aistack_command_assist_save_tab_widget emacs _aistack_command_assist_emacs_tab
_aistack_command_assist_save_tab_widget viins _aistack_command_assist_viins_tab
bindkey -M emacs '^I' _aistack_command_assist_tab
bindkey -M viins '^I' _aistack_command_assist_tab