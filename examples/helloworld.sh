#!/usr/bin/env bash
# Simple Hello World in bash that connects to the local interface via curl.
set -euo pipefail

readonly API_BASE="${AISTACK_API_BASE:-http://127.0.0.1:1337/v1}"
readonly MODEL="${AISTACK_MODEL:-default}"

command -v curl >/dev/null || { printf 'curl is required\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }

curl --fail-with-body --silent --show-error \
  "$API_BASE/chat/completions" \
  -H 'content-type: application/json' \
  -d "$(jq -nc --arg model "$MODEL" '{model: $model, stream: false, messages: [{role: "user", content: "Say hello world."}]}')" \
  | jq -er '.choices[0].message.content'