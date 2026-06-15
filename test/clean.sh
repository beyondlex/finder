#!/bin/bash
set -euo pipefail

APPNAME="nvim-finder-test"

CONFIG_DIR="$HOME/.config/$APPNAME"
DATA_DIR="$HOME/.local/share/$APPNAME"
CACHE_DIR="$HOME/.cache/$APPNAME"

echo "==> Cleaning $APPNAME..."
echo "    rm -rf $CONFIG_DIR"
echo "    rm -rf $DATA_DIR"
echo "    rm -rf $CACHE_DIR"

rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"

echo "==> Done. System Neovim untouched."
