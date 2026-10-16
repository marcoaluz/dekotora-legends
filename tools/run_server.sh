#!/usr/bin/env bash
# Abre o servidor multiplayer (modo desenvolvimento). Uso: bash tools/run_server.sh [porta]
source "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --path game -- --server --port="${1:-24600}"
