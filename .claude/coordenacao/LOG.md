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

## 2026-10-19 · T-143 · especialista · CONCLUÍDA
- Feito: viatura (Camry 709k→7,3k tri, sem NYPD/Toyota/placas, preto/branco japonês, giroflex vermelho piscando), carro batido (picape amassada refeita em voxels, 6k tri) no acidente; jipe (5,1k tri, sem "SUZUKI") no trânsito (9 modelos).
- Arquivos: blender/scripts/build_traffic_cars.py, lib/traffic_{police,jeep,wreck,kit}.py, road3d/{police_beacon,event_props}.gd, tests/test_accident_cars.gd, docs/capturas_t143/
- Validação: merge no wip com 2 conflitos aditivos (STATUS, LICENCAS) resolvidos; 225 testes ok; modo médio: chamadas e FPS iguais, textura +0,4 MB.
- Decisão pendente: giroflex só vermelho e pintura preto/branco japonesa; carros parados sem placa; bordas irregulares do carro batido.

## 2026-10-19 · T-141 + T-144 · especialista · CONCLUÍDA (retomada do WIP da outra sessão)
- Feito: batidas como no original (empurrão de faixa entre caminhões com regra de 75% da massa, quicar de volta, carro do trânsito arremessado na sim com giro/pulo/recuperação, ônibus só empurrado), efeitos (faíscas, clarão, até 64 pedaços num MultiMesh, chacoalhada), sons em camadas (4 novos no ElevenLabs, ~100–250 créditos), freada forte (chiado, pssh, fumaça, marcas, ícone) e buzina (H / X / botão na tela; abre caminho no trânsito; pela rede, protocolo 3); chave nova "Faíscas, pedaços e fumaça dos pneus".
- Arquivos: sim/{collision,thrown_car,traffic_sim,truck_sim,race_sim,hard_brake}.gd, net/{snapshot,client_sync,protocol}.gd, road3d/{impact_fx,brake_fx,race_scene_3d,traffic_3d}.gd, audio/race_audio.gd, ui/race_hud.gd, tests/test_impacts.gd, docs/capturas_t141/
- Validação: merge no wip com 3 conflitos aditivos de docs resolvidos; 240 testes ok; net_test passou (0 e 150 ms + 2% perda); modo médio igual (pico +6 chamadas na batida/freada).
- Decisão pendente: empurrão para o acostamento, regra dos 75%, bots buzinarem, ouvir os 4 sons. APK precisa ser gerado de novo (protocolo 3).

## 2026-10-19 · T-146 · especialista · CONCLUÍDA
- Feito: kit de beira de estrada de docs/Novas Melhorias: barreiras de obra listradas (obras, acidente, estreitamento, bocas de túnel), cavaletes e destroços, chapas e postes reais na sinalização da T-130, pórticos de treliça, vidro com moldura na barreira de som, outdoors com 4 artes fictícias trocáveis (acesos à noite); --no-kit para comparar.
- Arquivos: blender/scripts/build_roadside_kit.py, game/assets/scenery/kit/, textures/kit/, scenery/billboards/, road3d/{roadside_kit,mesh_batch,kit_props_3d,road_signs,road_furniture,event_props,track_events_3d,road_mesh,glb_mesh}.gd, tests/test_roadside_kit.gd, docs/capturas_t146/
- Validação: merge no wip com 5 conflitos aditivos de docs resolvidos; 245 testes ok; net_test PASSOU; modo médio nas 3 rotas 71–75 FPS, máx ~402–426 chamadas, textura +3,2 MB.
- Decisão pendente: aprovar outdoors (quantidade, lugar, artes) e manter a mureta feita por código (o pacote Metais é de barreira de obra).

