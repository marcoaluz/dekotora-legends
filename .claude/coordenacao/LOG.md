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

## 2026-10-17 · T-116 · ajudante-rapido · CONCLUÍDA
- Feito: anotei T-115 no STATUS, decisão de modelos de terceiros no DECISOES e duas armadilhas do Blender na SKILL (commit 86c1a90).
- Arquivos: docs/STATUS.md, docs/DECISOES.md, .claude/skills/blender-pixelart/SKILL.md
- Observação: LOG.md não foi commitado (pedido da tarefa). Atribuição do commit usa Haiku 5.5 (o modelo real), não Sonnet 5.5 como pedido na tarefa.

## 2026-10-18 00:30 · T-118 · especialista · CONCLUÍDA
- Feito: texturas do caminhão compartilhadas: uma cópia em game/assets/vehicles/dekotora/textures/ (gravada pelo build via lib/shared_tex.py); .glb com miniaturas 4×4 (cor média) como reserva; TruckTextures.apply() troca em runtime (material em cache por nome), chamado pelo TruckNode (depois do cromo e do mural) e pelo visualizador de acessórios. --fps-log agora mostra memória de textura e de vídeo.
- Arquivos: blender/scripts/lib/shared_tex.py, build_truck_3d.py, game/scripts/truck/{truck_textures,truck_node}.gd, ui/accessory_viewer.gd, road3d/race_scene_3d.gd, 13 .glb + miniaturas + textures/, docs STATUS/DECISOES
- Validação: .glb 51,2 → 33,0 MB; PNG de textura 18,5 → 1,5 MB (+0,36 MB de miniaturas); .pck Windows de teste 97,5 → 54,0 MB; corrida modo médio: textura 53,1 → 43,1 MB, vídeo 87,2 → 77,2 MB, ~490 chamadas e ~75 FPS iguais; garagem padrao/aero antes x depois com diferença média de pixel 0,0006–0,0008; corrida com rival ok; 141 testes 0 falhas; corrida, garagem, accessory_viewer, chrome_compare e servidor headless abrem (avisos de saída na garagem vêm da música, já existiam).
- Decisão pendente: nenhuma. (LOG.md não commitado: tem linhas de outra tarefa sem commit.)

## 2026-10-18 02:30 · T-121+T-124 · especialista · CONCLUÍDA
- Feito: 6 veículos novos no trânsito (van01, Ascona, Falcon, SUV, Fumi esportivo, ônibus) a partir dos modelos de terceiros; tipos na simulação (tamanho/velocidade/massa, fila e ultrapassagem, hitbox por tipo).
- Arquivos: blender/scripts/build_traffic_{cars,van01}.py, lib/traffic_{kit,classify,preview}.py, game/assets/vehicles/traffic/car_*, sim/traffic_sim.gd, road3d/traffic_3d.gd, tests/test_traffic_{models,kinds}.gd, LICENCAS.md, docs, docs/capturas_t124/
- Validação: 161 testes, 0 falhas; net_test passou; build determinístico; modo médio: chamadas ~440→~420, tri ~208→~232 mil, 75 FPS igual.
- Decisão pendente: Marco aprovar velocidades/massa/frequência de ônibus e esportivo. Aviso: o commit 1637c2c (T-125) levou linhas da T-124 e só compila junto com 1998131.

