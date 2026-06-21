#!/usr/bin/env bash
#
# install.sh — Installer for the single‑file Bash Plugin Manager (pm)
#
# Usage:
#   ./install.sh install
#   ./install.sh uninstall
#   PREFIX=$HOME/.local ./install.sh install
#

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"
SHAREDIR="$PREFIX/share/pm"
PLUGINDIR="$SHAREDIR/plugins"
TEMPLATEDIR="$SHAREDIR/templates"
STATEDIR="$SHAREDIR/state"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { printf "[install] %s\n" "$*"; }
err() { printf "[error] %s\n" "$*" >&2; exit 1; }

install_pm() {
  log "Installing pm into $PREFIX"

  mkdir -p "$BINDIR" "$PLUGINDIR" "$TEMPLATEDIR" "$STATEDIR"

  # Install the pm executable
  install -m 755 "$ROOT_DIR/pm" "$BINDIR/pm"

  # Copy templates if not already present
  if [ ! -d "$TEMPLATEDIR/plugin-basic" ]; then
    log "Copying built‑in templates"
    cp -R "$ROOT_DIR/templates/"* "$TEMPLATEDIR/" 2>/dev/null || true
  else
    log "Templates already exist — not overwriting"
  fi

  # Create plugin + state dirs if missing
  touch "$STATEDIR/.installed"

  log "Installation complete"
  log "Binary: $BINDIR/pm"
  log "Plugins: $PLUGINDIR"
  log "Templates: $TEMPLATEDIR"
  log "State: $STATEDIR"
}

uninstall_pm() {
  log "Uninstalling pm from $PREFIX"

  rm -f "$BINDIR/pm"
  rm -rf "$SHAREDIR"

  log "Uninstall complete"
}

case "${1:-}" in
  install) install_pm ;;
  uninstall) uninstall_pm ;;
  *)
    err "Usage: $0 {install|uninstall}"
    ;;
esac