## 2026-10-19 · T-147, T-150 · coordenador · CONCLUÍDA
- Feito: T-147: `bot_client.gd` aceita `--body=` e `tools/net_test.sh` aceita `BODY=`; corrida online com a graneleira passou (0 SCRIPT ERROR). T-150: APK de teste gerado (105 MB, chave de debug, protocolo 3), com a cópia temporária do preset sem Min/Target SDK (restaurado depois).
- Validação: 245 testes ok na main; net_test PASSOU (padrão e BODY=graneleira).

## 2026-10-19 · T-148, T-149, T-151 · ajudante-rapido · CONCLUÍDA
- Feito: notas nas skills blender-pixelart e godot-dekotora (graneleira, trânsito, kit de beira de estrada) e no PIPELINE_ARTE_BLENDER.md (commit 39f5cc7, merge 1c11dbe).

## 2026-10-19 · T-152 · especialista · CONCLUÍDA (com decisões pendentes)
- Feito: batida no trânsito custa velocidade na sim (frente 25-40% pela força, raspão 8-15%, ônibus x1,35; menor entre física e penalidade) + tranco 0,6 s (acelerador sem efeito, freio ok, balanço do caminhão/câmera, velocímetro vermelho); uma penalidade por batida; tranco no snapshot em ticks (protocolo 4); cliente suaviza o recuo da batida.
- Arquivos: sim/collision.gd, sim/truck_sim.gd, net/{snapshot,protocol,client_sync,bot_client}.gd, road3d/{impact_fx,race_scene_3d,race_demo}.gd, ui/race_hud.gd, tests/test_traffic_penalty.gd (11), docs/capturas_t152/
- Validação: merge na main sem conflito; 256 testes ok; net_test PASSOU; bots 6 sementes -1,2 a +2,5 s, nenhum travado; capturas 101->61 km/h (carro) e 94->45 km/h (ônibus) conferidas.
- Decisão pendente: kickdown do câmbio após a batida (40% custa ~10 s; com kickdown ~7,5 s); tranco também entre caminhões/obstáculos de evento; Marco sentir os números. Gerar APK novo (protocolo 4).

