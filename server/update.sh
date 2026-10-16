#!/usr/bin/env bash
# Atualiza o servidor com um binario novo (rode no VPS). Uso: sudo bash update.sh dekotora_server.x86_64
set -euo pipefail
BIN="${1:?informe o binario novo}"
systemctl stop kaido-server
install -m 0755 "$BIN" /opt/kaido/dekotora_server.x86_64
chown kaido:kaido /opt/kaido/dekotora_server.x86_64
systemctl start kaido-server
sleep 2
systemctl --no-pager status kaido-server | head -n 6
