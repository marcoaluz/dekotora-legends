# Log de coordenação

Cada agente acrescenta uma entrada **no fim** ao terminar uma tarefa. Nunca apague entradas antigas.
Formato em `docs/AGENTES.md`.

## 2026-10-15 22:55 · T-000 · coordenador · CONCLUÍDA
- Feito: time de agentes criado (ajudante-rapido/Haiku, especialista/Opus, supervisor/Sonnet), quadro e log.
- Arquivos: .claude/agents/*, .claude/coordenacao/*, .claude/commands/*, docs/AGENTES.md, CLAUDE.md
- Observação: nada

## 2026-10-15 · T-001 · coordenador · CONCLUÍDA
- Feito: leitura de README, CLAUDE.md, AGENTES.md, PROMPTS.md e docs/. Ambiente conferido: git 2.55 + LFS 3.7.1, Blender 5.2.2 LTS (bpy + numpy 2.3.4 OK), Godot 4.7.2 (headless abre game/ e sai, exit 0).
- Arquivos: .claude/coordenacao/QUADRO.md, LOG.md, docs/ROADMAP.md
- Validação: blender -b --python-expr; godot --headless --path game --quit
- Observação / Decisão pendente: godot e blender NÃO estão no PATH (estão em D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe e D:\Blender\blender.exe). Pasta não é repositório git ainda. Export templates 4.7.2 baixados em D:\DEV\Godot\dl (.tpz), instalação no editor pendente. Android SDK/JDK não verificados.

## 2026-10-16 · T-002..T-081 · coordenador · CONCLUÍDA (execução contínua autorizada pelo Marco)
- Feito: prompts P01–P81 executados em sequência pelo próprio coordenador (sem subagentes: o contexto compartilhado compensou o custo de
  repassar; o Marco autorizou seguir até o fim). Ver `docs/STATUS.md` e `docs/ROADMAP.md`.
- Validação: 84 testes automáticos, teste de rede ponta a ponta (`tools/net_test.sh`), builds Windows e servidor Linux exportadas, capturas de tela inspecionadas.
- Observação / Decisão pendente: Android não testado (falta SDK), visual/plano B e áudio precisam de aprovação do Marco; nome do jogo provisório.

## 2026-10-17 · T-089…T-096 · coordenador · CONCLUÍDA (T-090 precisa Marco; T-097 precisa Marco)
- Feito: plano visual V0–V7 (docs/PLANO_VISUAL.md): patch das rodas e protótipo noturno; hora do dia por rota (night/dusk/day) com céu por shader; 3 propostas de direção de arte (docs/DIRECAO_ARTE.md); via expressa japonesa (sem zebra, faixa amarela, marcações, delineadores, pórticos com kanji, viaduto, túneis); texturas CC0 (Poly Haven) e desgaste; efeitos de velocidade/luz com chaves nas Opções; cromo por matcap; decoração Dekotora no caminhão (luzes, andons, mural trocável).
- Arquivos: game/scripts/road3d/{world_env,road_mesh,road_furniture,tunnel_3d,roadside_3d,city_builder,speed_fx,light_streaks,race_scene_3d}.gd, game/scripts/data/time_of_day.gd, game/data/time/, game/scripts/truck/{truck_node,chrome_matcap}.gd, blender/scripts/{build_matcaps.py,truck3d/deco.py,lib/tex.py}, docs/DIRECAO_ARTE.md
- Observação: V8 (celular) bloqueado sem APK. Custo modo médio ~345 chamadas (antes ~330). 92 testes passam.

## 2026-10-17 · T-098 · coordenador · CONCLUÍDA (análise retomada de outra sessão)
- Feito: análise das 4 partes do gameplay de Art Truck Battle (PS1). Partes 1–2 já estavam em notas; refeitas e conferidas as Partes 3 e 4 com imagem (folhas de contato 4-em-1, 2-em-1). Documento com controle, dano, câmera, HUD, estrutura da corrida, loja, cenário e tabela de 30 ideias com esforço/prioridade/decisão.
- Arquivos: docs/REFERENCIA_ART_TRUCK_BATTLE.md, docs/referencia_atb/*.png (14 prints). Vídeos e notas ficam em referencias/atb/ (fora do Git).
- Observação / Decisão pendente: leituras de imagem falharam várias vezes na sessão anterior ("request limit"); só entrou o que foi visto. Itens marcados [incerto] no doc. "Sem primeira pessoa" ainda não está em DECISOES. Tabela tem itens que pedem decisão do Marco (prazo de entrega, regra de derrota, rivais que recusam, nota de destaque).

## 2026-10-17 · T-105 · coordenador · PASSO 1 CONCLUÍDO (aguarda Marco)
- Feito: pesquisa Blender Lab MCP (oficial, v1.0.3, Blender 5.1+, página não cita Claude Code nem lista ferramentas/captura de tela) x "MCP for Blender" (comunidade, MIT, `look`/`execute_blender_code`, comando para Claude Code). Marco aprovou a comunitária. Instalado: uv 0.13.1 (~/.local/bin, sem mexer no PATH), add-on em %APPDATA%\Blender Foundation\Blender\5.2\scripts\addons\blender_mcp.py, MCP `blender` registrado em escopo local (DISABLE_TELEMETRY=true), `claude mcp list` mostra Connected.
- Falta (Marco): abrir o Blender, ativar "Interface: MCP for Blender", N → aba → Start MCP Server; reiniciar o Claude Code para as ferramentas aparecerem nesta sessão. Só então passos 2-4 (modelagem da frente, renders, relatório).
- Observação: nada do jogo foi alterado. Referência para o clima: docs/dekotora_volvo_3d_references/01_dekotora_front_bumper.png.

## 2026-10-17 · T-105 · coordenador · CONCLUÍDA
- Feito: MCP conectado (Blender 5.2.2, add-on 1.8). Modelei a frente de um Dekotora noturno por código e renderizei em Cycles (3 rodadas de ajuste, 95–135 s cada na CPU). Relatório em docs/TESTE_MCP_BLENDER.md; render em docs/direcao_arte/mcp_blender_frente_cycles.png; .blend em blender/renders/mcp_teste/ (fora do Git).
- Observação: nada do jogo foi alterado. Subagentes não enxergam as ferramentas do MCP, por isso não deleguei ao especialista. Modelo ainda é de caixas; o ganho do MCP é de luz/reflexo, não de forma.

## 2026-10-17 · T-099…T-104 · coordenador · CONCLUÍDAS (lote ATB-1)
- Feito: decisões em DECISOES/GDD (T-099); controle por faixas na simulação, bots, rede, entrada, HUD e setas no caminhão (T-100); prazo de entrega e regra de vitória/derrota (T-101); perda de carga 0–40% e tipos de carga (T-102); rival de verdade (T-103); pausa Continuar/Revanche/Desistir sem escurecer e barra de progresso com rival (T-104). 122 testes passando, `tools/net_test.sh` (com e sem perda) passou. Capturas em docs/capturas_atb1/.
- Não usei subagentes: as tarefas mexem no mesmo conjunto de arquivos da simulação e da rede, e reexplicar o contexto custaria mais que fazer.
- Dúvidas registradas: derrota paga 0 ¥ e 0 Fama (risco de ficar sem dinheiro); prazo das rotas 2 e 3 fixado a mão (130 s e 150 s) porque bots difíceis levam 112 s e 129 s.
- Achado fora do escopo: erro de malha no túnel da rota Hakone (`tunnel_3d.gd:151`, `set_normal`) já existia antes do lote.
- Lote ATB-2 NÃO iniciado (o pedido diz para esperar o lote 1 estar bom no teste do Marco).
