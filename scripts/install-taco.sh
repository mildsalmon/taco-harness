#!/usr/bin/env bash
# install-taco.sh — Install taco CLI to PATH
# Usage: ./scripts/install-taco.sh [install-dir]
#   install-dir defaults to ~/.local/bin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TACO_SOURCE="$SCRIPT_DIR/taco"
INSTALL_DIR="${1:-$HOME/.local/bin}"

# Validate source exists
if [[ ! -f "$TACO_SOURCE" ]]; then
  echo "[ERROR] taco script not found: $TACO_SOURCE" >&2
  exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Remove existing
LINK_PATH="$INSTALL_DIR/taco"
if [[ -e "$LINK_PATH" ]]; then
  echo "[INFO] Removing existing: $LINK_PATH" >&2
  rm -f "$LINK_PATH"
fi

# Create symlink
ln -s "$TACO_SOURCE" "$LINK_PATH"
echo "[INFO] Installed: $LINK_PATH -> $TACO_SOURCE" >&2

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qF "$INSTALL_DIR"; then
  echo "" >&2
  echo "[WARN] $INSTALL_DIR is not in your PATH." >&2
  echo "       Add this to your ~/.zshrc or ~/.bashrc:" >&2
  echo "" >&2
  echo "       export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
  echo "" >&2
else
  echo "[INFO] Done! Try: taco help" >&2
fi
