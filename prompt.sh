#!/usr/bin/env bash
#
# prompt.sh — Interactive UI for the Bash Plugin Manager (pm)
#

set -euo pipefail

PM_HOME="${PM_HOME:-$HOME/.local/share/pm}"
PM_PLUGIN_DIR="$PM_HOME/plugins"
PM_TEMPLATE_DIR="$PM_HOME/templates"
PM_STATE_DIR="$PM_HOME/state"

pm() {
  command pm "$@"
}

pause() {
  printf "\nPress enter to continue..."
  read -r _
}

while true; do
  clear
  cat <<EOF
========================================
        Bash Plugin Manager (pm)
========================================

 1) List plugins
 2) List enabled plugins
 3) Enable plugin
 4) Disable plugin
 5) Run plugin
 6) Show plugin info
 7) Create new plugin
 8) Validate plugin
 9) Edit plugin
 q) Quit

EOF

  read -rp "Select option: " choice

  case "$choice" in
    1)
      pm list
      pause
      ;;
    2)
      pm enabled
      pause
      ;;
    3)
      read -rp "Plugin to enable: " name
      pm enable "$name"
      pause
      ;;
    4)
      read -rp "Plugin to disable: " name
      pm disable "$name"
      pause
      ;;
    5)
      read -rp "Plugin to run: " name
      read -rp "Args: " args
      # shellcheck disable=SC2086
      pm run "$name" $args
      pause
      ;;
    6)
      read -rp "Plugin: " name
      pm info "$name"
      pause
      ;;
    7)
      read -rp "New plugin name: " name
      read -rp "Template (plugin-basic/plugin-advanced/plugin-service/plugin-hook): " tpl
      tpl="${tpl:-plugin-basic}"
      pm new-plugin "$name" "$tpl"
      pause
      ;;
    8)
      read -rp "Plugin to validate: " name
      pm validate "$name"
      pause
      ;;
    9)
      read -rp "Plugin to edit: " name
      ${EDITOR:-nano} "$PM_PLUGIN_DIR/$name"
      ;;
    q|Q)
      echo "Goodbye."
      exit 0
      ;;
    *)
      echo "Invalid choice."
      sleep 1
      ;;
  esac
done
