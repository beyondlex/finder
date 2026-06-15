#!/bin/bash
set -euo pipefail

APPNAME="nvim-finder-test"
CONFIG_DIR="$HOME/.config/$APPNAME"
DATA_DIR="$HOME/.local/share/$APPNAME"
CACHE_DIR="$HOME/.cache/$APPNAME"

CLEAN=0
ARGS=()

usage() {
  echo "Usage: $0 [options] [-- <nvim args>]"
  echo ""
  echo "Options:"
  echo "  --clean     Delete all test data (config/data/cache) before launch"
  echo "  -h|--help   Show this help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) CLEAN=1; shift ;;
    --) shift; ARGS+=("$@"); break ;;
    -h|--help) usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$CLEAN" = 1 ]; then
  echo "==> Cleaning $APPNAME data..."
  rm -rf "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
fi

mkdir -p "$CONFIG_DIR"

{
  echo "vim.g.finder_root = '$PROJECT_DIR'"
  echo ""
  cat "$PROJECT_DIR/test/init.lua"
} > "$CONFIG_DIR/init.lua"

echo "==> Launching $APPNAME..."
echo "    Config: $CONFIG_DIR"
echo "    Data:   $DATA_DIR"
echo "    Plugins: edit test/init.lua to add plugins"
echo ""

exec env NVIM_APPNAME="$APPNAME" nvim "${ARGS[@]+"${ARGS[@]}"}"