## 2026-10-18 03:30 · T-125+T-126 · especialista · CONCLUÍDA
- Feito: caminhão base Canter (malha do JAC 1045, baú nosso) e cabine curta; BodyDef por modelo (massa, capacidade 4 t, hitbox 7 m, agilidade, torque); 10 peças novas (Kenworth, Fumi, JAC) com 2 encaixes novos.
- Arquivos: blender/scripts/truck3d/{jac_*,canter}.py, lib/extract.py, accessories/thirdparty.py, game/data/bodies/*.tres, tests/test_canter.gd, test_parts_thirdparty.gd, docs/capturas_t125, capturas_t126
- Validação: 165 testes, 0 falhas; modo médio 75 FPS; Canter ~340 chamadas (base ~380); 8 peças novas: +10 mil tri, mesmas chamadas.
- Decisão pendente: Marco ajustar números do Canter, preços e destaques das peças; dar números próprios ao baú leve e longo.

## 2026-10-18 · T-129 · especialista · CONCLUÍDA
- Feito: cabines só de arquivo: chata (padrão), jac (Japonesa alta), curta, americana (Kenworth); 4 cabines por código removidas (scripts, 12 .glb, 5 texturas); migração de perfis (padrao/classica/alta→chata, aero→jac); cabine vai no descritor de rede.
- Validação: 171 testes, 0 falhas; .pck de teste 68,6→57,4 MB; 75 FPS, chamadas iguais.
- Pendências: Marco aprovar nomes, chata como padrão, olhar contorno fraco no capô da americana; captura da lista de cabines na garagem ainda mostra só carrocerias. Commit 017d888 ("asda") do Marco levou arquivos em andamento.

## 2026-10-18 · T-130 · especialista · CONCLUÍDA
- Feito: inventário dos modelos (docs/INVENTARIO_MODELOS.md; Tunnel.obj/van.abc só medidos, sem copiar); placas japonesas fictícias em caminhões e tráfego; sinalização japonesa (limites, losangos, chevrons, km, 出口, placa do túnel, 止まれ no pedágio).
- Validação: 179 testes, 0 falhas; modo médio nas 3 rotas: +3 chamadas de desenho, FPS igual (75), textura +0,9 MB.
- Decisão pendente: Marco mandar link/licença de Tunnel.obj e van.abc; aprovar limites, 止まれ no pedágio e nomes de túnel.

## 2026-10-18 15:30 · T-133 · especialista · CONCLUÍDA
- Feito: pneus já giravam (13 modelos, jogador/rivais/tráfego); calotas e rodas da loja ficavam nos pontos fixos MOUNT_WHEEL_FRONT_FACE (só frente). Agora `TruckWheels` prende a peça de roda em todas as rodas externas como filha do pneu (gira e estérça junto), giro por raio de cada roda (Canter 0,45/0,43; JAC 0,55; americana 0,53), garagem gira devagar só na vista RODAS. Sem regerar .glb.
- Arquivos: game/scripts/truck/truck_wheels.gd (novo), truck_node.gd, ui/garage_stage.gd, ui/garage_screen.gd (--shot-pair), road3d/race_demo.gd (--burst), tests/test_wheels_spin.gd, tools_dev/measure_wheels.gd, docs STATUS/DECISOES/ACESSORIOS, docs/direcao_arte/rodas_girando_*.png.
- Validação: 184 testes, 0 falhas (179 + 5 novos); capturas de 2 quadros seguidos na corrida e na garagem conferidas; corrida decorada sem vsync: ~249 FPS antes, ~247 depois (ruído), +~10 chamadas, +~2 mil triângulos (peças de roda sem sombra e até 60 m).
- Decisão pendente: nenhuma (confirmar com o Marco se quer as peças visíveis além de 60 m e a velocidade do giro na garagem).

## 2026-10-18 15:40 · T-132 · especialista · CONCLUÍDA
- Feito: caminhão segue a faixa nas curvas (sim: `CurveGrip` com atrito acima da segura, deslizada <= 0,5 m, escape só acima de +30% com aviso ~2 s antes; giro do corpo só na troca de faixa, <= 3°, pivô no eixo traseiro, direção = eixo traseiro -> dianteiro). Mesma regra em bots, servidor, predição (ClientSync) e trânsito. HUD "CURVA! ALIVIE"/"DERRAPANDO!", vibração, pneu cantando pelo `skid`. Nenhum .glb girado (24 conferidos).
- Arquivos: game/scripts/sim/{curve_grip,truck_sim,traffic_sim}.gd, road3d/{track_path,race_scene_3d,traffic_3d,race_demo}.gd, ui/race_hud.gd, audio/race_audio.gd, data/i18n/pt-BR.json, tests/test_lane_following.gd, tests/test_sim_basic.gd (comentário), tools_dev/{measure_lane_following,check_glb_orientation}.gd, docs STATUS/DECISOES/BALANCEAMENTO/GDD/ROADMAP, docs/direcao_arte/faixa_curva_*.png
- Validação: medição antes (9,88 m viaduto, 7,94 m montanha, 52% corpo > 2°) reproduz o Marco; depois 0,36 / 0,25 / 0,19 m e 0% > 2° (máx 0,16°); 192 testes 0 falhas (após merge da main); net_test PASSOU (Ana estoura o prazo nos dois casos, antes e depois: já existia); capturas olhadas.
- Decisão pendente: com V8 + turbo duplo (ou 16 t) acelerando sem soltar, entra a +47% na curva 1,0 do viaduto e escapa (regra dos +30%, com aviso). Manter ou subir o limite/atrito? Aviso: a main tem um gitlink `.claude/worktrees/agent-ab772c8029a7a1802` versionado (veio da main, não desta tarefa).

## 2026-10-18 · T-138 · especialista · CONCLUÍDA
- Feito: telas por containers presas às bordas (aspect expand), resultado novo com frases claras, fundo do menu A/B nas Opções, garagem com câmera mais perto, cromo de estúdio e botão VER EM MOVIMENTO, ~115 chaves pt-BR que faltavam, teste de textos.
- Validação: 196 testes, 0 falhas na main após o merge; capturas 960x540 e 1200x540 em docs/capturas_t138/.
- Decisão pendente: fundo padrão do menu (A posto / B rodovia) e se a câmera da garagem está perto o bastante.

## 2026-10-18 · T-136 · especialista · CONCLUÍDA
- Feito: baú médio premium nas 4 cabines (alta no Blender, bake normal/AO/ORM, leve com chapa ondulada e ferragens reais), CC0 512 px, mural trocável com normais/AO; capturas antes/depois.
- Validação: 200 testes, 0 falhas na main após o merge; chamadas 302→304, textura 40,9→44,1 MB, FPS igual; baú 4,1→7,8 mil tri.
- Decisão pendente: Marco aprovar o visual e decidir se estende a leve/longo/Canter.

## 2026-10-18 · T-139 · especialista · CONCLUÍDA (com decisão pendente)
- Feito: eventos de pista (acidente, obras com limite 60 km/h, estreitamento 3→2): sim, rede (servidor sorteia, protocolo 2), bots, trânsito, visual (3 chamadas/evento, 11 no acidente), HUD, sons de reserva, folga no prazo, testes e docs.
- Validação: 211 testes, 0 falhas na main após o merge (2 conflitos aditivos resolvidos em truck_sim.gd e DECISOES.md); net_test.sh passou; FPS igual (75).
- Decisão pendente: regra das chapas de aço nas obras (alternativas: multa em ¥ ou só visual); chance de 45% e posições dos eventos fixos; viatura de polícia no acidente. Gerar o APK de novo (protocolo 2). 5 sons novos pedidos em docs/AUDIO_ELEVENLABS.md (aguardam autorização de gasto no ElevenLabs).

## 2026-10-19 · T-145 · especialista · CONCLUÍDA (PRECISA DECISÃO do Marco)
- Feito: graneleira (modelo do Marco reduzido 81k→7,8k tri, tampas com mural trocável, cabeceira torii) nas 4 cabines; garagem/perfil/rede/bot; regra carga x carroceria (grãos e brita novos; "PRECISA DE BAÚ/GRANELEIRA").
- Arquivos: blender/scripts/truck3d/{gran_src,graneleira}.py, data/bodies/graneleira.tres, data/cargo/{graos,brita}.tres, contracts.gd, game_state.gd, tests/test_graneleira.gd, docs/capturas_t145/
- Validação: 221 testes ok (merge 166f612 no branch wip/t141-t143-t144); capturas olhadas; modo médio 73–75 FPS, chamadas iguais ao baú médio.
- Decisão pendente: regra de carga, tamanho único, lona preta, 14 t / 7.500 kg, preço. Observação do coordenador: na ficha técnica a linha "Leva" fica cortada embaixo (rola o painel).
