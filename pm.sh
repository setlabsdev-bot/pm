#!/usr/bin/env bash
set -euo pipefail

#############################################
#  pm — Single‑File Bash Plugin Manager
#  Author: setya + Copilot
#############################################

PM_HOME="${PM_HOME:-$HOME/.local/share/pm}"
PM_PLUGIN_DIR="$PM_HOME/plugins"
PM_STATE_DIR="$PM_HOME/state"
PM_TEMPLATE_DIR="$PM_HOME/templates"

mkdir -p "$PM_PLUGIN_DIR" "$PM_STATE_DIR" "$PM_TEMPLATE_DIR"

#############################################
# Logging
#############################################
pm_log() { printf "[pm] %s\n" "$*" >&2; }

#############################################
# Template Extraction (only once)
#############################################
pm_extract_templates() {
  [[ -d "$PM_TEMPLATE_DIR/plugin-basic" ]] && return 0

  pm_log "Extracting built‑in templates…"

  mkdir -p "$PM_TEMPLATE_DIR/plugin-basic"
  mkdir -p "$PM_TEMPLATE_DIR/plugin-advanced"
  mkdir -p "$PM_TEMPLATE_DIR/plugin-service"
  mkdir -p "$PM_TEMPLATE_DIR/plugin-hook"

  # BASIC
  cat > "$PM_TEMPLATE_DIR/plugin-basic/plugin.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

plugin_main() {
  echo "[__PLUGIN_NAME__] Basic plugin running"
  echo "Args: $*"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  plugin_main "$@"
fi
EOF

  cat > "$PM_TEMPLATE_DIR/plugin-basic/metadata" <<'EOF'
name=__PLUGIN_NAME__
version=0.1.0
description=Basic plugin
entry=plugin.sh
enabled=false
EOF

  # ADVANCED
  mkdir -p "$PM_TEMPLATE_DIR/plugin-advanced"
  cat > "$PM_TEMPLATE_DIR/plugin-advanced/plugin.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="__PLUGIN_NAME__"

log() { printf "[%s] %s\n" "$PLUGIN_NAME" "$*" >&2; }

plugin_init() { log "init"; }
plugin_main() { log "run"; log "Args: $*"; }
plugin_cleanup() { log "cleanup"; }

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  plugin_init
  plugin_main "$@"
  plugin_cleanup
fi
EOF

  cat > "$PM_TEMPLATE_DIR/plugin-advanced/metadata" <<'EOF'
name=__PLUGIN_NAME__
version=0.1.0
description=Advanced plugin with hooks
entry=plugin.sh
enabled=false
EOF

  # SERVICE
  mkdir -p "$PM_TEMPLATE_DIR/plugin-service"
  cat > "$PM_TEMPLATE_DIR/plugin-service/plugin.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

while true; do
  echo "[__PLUGIN_NAME__] Tick at $(date)"
  sleep 5
done
EOF

  cat > "$PM_TEMPLATE_DIR/plugin-service/metadata" <<'EOF'
name=__PLUGIN_NAME__
version=0.1.0
description=Service plugin (daemon-like)
entry=plugin.sh
enabled=false
EOF

  # HOOK
  mkdir -p "$PM_TEMPLATE_DIR/plugin-hook"
  cat > "$PM_TEMPLATE_DIR/plugin-hook/plugin.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

hook_pre()  { echo "[__PLUGIN_NAME__] pre-hook"; }
hook_run()  { echo "[__PLUGIN_NAME__] run-hook"; }
hook_post() { echo "[__PLUGIN_NAME__] post-hook"; }

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  hook_pre
  hook_run "$@"
  hook_post
fi
EOF

  cat > "$PM_TEMPLATE_DIR/plugin-hook/metadata" <<'EOF'
name=__PLUGIN_NAME__
version=0.1.0
description=Hook-based plugin
entry=plugin.sh
enabled=false
EOF
}

pm_extract_templates

#############################################
# Plugin Helpers
#############################################
pm_list_plugins() {
  echo "Available plugins:"
  for p in "$PM_PLUGIN_DIR"/*; do
    [[ -d "$p" ]] || continue
    echo " - $(basename "$p")"
  done
}

pm_list_enabled() {
  echo "Enabled plugins:"
  for p in "$PM_PLUGIN_DIR"/*; do
    [[ -f "$p/metadata" ]] || continue
    if grep -q "^enabled=true" "$p/metadata"; then
      echo " - $(basename "$p")"
    fi
  done
}

pm_enable_plugin() {
  local name="$1"
  local meta="$PM_PLUGIN_DIR/$name/metadata"
  [[ -f "$meta" ]] || { echo "No such plugin: $name"; return 1; }
  sed -i 's/^enabled=.*/enabled=true/' "$meta"
  pm_log "Enabled $name"
}

pm_disable_plugin() {
  local name="$1"
  local meta="$PM_PLUGIN_DIR/$name/metadata"
  [[ -f "$meta" ]] || { echo "No such plugin: $name"; return 1; }
  sed -i 's/^enabled=.*/enabled=false/' "$meta"
  pm_log "Disabled $name"
}

pm_show_plugin_info() {
  local name="$1"
  local meta="$PM_PLUGIN_DIR/$name/metadata"
  [[ -f "$meta" ]] || { echo "No such plugin: $name"; return 1; }
  cat "$meta"
}

pm_run_plugin() {
  local name="$1"; shift || true
  local dir="$PM_PLUGIN_DIR/$name"
  local meta="$dir/metadata"

  [[ -f "$meta" ]] || { echo "No such plugin: $name"; return 1; }

  local entry
  entry=$(grep '^entry=' "$meta" | cut -d= -f2)

  [[ -f "$dir/$entry" ]] || { echo "Missing entry script"; return 1; }

  "$dir/$entry" "$@"
}

#############################################
# Plugin Validation
#############################################
pm_validate_plugin() {
  local name="$1"
  local dir="$PM_PLUGIN_DIR/$name"

  [[ -d "$dir" ]] || { echo "No such plugin: $name"; return 1; }

  local ok=true

  [[ -f "$dir/metadata" ]] || { echo "Missing metadata"; ok=false; }
  [[ -f "$dir/plugin.sh" ]] || { echo "Missing plugin.sh"; ok=false; }

  if grep -R "__PLUGIN_NAME__" "$dir"; then
    echo "Template placeholders still present"
    ok=false
  fi

  $ok && echo "Plugin '$name' is valid."
}

#############################################
# Plugin Generator
#############################################
pm_new_plugin() {
  local name="$1"
  local template="${2:-plugin-basic}"

  local src="$PM_TEMPLATE_DIR/$template"
  local dst="$PM_PLUGIN_DIR/$name"

  [[ -d "$src" ]] || { echo "Unknown template: $template"; return 1; }
  [[ -e "$dst" ]] && { echo "Plugin exists: $name"; return 1; }

  cp -R "$src" "$dst"

  find "$dst" -type f -print0 | while IFS= read -r -d '' f; do
    sed -i "s/__PLUGIN_NAME__/$name/g" "$f"
  done

  chmod +x "$dst"/*.sh 2>/dev/null || true

  pm_log "Created plugin '$name' from template '$template'"
}

#############################################
# Interactive Prompt
#############################################
pm_prompt() {
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
 q) Quit

EOF
    read -rp "Select option: " choice

    case "$choice" in
      1) pm_list_plugins; read -rp "Press enter…" ;;
      2) pm_list_enabled; read -rp "Press enter…" ;;
      3) read -rp "Plugin: " n; pm_enable_plugin "$n"; read -rp "Press enter…" ;;
      4) read -rp "Plugin: " n; pm_disable_plugin "$n"; read -rp "Press enter…" ;;
      5) read -rp "Plugin: " n; read -rp "Args: " a; pm_run_plugin $n $a; read -rp "Press enter…" ;;
      6) read -rp "Plugin: " n; pm_show_plugin_info "$n"; read -rp "Press enter…" ;;
      7) read -rp "Name: " n; read -rp "Template (plugin-basic/plugin-advanced/plugin-service/plugin-hook): " t; pm_new_plugin "$n" "$t"; read -rp "Press enter…" ;;
      8) read -rp "Plugin: " n; pm_validate_plugin "$n"; read -rp "Press enter…" ;;
      q|Q) break ;;
      *) echo "Invalid"; sleep 1 ;;
    esac
  done
}

#############################################
# CLI
#############################################
cmd="${1:-}"; shift || true

case "$cmd" in
  list) pm_list_plugins ;;
  enabled) pm_list_enabled ;;
  enable) pm_enable_plugin "$@" ;;
  disable) pm_disable_plugin "$@" ;;
  run) pm_run_plugin "$@" ;;
  info) pm_show_plugin_info "$@" ;;
  new-plugin) pm_new_plugin "$@" ;;
  validate) pm_validate_plugin "$@" ;;
  prompt) pm_prompt ;;
  *)
    cat <<EOF
Usage: pm <command>

Commands:
  list
  enabled
  enable <name>
  disable <name>
  run <name> [args]
  info <name>
  new-plugin <name> [template]
  validate <name>
  prompt
EOF
    ;;
esac