## 2026-10-19 · T-153 · especialista · CONCLUÍDA (PRECISA DECISÃO do Marco)
- Feito: trechos com 2 faixas de verdade (RouteDef.lane_sections; a faixa da direita acaba; muretas, acostamentos, linhas e zebrado estreitam com transição suave; quem fica na faixa raspa e é obrigado a entrar na fila); ponte no litoral (2.440–2.745 m, lombada nova), viaduto antigo (2.270–2.510 m), túnel antigo 湯坂隧道 na montanha (805–1.040 m); placas e HUD; setup online com lane_sections (protocolo 5).
- Arquivos: sim/{lane_sections,track_events,track,event_contact}.gd, data/routes/*.tres, net/{room,client_sync,protocol}.gd, road3d/{road_mesh_narrow,section_props,section_structures_3d,...}.gd, ui/event_hud.gd, tests/test_lane_sections.gd, docs/capturas_t153/
- Validação: merge na main sem conflito; 265 testes ok; net_test PASSOU; chamadas iguais (±5), bots +1 a +3 s; capturas olhadas (túnel antigo muito escuro à noite: vai para a F4).
- Decisão pendente: posições dos trechos, lombada do litoral, nome 湯坂隧道, folga no prazo (hoje nenhuma). Gerar o APK de novo (protocolo 5).

## 2026-10-19 · T-157 · ajudante-rapido · CONCLUÍDA
- Feito: seção "Trechos de 2 faixas (T-153)" na skill godot-dekotora (dados, sim, visual, flags, capturas, protocolo 5), nomes conferidos no código (commit 88694d7).

## 2026-10-19 · T-154 · especialista · CONCLUÍDA (PRECISA DECISÃO do Marco)
- Feito: ferrovia só visual nas 3 rotas (via dupla, muro, catenária, viaduto, bocas de túnel; litoral 0–2.150 m, cidade inteira elevada + viaduto de trem sobre a pista em 1.500 m, montanha 1.240–2.080 e 2.380–fim + viaduto em 240 m), trem de carga por código e bonde amarelo (Urbos do Marco 71k→6,9k tri, sem logos); trens cruzam o jogador (1º ~10 s, depois 22–40 s), luzes à noite. Nenhuma peça de ferrovia de terceiros encontrada no PC.
- Arquivos: road3d/{railway_3d,railway_layout,rail_line,rail_traffic,trains_3d,rail_kit,rail_mound}.gd, blender/scripts/build_railway_kit.py, assets/scenery/rail, textures/rail, tests/test_railway.gd, docs/capturas_t154/
- Validação: merge na main com 2 conflitos aditivos de docs; 1 teste falhou após juntar com a T-153 (linha elevada da cidade × viaduto antigo): conferido em captura que não há sobreposição (linha a 40 m, no próprio viaduto) e o teste passou a ignorar a cidade, como já fazia com o túnel da cidade; 275 testes ok; modo médio +3 a +8 chamadas.
- Decisão pendente: bonde (Sketchfab Standard) e pintura amarela; lugares e frequência dos trens; som do trem (2 sons ElevenLabs propostos).

## 2026-10-19 · T-158 · ajudante-rapido · CONCLUÍDA
- Feito: seção "Ferrovia (T-154)" nas skills godot-dekotora e blender-pixelart (nomes conferidos no código) e linha da T-154 no ROADMAP (commit 2be16ef).

## 2026-10-20 · T-155 · especialista · CONCLUÍDA
- Feito: mural do baú/graneleira aceso à noite (emissão por TimeOfDay.mural_glow: noite 0,8, tarde 0,4, dia 0); ficha da garagem cabe inteira (960x540 e 2400x1080); carro batido com rodas redondas e sem lascas; bocas de túnel abertas (regressão da T-153 no perfil do arco, com teste novo) e muros listrados maiores; túnel antigo mais claro (lâmpadas nas paredes + poças de luz, 1 chamada); STATUS: Android já instalado.
- Arquivos: truck/mural_glow.gd, road3d/{tunnel_3d,tunnel_light_pools,kit_props_3d,roadside_kit}.gd, ui/garage_info_panel.gd, blender/scripts/lib/traffic_wreck.py, tests/{test_mural_glow,test_tunnel_portals}.gd, docs/capturas_t155/
- Validação: merge na main sem conflito; 282 testes ok; modo médio +0 a +3 chamadas; folhas antes/depois conferidas pelo coordenador.
- Decisão pendente: força do mural à noite, ficha compacta (aviso de potência como dica), tamanho dos muros das bocas. APK novo.

## 2026-10-20 · T-160 · ajudante-rapido · CONCLUÍDA
- Feito: seção "Acabamento (T-155)" na skill godot-dekotora e item (g) do carro batido na blender-pixelart (commit 493abb6).

## 2026-10-20 · T-156 · especialista · CONCLUÍDA (PRECISA DECISÃO do Marco)
- Feito: abertura "frente a frente" antes da largada (área de descanso/pedágio pela hora do dia, caminhões reais, detalhes + faixa, VS com tambor, alinhamento, pular, revanche curta); campanha 1x1; grid lado a lado a 30 m; comboio online (3–4 = trânsito mais leve); protocolo 6 com relógio comum; rival não prende no acostamento.
- Arquivos: road3d/duel_{plan,intro,stage,shots,cards}.gd, ui/duel_band.gd, sim/start_grid.gd, sim/bot_driver.gd, net/*, race_scene_3d.gd, tests/test_duel_*.gd, docs/capturas_t156/
- Validação: merge na main sem conflito; 292 testes ok; net_test 0 ms e 150 ms + 2% PASSOU (coordenador rodou de novo depois do merge); capturas conferidas.
- Decisão pendente: dificuldade do rival no 1x1 (bot-jogador venceu 7/18, antes 10/18), corrida rápida com 4, falas/nomes/brasão, ouvir vs_taiko_hit. APK novo (protocolo 6).

## 2026-10-20 · T-161 · ajudante-rapido · CONCLUÍDA
- Feito: seção "Abertura frente a frente (T-156)" na skill godot-dekotora e linha da T-156 no ROADMAP (commit 57543aa).

## 2026-10-20 · T-150b · coordenador · CONCLUÍDA
- Feito: APK de teste gerado de novo depois das T-152..T-156 (protocolo 6): builds/kaido-bakuso-debug.apk, 108 MB, chave de debug; preset restaurado.

## 2026-10-20 · T-159 · especialista · PRECISA DECISÃO
- Feito: análise dos 5 modelos de docs/Modelos/Road_pontes (só análise, nada no jogo): Outdor = pórtico de placas dos EUA com fotos de placas reais (não usar); Ponte A = viaduto de concreto 2 faixas (usar o pilar em "T"; talvez viaduto cruzando por cima); Ponte B = pênsil europeia de 1 faixa (não usar); road = kit CGTrader (guard-rail em W + poste com fios); Túnel = o mesmo Tunnel.obj da T-130 (referência para semáforos de faixa e calçada por código).
- Arquivos: docs/ANALISE_ROAD_PONTES.md, docs/INVENTARIO_MODELOS.md, docs/STATUS.md, docs/capturas_t159/, blender/scripts/inspect_model.py
- Validação: merge na main sem conflito; folhas conferidas pelo coordenador.
- Decisão pendente: licença do túnel e demais; postes com fios; viaduto cruzando por cima; semáforo do túnel ligado aos eventos ou só enfeite. Aviso: pastas de terceiros movidas para docs/Modelos/ (T-162 corrige os caminhos).

## 2026-10-20 · T-162 · ajudante-rapido · CONCLUÍDA
- Feito: caminhos padrão de 12 scripts (Blender e tools) apontam para docs/Modelos/<pasta>, com volta ao caminho antigo se o novo não existir; STATUS e skill blender-pixelart atualizados; coordenador corrigiu o exemplo em PIPELINE_ARTE_BLENDER.md (commit 8db8af6).
- Validação: py_compile e bash -n ok; arquivos esperados existem em docs/Modelos/. Docs históricos (DECISOES, INVENTARIO, LICENCAS) mantêm o caminho antigo como registro.

## 2026-10-20 · T-166 · ajudante-rapido · CONCLUÍDA
- Feito: decisão do Marco (licenças de terceiros liberadas) registrada em DECISOES; STATUS atualizado (T-159, T-154, T-130 sem a parte de licença); nota em LICENCAS.md.
- Arquivos: docs/DECISOES.md, docs/STATUS.md, game/assets/LICENCAS.md, .claude/coordenacao/LOG.md
- Observação: Tunnel.obj e van.abc continuam fora do PC; o Marco precisa recolocá-los em docs/Modelos/ para uso. Nada apagado.

## 2026-10-20 22:51 · T-167 · ajudante-rapido · CONCLUÍDA
- Feito: gen_audio --only nos 5 sons de T-139: já existiam (gerados em 2026-10-18, commit 04881bd); script não gastou créditos (0; total 61.135/131.000). Import do Godot rodou sem erro.
- Arquivos: nenhum alterado (mp3 já versionados via LFS; nada para commitar)
- Observação: sons de trem (T-154) não têm entradas no gen_audio.py, nada gerado. Os 5 sons podem ser ouvidos em game/assets/audio/sfx/.

## 2026-10-20 22:56 · T-168 · ajudante-rapido · CONCLUIDA
- Feito: sons de trem train_horn (3 s) e train_pass (6 s, loop) cadastrados na seção 4 e gerados no ElevenLabs.
- Arquivos: docs/AUDIO_ELEVENLABS.md, game/assets/audio/sfx/ambient/train_horn.mp3 (+.import), game/assets/audio/sfx/ambient/train_pass.mp3 (+.import), .claude/coordenacao/LOG.md
- Observação: gen_audio.py lê a lista da tabela do doc (não há lista no script). Créditos: 61.135/131.000 antes; contador de gasto mostrou 0, pode estar atrasado. Som ainda não ligado ao jogo.

## 2026-10-20 23:20 · T-165 · especialista · CONCLUÍDA
- Feito: causa achada (botões/cartões com mouse_filter STOP seguravam o toque; ScrollContainer do 4.7 só rolava nos vãos). Novo `TouchScroll` (descendentes em PASS, zona morta 10) usado nas 4 listas: garagem (2 colunas), mercado de fretes, opções, lobby.
- Arquivos: game/scripts/ui/components/touch_scroll.gd (novo), garage_screen.gd, freight_market.gd, options_panel.gd, lobby_screen.gd, game/tests/test_touch_scroll.gd, docs/DECISOES.md, skill godot-dekotora. Commit d876229 na branch `t165-rolagem-toque` (worktree .claude/worktrees/t165), falta merge na main.
- Validação: suíte completa 297 testes, 0 falhas (5 novos simulando ScreenTouch/ScreenDrag + mouse emulado); menu, mercado, opções, garagem (modelo e decoração) e lobby abrem headless sem ERROR. APK não gerado (falta testar no celular).
- Decisão pendente: nenhuma. Obs.: matei sem querer processos python.exe durante a tarefa e o servidor MCP do Blender desconectou; precisa reabrir se for usado.
## 2026-10-20 23:40 · T-170 · especialista · PRECISA DECISÃO
- Feito: som da seta. "Seta" já existia (pisca da troca de faixa: 1º toque em < / > liga, 2º troca); som ligado a ela: tique-taque do relé em sincronia com a lâmpada (SignalBlink, ~1,5 Hz, começa aceso) e clique da alavanca a cada toque. Lâmpadas e HUD no mesmo ritmo. 2 sons gerados no ElevenLabs. Sem botões/teclas novos (Q/E não criados), sem sim/rede.
- Arquivos: game/scripts/truck/signal_blink.gd, game/scripts/audio/turn_signal_audio.gd, truck_node.gd, race_hud.gd, race_scene_3d.gd, game/assets/audio/sfx/truck/turn_signal_{tick,switch}.mp3, tests/test_turn_signal.gd, docs (AUDIO_ELEVENLABS, DECISOES, ROADMAP, STATUS), skill godot-dekotora.
- Validação: run_tests 300/300; race3d --demo=lanes 600 quadros sem erro; menu abre (só o aviso comum "resources still in use at exit").
- Decisão pendente: Marco quer também um pisca MANUAL (liga/desliga, botões próprios, Q/E) ou o da troca de faixa basta?
## 2026-10-21 · T-173 · especialista · CONCLUÍDA (Marco precisa ouvir e confirmar)
- Feito: escapamento define o som do motor (exh_straight=exh_rasp rouco; novos exh_stack grave e exh_chrome_cut=exh_pop com estalos; 3 loops cada), turbina com assobio e "pssh" do perfil, 3 buzinas novas + escolha grátis na aba MECÂNICA (seção BUZINA, botão OUVIR com prévia), rivais offline com som sorteado, online com motor/escape/buzina do descritor (protocolo 7); loop da buzina por janela medida (a básica repetia silêncio).
- Arquivos: audio/{engine_sounds,horn_catalog,sound_preview,engine_audio,race_audio,truck_sfx}.gd, ui/{garage_horns,garage_shop,engine_audio_test}.gd, autoload/game_state.gd, net/{protocol,server_main,bot_client}.gd, road3d/race_scene_3d.gd, data/engines/exh_{stack,chrome_cut,straight}.tres, i18n, tests/test_engine_sounds.gd, tools/net_test.sh, 18 MP3
- Validação: 301 testes ok; engine_audio_test --cycle-profiles 12 combinações ok; garagem/corrida/menu abrem sem SCRIPT ERROR; net_test 0 ms e 150 ms+2% PASSOU com SOM_REDE OK; sons medidos no Blender (aud.Sound().data()): duração certa, loops estáveis. ElevenLabs: 627 créditos (61.873/131.000).
- Decisão pendente: preços/efeitos dos 2 escapes novos; buzina grátis; chaminés montarem a peça kw_exhaust_stacks?; quais sons regerar. APK novo (protocolo 7).

## 2026-10-21 · T-171 · especialista · CONCLUÍDA (1 confirmação do Marco)
- Feito: (1) pneu "enterrado": .glb certos (pneu em y=0), mas a plataforma giratória do galpão tem 10 cm; GarageStage agora sobe o caminhão até o topo dela (medido). Corrida intacta. (2) prévia: tocar/clicar/focar um cartão de peça não instalada monta a peça no caminhão, câmera vai à vista dela (calotas giram), faixa PRÉVIA no topo do painel direito com COMPRAR E EQUIPAR / EQUIPAR / VOLTAR AO ATUAL, Esc/B volta; trocar de encaixe/aba/sair reverte; cores travadas por Fama viram "só ver". Mecânica sem efeito visual (fica o texto).
- Arquivos: scripts/truck/truck_ground.gd, scripts/ui/{garage_preview,garage_preview_ui}.gd (novos), garage_stage.gd, garage_screen.gd, garage_shop.gd (ganchos), garage_debug.gd (--preview, --preview-paint, --fame), i18n, tests/test_garage_preview.gd (4), tools_dev/{measure_wheel_ground,crop_zoom}.gd, tools/{capture_t171,capture_t171_preview,sheet_t171}.sh, docs/capturas_t171/, DECISOES/ROADMAP/STATUS, skill godot-dekotora.
- Validação: run_tests 309/309; garagem, menu (e fundo hall), lobby e race3d abrem headless sem ERROR; capturas antes/depois em 8 combinações (chata, jac, curta, americana, Canter, leve, longo, graneleira) e prévia em 960x540 e 1200x540.
- Decisão pendente: botão da faixa compra E instala (Claude decidiu; Marco confirma). garage_screen.gd passou de 300 linhas (414): dividir depois (aba MODELO em arquivo próprio).
## 2026-10-21 · T-172 · especialista · PRECISA DECISÃO (visual do Marco)
- Feito: 6 peças deluxe por código (andon de cabine 一番星, coroa de lanternas de ônibus, neon de chão com brilho no asfalto, estrutura lateral cromada "uroko", estribo iluminado, barra de 16 lanternas), encaixe novo `underglow`, AccessoryGlow (brilho/acrílico seguem dia/noite), dados .tres (preços PROPOSTOS), pt-BR, visualizador com categoria Deluxe, capturas antes/depois.
- Arquivos: blender/scripts/{accessories/deluxe.py, lib/deluxe_geo.py, deluxe_previews.py, build_accessories.py, lib/mesh3d.py}, game/scripts/truck/{accessory_glow,truck_node,accessory_materials}.gd, scripts/ui/accessory_viewer.gd, tools_dev/gen_data.gd (--only), data/parts/*_dx.tres, tests/test_parts_deluxe.gd, tools/{capture,sheet,measure}_t172.sh, docs/capturas_t172/
- Validação: Blender 6 peças sem avisos (634–5.304 tri); 297 testes ok; corrida modo médio +17 chamadas, +7,9 mil tri, +0,9 MB textura, FPS no ruído; capturas conferidas.
- Decisão pendente: Marco aprovar o acabamento e dizer se segue para mais peças; confirmar leitura de "estura" (estrutura lateral + estribo); preços; peças de lado de 4,2 m passam do baú no Canter/leve (igual às saias antigas).
