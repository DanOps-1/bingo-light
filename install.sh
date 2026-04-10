#!/usr/bin/env bash
# bingo-light installer
set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Installing to $INSTALL_DIR (requires sudo)..."
    sudo cp "$SCRIPT_DIR/bingo-light" "$INSTALL_DIR/bingo-light"
    sudo chmod +x "$INSTALL_DIR/bingo-light"
else
    cp "$SCRIPT_DIR/bingo-light" "$INSTALL_DIR/bingo-light"
    chmod +x "$INSTALL_DIR/bingo-light"
fi

echo "bingo-light installed to $INSTALL_DIR/bingo-light"
echo "Run 'bingo-light --help' to get started."
