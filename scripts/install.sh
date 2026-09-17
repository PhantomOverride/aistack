#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/aistack"
readonly INSTALL_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
readonly USER_CONFIG="$CONFIG_HOME/config.env"
readonly BIN_LINK="$INSTALL_DIR/aistack"

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty || reply=""
  [[ "${reply,,}" == y || "${reply,,}" == yes ]]
}

write_config() {
  install -m 600 "$PROJECT_DIR/config/config.env.example" "$USER_CONFIG"
  printf '%s %s; set endpoint URLs, models, and credentials before using lab or cloud.\n' "$1" "$USER_CONFIG"
}

install_aistack() {
  mkdir -p "$CONFIG_HOME" "$INSTALL_DIR"
  if [[ -f "$USER_CONFIG" ]]; then
    if confirm "$USER_CONFIG already exists; overwrite with defaults?"; then
      write_config 'Overwrote'
    else
      printf 'Kept existing %s\n' "$USER_CONFIG"
    fi
  else
    write_config 'Created'
  fi
  ln -sfn "$PROJECT_DIR/bin/aistack" "$BIN_LINK"
  printf 'Installed %s\n' "$BIN_LINK"
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) printf 'Run: aistack local\n' ;;
    *) printf 'Add %s to PATH, then run: aistack local\n' "$INSTALL_DIR" ;;
  esac
}

uninstall_aistack() {
  if [[ -L "$BIN_LINK" ]]; then
    rm -f "$BIN_LINK"
    printf 'Removed %s\n' "$BIN_LINK"
  fi
  if [[ -d "$CONFIG_HOME" ]]; then
    rm -rf "$CONFIG_HOME"
    printf 'Removed %s\n' "$CONFIG_HOME"
  fi
  printf 'Uninstalled. Containers and volumes are untouched; run "aistack reset all" first to remove those.\n'
}

main() {
  case "${1:-install}" in
    install) install_aistack ;;
    uninstall) uninstall_aistack ;;
    *) printf 'Usage: install.sh [install|uninstall]\n' >&2; exit 2 ;;
  esac
}

main "$@"
