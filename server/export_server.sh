#!/usr/bin/env bash
# Exporta o preset "Server" (Linux x86_64, headless) para builds/dekotora_server.x86_64.
source "$(dirname "$0")/../tools/env.sh"
cd "$(dirname "$0")/.."
mkdir -p builds
"$GODOT" --headless --path game --export-release "Server" ../builds/dekotora_server.x86_64
ls -la builds/dekotora_server.x86_64
