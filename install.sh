#!/usr/bin/env bash
# fork-pilot installer
set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Installing to $INSTALL_DIR (requires sudo)..."
    sudo cp "$SCRIPT_DIR/fork-pilot" "$INSTALL_DIR/fork-pilot"
    sudo chmod +x "$INSTALL_DIR/fork-pilot"
else
    cp "$SCRIPT_DIR/fork-pilot" "$INSTALL_DIR/fork-pilot"
    chmod +x "$INSTALL_DIR/fork-pilot"
fi

echo "fork-pilot installed to $INSTALL_DIR/fork-pilot"
echo "Run 'fork-pilot --help' to get started."
