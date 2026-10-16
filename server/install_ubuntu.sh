#!/usr/bin/env bash
# Instala o servidor do Kaido Bakuso num VPS Ubuntu 22.04/24.04 (rode como root ou com sudo).
# Antes: copie dekotora_server.x86_64 para o VPS (veja server/README.md). Uso: sudo bash install_ubuntu.sh [caminho_do_binario]
set -euo pipefail
BIN="${1:-./dekotora_server.x86_64}"
[ -f "$BIN" ] || { echo "Binario nao encontrado: $BIN"; exit 1; }
id kaido >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin kaido
mkdir -p /opt/kaido
install -m 0755 "$BIN" /opt/kaido/dekotora_server.x86_64
chown -R kaido:kaido /opt/kaido
install -m 0644 "$(dirname "$0")/kaido-server.service" /etc/systemd/system/kaido-server.service
systemctl daemon-reload
systemctl enable --now kaido-server
# firewall (ufw): SSH + porta UDP do jogo
if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH >/dev/null || true
  ufw allow 24600/udp >/dev/null || true
  ufw --force enable >/dev/null || true
fi
systemctl --no-pager status kaido-server | head -n 8
echo "Pronto. Logs: journalctl -u kaido-server -f"
