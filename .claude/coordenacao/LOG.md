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

## 2026-10-17 · T-107…T-112 · coordenador · CONCLUÍDAS (lote ATB-2)
- Feito: nota de destaque (T-107), abas Decoração/Mecânica e prévia dia/noite (T-108), luzes com padrões de pisca por shader, custo zero medido (T-109), adesivos em PNG com 6 provisórios e pasta game/assets/decals (T-110), rivais que recusam por Fama e destaque (T-111), largada/chegada com corte lateral, banners e clarão do túnel (T-112). 141 testes passando e net_test OK. Capturas em docs/capturas_atb2/.
- Não usei subagentes (mesmos arquivos, contexto longo). Corrigido risco: o `--demo` da garagem regravava user://profile.json; agora usa user://demo_profile.json. O profile.json real pode ter sido sobrescrito por um `--demo` anterior (era um perfil de demonstração, com a garagem cheia).
- Dúvidas para o Marco: valores de destaque/Fama dos rivais, preço/Fama das cores de pintura, multiplayer sem adesivos/luzes dos outros.

## 2026-10-17 21:05 · T-106 · especialista · CONCLUÍDA
- Feito: cabine realista nas 4 cabines (casca com recorte do arco da roda e frente curva; vidros/faróis/grade/frisos que seguem a curva; porta com vinco, janela, maçaneta, fechadura, pega-mão; espelhos com haste + espelho de canto; para-brisa envolvente com limpadores e caixa de ar; para-choque varrido; degraus; para-lama, forro e protetor de lama; defletor por loft) e texturas por código (pintura suja por altura + normal, plástico com poeira, para-brisa com arcos do limpador, colmeia, fendas, chapa xadrez, pneu). Decoração V7 reaplicada (sobrancelha de luzes agora segue a casca).
- Arquivos: blender/scripts/truck3d/{cab,cab_surface,cab_front,cab_doors,cab_roof,deco,wheels}.py, blender/scripts/lib/{tex_truck,pbr,mesh3d,mesh_adv,preview}.py, build_truck_3d.py, tools/glb_stats.py, 13 .glb + texturas extraídas, garage_screen/garage_stage (--noparts, --cab, --zoom; já entraram no commit do T-112), docs STATUS/DECISOES/ROADMAP, docs/direcao_arte/cabine_realista_*.png
- Validação: 13 .glb gerados (75 s); triângulos base 61.748 → 64.297 (leve 51,9 mil, longo 76,8 mil); textura por .glb 0,06 → 1,2–1,5 MB; Godot --import OK; 141 testes, 0 falhas; corrida, garagem e accessory_viewer abrem sem erro (só o aviso antigo "resources still in use at exit"); capturas na garagem (com e sem as 16 peças da demo: encaixam) e na corrida.
- Decisão pendente: texturas repetidas em cada .glb (opção: uma cópia compartilhada aplicada pelo TruckNode); apagar os PNGs extraídos antigos que não são mais usados.

## 2026-10-17 21:01 · T-114 · ajudante-rapido · CONCLUÍDA
- Feito: seção "Caminhão 3D (T-106)" na skill blender-pixelart; linhas tex_truck.py e pbr.truck_set na tabela da biblioteca (commit a7a5b59).
- Arquivos: .claude/skills/blender-pixelart/SKILL.md, docs/PIPELINE_ARTE_BLENDER.md, .claude/coordenacao/LOG.md
- Observação: cab_surface é arquivo .py com função patch() (não ".patch"); glb_stats.py fica em tools/ na raiz; com --night o sheet é truck_<tag>_night_sheet.png. Trailer do commit: Haiku 5.5 (o pedido dizia Sonnet 5.5). LOG.md não foi commitado.

## 2026-10-17 23:45 · T-115 · especialista · PRECISA DECISÃO
- Feito: análise dos 4 modelos de terceiros em docs/Novos modelos/ (só leitura). Canter = extraído de jogo (nomes *.nr do Ninja Ripper), sem vidro/textura: descartar. Cabine = International CF500 (não DAF), STL de CAD limpo, 201 peças espelhadas sem nome/cor/UV: serve como 5ª cabine com trabalho. Carro = Suzuki Samurai/Gypsy, malha única, 50 texturas 4K. Van = Partner/Berlingo, peças nomeadas: a mais fácil (tráfego).
- Arquivos: docs/NOVOS_MODELOS.md, docs/direcao_arte/novos_modelos_{todos,cf500,trafego_6k}.png; scripts de teste em blender/renders/t115/ (fora do Git)
- Validação: Blender 5.2.2 headless importou/mediu os 4 e converteu (decimate) para .glb: CF500 609.630→40.000 tri (1,4 MB), van 504.334→20.000 (0,97 MB) e 6.000 (0,38 MB), carro 436.059→30.000 (15,7 MB com texturas 1K) e 6.000 (0,32 MB sem texturas), Canter 129.583→40.000; Godot 4.7.2 headless (projeto temporário) importou e carregou os 4 .glb sem erro (rodas wheel_* achadas).
- Decisão pendente: Marco precisa informar origem/licença de cada modelo (links, se pagou). Opções: (a) licença ok → van e carro no tráfego, depois CF500 como 5ª cabine (2–3 sessões, apagar marcas); (b) sem licença → usar só como referência e fazer a 5ª cabine "cara chata" por código.
