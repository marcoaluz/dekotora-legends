#!/usr/bin/env bash
# Teste de ponta a ponta do multiplayer: 1 servidor + 2 clientes automaticos no mesmo PC.
# Uso: bash tools/net_test.sh [latencia_ms] [perda]    (padrao: 0 e 0)
# BODY=graneleira bash tools/net_test.sh  -> o cliente Beto corre com essa carroceria
# T-173: Beto corre com HORN (padrao horn_ship_deep) e EXH (padrao exh_stack); Ana precisa receber os dois no descritor.
source "$(dirname "$0")/env.sh"
LAT=${1:-0}; LOSS=${2:-0}
HORN=${HORN:-horn_ship_deep}; EXH=${EXH:-exh_stack}
PORT=$((24600 + RANDOM % 300))
LOGDIR=${TMPDIR:-/tmp}/kb_nettest; mkdir -p "$LOGDIR"; rm -f "$LOGDIR"/*.log
cd "$(dirname "$0")/.."
"$GODOT" --headless --path game -- --server --port=$PORT > "$LOGDIR/server.log" 2>&1 &
SERVER=$!
sleep 4
"$GODOT" --headless --path game -- --bot-client --port=$PORT --name=Ana --code=ANA22222 --create --players=2 --bots=1 --latency=$LAT --loss=$LOSS > "$LOGDIR/ana.log" 2>&1 &
ANA=$!
CODE=""
for i in $(seq 1 40); do
  CODE=$(grep -o "entrou na sala [A-Z0-9]*" "$LOGDIR/ana.log" | head -1 | awk '{print $4}')
  [ -n "$CODE" ] && break
  sleep 0.5
done
echo "sala criada: $CODE"
"$GODOT" --headless --path game -- --bot-client --port=$PORT --name=Beto --code=BETO3333 --join=$CODE --latency=$LAT --loss=$LOSS ${BODY:+--body=$BODY} --horn=$HORN --exhaust=$EXH > "$LOGDIR/beto.log" 2>&1 &
BETO=$!
wait $ANA; RA=$?
wait $BETO; RB=$?
kill $SERVER 2>/dev/null
echo "--- servidor"; grep -E "^\[servidor\]" "$LOGDIR/server.log" | head -20
echo "--- Ana (saida $RA)"; grep -E "RESULTADO|PRED:|LARGADA|abertura|erro_pred|erro do servidor|desconectado" "$LOGDIR/ana.log" | tail -9
echo "--- Beto (saida $RB)"; grep -E "RESULTADO|PRED:|LARGADA|abertura|erro_pred|erro do servidor|desconectado" "$LOGDIR/beto.log" | tail -9
echo "--- carro acidentado (T-183: estado no snapshot, protocolo 8)"; grep -h "ACIDENTADOS:" "$LOGDIR/ana.log" "$LOGDIR/beto.log"
echo "--- largada (T-156: abertura e relogio comum)"; grep -hE "abertura|LARGADA" "$LOGDIR/ana.log" "$LOGDIR/beto.log"
echo "--- som (T-173: buzina e escapamento no descritor)"; grep -h "SOM:" "$LOGDIR/ana.log"
SOM_OK=0
if grep -q "SOM:.*bot=false buzina=$HORN escape=$EXH" "$LOGDIR/ana.log"; then echo "SOM_REDE: OK (Ana ouve a buzina $HORN e o escape $EXH do Beto)"; else echo "SOM_REDE: FALHOU"; SOM_OK=1; fi
if [ $SOM_OK -eq 0 ] && grep -q BOTCLIENT_DONE "$LOGDIR/ana.log" && grep -q BOTCLIENT_DONE "$LOGDIR/beto.log"; then echo "NET_TEST: PASSOU"; exit 0; else echo "NET_TEST: FALHOU (logs em $LOGDIR)"; exit 1; fi
