# STATUS — contexto para retomar o trabalho (outra sessão/conta)

Atualize ao fim de CADA tarefa. Leia antes: `CLAUDE.md`, `docs/AGENTES.md`, `docs/ROADMAP.md`, `docs/DECISOES.md`.
Última atualização: **2026-10-22** (T-193: modelos das pastas novas de docs/Modelos no jogo: trens variados, 2 carros no trânsito, 8 prédios texturizados + skyline, neon kanji, carro único; antes: T-192 cenário nas 3 rotas inteiras). Todos os prompts P00–P81 foram executados até onde dá **sem o celular/contas do Marco**.

## Ambiente do PC do Marco (Windows 10, Git Bash + PowerShell)

- Godot 4.7.2: `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe` (fora do PATH). Modelos de exportação completos em
  `%APPDATA%\Godot\export_templates\4.7.2.stable` (extraídos de `D:\DEV\Godot\dl\*.tpz`).
- Blender 5.2.2 LTS: `D:\Blender\blender.exe` (fora do PATH). `bpy` + numpy OK.
- No bash: `source tools/env.sh` define `$GODOT` e `$BLENDER`.
- Projeto em `D:\DEV\dekotora-legends\dekotora-legends` (git local; **sem remoto GitHub** ainda; LFS ativo para mp3/ttf/blend).
- **Android: JÁ INSTALADO, não instale de novo.** Em `D:\DEV\android-tools\` (sem administrador): JDK 17 Temurin
  (`jdk\jdk-17.0.20.1+1`), Android SDK (`sdk`: Platform 36, Build-Tools 36.0.0, Platform-Tools, command-line tools).
  O APK de teste já é gerado: `godot --headless --path game --export-debug "Android" ../builds/kaido-bakuso-debug.apk`
  (**120 MB em 2026-10-22 12:10 (T-194: Ultra/vida T-189, cenário inteiro T-192, modelos novos T-193), protocolo de rede 8**, chave de debug; antes 114 MB das 19:35 de 2026-10-21 (T-187, cenário da T-186), 111 MB das 15:42 (T-184, com carro acidentado T-183), 111 MB das 14:53 (T-182, com câmera livre T-181 e T-177/178/179, protocolo 7), 111 MB das 11:36 e 105 MB em 2026-10-19), usando uma **cópia temporária** do `export_presets.cfg` com "Min SDK"/"Target SDK"
  vazios (Gradle desligado) e restaurando depois; passo a passo em `docs/RELEASE_ANDROID.md`. Instalar no celular:
  `D:\DEV\android-tools\sdk\platform-tools\adb.exe install -r builds\kaido-bakuso-debug.apk`.
- Python do sistema não tem numpy/Pillow (use o Python do Blender, ver `tools/image_resize.py`).
- Chave da API de áudio: `.chaves.env` (ignorado pelo git; variáveis `ELEVENLABS_API_KEY`, `PIXELLAB_API_KEY`). Nunca imprimir o valor.
- **Ferramenta Bash do Claude Code**: comandos grandes com heredocs/aspas às vezes falham ("unexpected EOF"). Crie arquivos com a
  ferramenta Write e rode patches Python por arquivo. `rm -rf $VAR/*` é bloqueado: use `"${VAR:?}"/*`.

## Como validar tudo (o Marco pode rodar)

| O quê | Comando (na raiz do projeto) |
| --- | --- |
| Abertura frente a frente (T-156) | corrida da campanha normal (Continuar) mostra a cena; forçar `-- --route=kanto_2_viaduct --intro=full\|short\|none`; capturas `GODOT=... bash tools/capture_t156.sh PASTA [dia noite tarde curta comboio]`; custo `bash tools/measure_t156.sh` (`MEASURE_EXTRA="--intro=none"` compara); duelo sem tela `godot --headless --path game -s res://tools_dev/measure_duel.gd [-- --seeds=6]` |
| Biblioteca de cenário (T-186) | inventário `bash tools/inventory_models.sh`; corrida com as árvores/postes/pessoas novas é a normal; antigo: `-- --old-trees --old-lamps --no-people`; `--no-tree-lod`; prints com a câmera livre sem teclado `GODOT=... bash tools/capture_t186.sh PASTA [extras]` (`--freecam --freecam-tour=PASTA --tour=nome@km,lat,alt,giro,incl;...`); custo `bash tools/measure_t186.sh [quadros] [day|night]` (`MEASURE_EXTRA="--old-trees --old-lamps --no-people"`); folha dos modelos `godot --path game --resolution 640x480 -s res://tools_dev/model_sheet_t186.gd -- --out=PASTA_ABS`; contagem de árvores `-s res://tools_dev/probe_groves.gd`; testes `-- --only=scenery_t186`; detalhes em `docs/BIBLIOTECA_CENARIO.md` |
| Cenário novo na rota inteira (T-188 + T-192) | padrão na corrida normal, nas 3 rotas do km 0 ao fim: `-- --route=kanto_3_mountain --start=300 --time=night`; só o antigo trecho-piloto `-- --t188=segment`; antigo `-- --t188=off`; prints da rota inteira `bash tools/capture_t192.sh PASTA [day night] [-- extras]` + folhas `bash tools/sheet_t192.sh` (em `docs/capturas_t192/`); custo `bash tools/measure_t192.sh [3000] [night]`; árvores `blender -b --factory-startup -P blender/scripts/build_foliage_t192.py -- --preview`; testes `-- --only=scenery_t192`; T-188: prints `GODOT=... bash tools/capture_t188.sh PASTA [day night] [-- extras]` + folhas `bash tools/sheet_t188.sh` (em `docs/capturas_t188/`); custo `bash tools/measure_t188.sh [quadros] [day ou night]` (`MEASURE_EXTRA="--t188=off"`); texturas `blender -b --factory-startup -P blender/scripts/build_t188_textures.py` e `godot --path game -s res://tools_dev/make_neon_atlas.gd` (janela); testes `-- --only=scenery_t188`; no log aparece `SCENIC_T188 ...` |
| Modelos novos (T-193) | corrida normal; desligar `-- --no-city-models` (prédios texturizados e skyline), `--no-unique-car`; trens `--train=freight`; prints `bash tools/capture_t193.sh PASTA [day night]` (em `docs/capturas_t193/`, folhas `folha_day/night/trens/modelos.png`); custo `MEASURE_Q=media bash tools/measure_t192.sh 3000 night` (antes: `MEASURE_EXTRA="--no-city-models --no-unique-car"`, em `docs/capturas_t193/custo_*.txt`); carro único `-s res://tools_dev/probe_unique_t193.gd`; regerar: ver `docs/BIBLIOTECA_CENARIO.md` seção 4; testes `-- --only=scenery_t193` |
| PC Ultra + vida do cenário (T-189) | PC abre em Forward+/Ultra; Opções > Gráficos: Qualidade (Ultra só no PC), "Vida do cenário", "Borrão de velocidade", "Chuva"; forçar `-- --quality=3`, `--life=off\|on`, `--rain`/`--no-rain`, `--motion-blur`, `--time=dawn`; média como no celular: `godot --path game --rendering-method gl_compatibility ... -- --quality=1 --life=off`; prints `GODOT=... bash tools/capture_t189.sh PASTA [day night]` (em `docs/capturas_t189/`, folhas `folha_day/night.png`: esquerda média, direita Ultra); FPS `bash tools/measure_t189.sh [quadros] [day\|night] [1920x1080]`; testes `-- --only=ultra_look` e `-- --only=race_life`; no log `LIFE_T189 ...` |
| Câmera livre / explorador (T-181) | `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_3_mountain --freecam` (já abre nela) ou F1 dentro da corrida; comandos na seção "Câmera livre" abaixo; testes `-- --only=freecam` |
| Testes automáticos (395) | `godot --headless --path game -s res://tests/run_tests.gd` (código de saída 0 = passou) |
| Garagem: prévia e pneus (T-171) | `-- --demo --noparts --preview=fb_gold_wing` (peça em prévia), `--preview-paint=#f0b83a --fame=0` (cor travada); capturas `bash tools/capture_t171_preview.sh PASTA`, pneus `bash tools/capture_t171.sh PASTA [wheel\|side\|default]` + `bash tools/sheet_t171.sh`; medida dos pneus `godot --headless --path game -s res://tools_dev/measure_wheel_ground.gd` |
| Jogo (menu) | `godot --path game` |
| Corrida direto | `godot --path game res://scenes/race/race3d.tscn` (WASD/setas, Espaço = Passing, Esc = pausa) |
| Garagem | menu → GARAGEM (debug: `-- --demo --damage --tab=repair --slot=front_bumper`) |
| Demonstração dos acessórios | `godot --path game res://scenes/tools/accessory_viewer.tscn` |
| Som do motor | `godot --path game res://scenes/tools/engine_audio_test.tscn` (T-173: escapamentos, turbinas, buzinas; sem tela: `--headless ... -- --cycle-profiles`). T-197: botão DIRIGIR (roteiro lenta → marchas → freio-motor → freada), Leve (Canter), Som antigo, Cabine |
| Gravar o som do jogo em .wav (T-197) | `GODOT=... bash tools/render_t197_audio.sh [PASTA]` (Movie Maker, uma janela por vez, ~50 s cada; espectrogramas e análise com `tools/audio_t197_report.py`). Regerar os sons sintetizados: `python tools/synth_truck_audio.py` e depois `--import` |
| Multiplayer ponta a ponta | `bash tools/net_test.sh` e `bash tools/net_test.sh 150 0.02` |
| Servidor (PC) | `tools\run_server.bat` (guia: `docs/REDE_WIFI.md`) |
| Eventos de pista (T-139) | `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_2_viaduct --start=1650` (acidente fixo em 2.000 m); forçar: `--event=accident:2-3@900`, `--event=works:3@700+170`, `--event=narrow:1@800`; `--no-events`; `--event-seed=N` |
| Carro acidentado (T-183) | `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_1_coast --no-events --demo=crash --start=300 --start-speed=28 --cam=wreck` (a câmera vai para o carro batido: pisca-alerta, fumaça, triângulo; `--time=night`); console: `ACIDENTADO carro N: ... v=0.0 m/s`; capturas `bash tools/capture_t183.sh PASTA` (em `docs/capturas_t183/`); sem tela `godot --headless --path game -s res://tools_dev/trace_wreck.gd` (antes/depois em `docs/capturas_t183/trace_*.txt`); testes `-- --only=wreck` |
| Batidas e freada (T-141/T-144) | `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_1_coast --no-events --demo=crash --start=300 --start-speed=28` (bate no trânsito; `--cam=21,7,3.2,12,0,1.2` vê de lado); `--demo=brake --start-speed=30` (buzina e freada forte); `--no-impact-fx` desliga os efeitos; com `--shots=PASTA` o `--demo=crash` grava `batida_antes` e `batida_a..e` e o console mostra `BATIDA ... 101 -> 61 km/h (penalidade 40%)` (T-152); sonda: `godot --path game -s res://tools_dev/fx_probe.gd -- --out=X.png [--brake]` |
| Batidas por corrida | `godot --headless --path game -s res://tools_dev/measure_impacts.gd [-- --seeds=4 --route=ROTA]` (T-152: chegada de cada bot e quanto as batidas custaram) |
| Custo dos eventos no tempo | `godot --headless --path game -s res://tools_dev/measure_event_times.gd [-- --seeds=5 --route=ROTA]` |
| Trechos de 2 faixas (T-153) | corrida: `-- --route=kanto_1_coast --start=2200` (ponte), `--route=kanto_2_viaduct --start=2100` (viaduto antigo), `--route=kanto_3_mountain --start=560` (túnel antigo); `--no-sections` tira os trechos (comparar); capturas `bash tools/capture_t153.sh PASTA [filtro]`; custo `bash tools/measure_t153.sh [quadros] [--no-sections]`; sem tela: `tools_dev/trace_section.gd -- --route=R [--human] [--log]` e `tools_dev/measure_section_times.gd`; só estes testes: `-s res://tests/run_tests.gd -- --only=lane_sections` |
| Kit de beira de estrada (T-146) | `blender -b --factory-startup -P blender/scripts/build_roadside_kit.py -- --src "CAMINHO/docs/Modelos/Novas Melhorias" [--preview]` (modelos e texturas reduzidos); artes dos outdoors: `godot --path game -s res://tools_dev/make_billboard_art.gd`; capturas `GODOT=... bash tools/capture_t146.sh PASTA [--no-kit]`; custo `bash tools/measure_roadside.sh` e `bash tools/measure_roadside_spot.sh` |
| Ferrovia e trens (T-154) | `blender -b --factory-startup -P blender/scripts/build_railway_kit.py -- --lrt-src "CAMINHO/docs/Modelos/Modelos Melhorados/kaohsiung_circular_light_rail_caf_urbos_3.glb" [--preview]` (modelos e texturas; `--no-lrt` pula o bonde); corrida: `--no-rail` desliga, `--train=freight\|lrt` e `--train-dir=same\|opposite` forçam o próximo trem; capturas `GODOT=... bash tools/capture_t154.sh PASTA [cenas]`; custo `GODOT=... bash tools/measure_railway.sh` |
| Acabamento F4 (T-155) | capturas antes/depois `bash tools/capture_t155.sh PASTA [mural\|ficha\|batido\|tunel]` e folhas `bash tools/sheet_t155.sh` (em `docs/capturas_t155/`); custo `bash tools/measure_t155.sh`; carro batido `blender -b --factory-startup -P blender/scripts/build_traffic_cars.py -- --model wreck --wreck-dir "<pasta principal>/docs/Modelos/Novas Melhorias"` |
| Cenário novo T-169 (+T-163/T-164) | gerar: `blender -b --factory-startup -P blender/scripts/build_backdrop_kit.py -- --snow-src "<pasta principal>/docs/Modelos/Fundo Montanha Gelo/sNOWlaNDSCAPE.fbx" --water-src "<...>/docs/Modelos/Agua/Water_Pack_Ozero.blend" [--preview]`, `build_tree_kit.py -- --src "<...>/docs/Modelos/Arvore"`, `build_road_pontes_kit.py -- --src "<...>/docs/Modelos/Road_pontes" --pole-src "<...>/docs/Modelos/poste/Utility_pole.blend"`; capturas `GODOT=... bash tools/capture_t169.sh PASTA [filtro] [--no-backdrop --no-pontes-kit --no-lane-signals]`; custo `bash tools/measure_t169.sh [quadros] [day\|night]`; corrida: viaduto `-- --route=kanto_2_viaduct --start=1950` ou `--route=kanto_3_mountain --start=2480`; semáforo com X `--route=kanto_2_viaduct --start=975 --event=works:3@1180+170`; desligar: `--no-backdrop`, `--no-pontes-kit`, `--no-overpass`, `--no-poles`, `--no-lane-signals`; testes `-- --only=scenery_t169`; onde cabe viaduto `-s res://tools_dev/find_overpass_spots.gd` |
| Montanhas visíveis (T-179) | capturas com a câmera do jogo, hora da própria rota e modo médio: `GODOT=... bash tools/capture_t179.sh PASTA [filtro]` (corrida rápida, litoral, viaduto, montanha); folhas antes/depois `bash tools/sheet_t179.sh ANTES DEPOIS` (em `docs/capturas_t179/`); `--view-far=900` volta à câmera antiga; testes `-- --only=scenery_t179` |
| Build Windows | `godot --headless --path game --export-release "Windows" ../builds/dekotora.exe` (testado: roda a corrida 3D com áudio) |

## Câmera livre de exploração (T-181)

Para andar pelo mapa e apontar problemas ("objeto X no km 1,2 está flutuando"). A corrida **congela** (simulação, bots,
trânsito e som) enquanto ela está ligada; ao sair, a corrida volta exatamente do mesmo ponto, com a câmera normal.

- **Quem pode usar**: build de debug (o Godot do PC e o APK de teste) sempre; versão final só com **Opções > Avançado >
  Modo explorador (câmera livre)** ligado (gravado em `user://settings.cfg`, seção `[advanced]`); ou com `--freecam`.
- **Nunca na corrida online**: lá a simulação é do servidor e dos outros jogadores (não dá para pausar); F1 e `--freecam` não fazem nada.
- **Ligar**: `-- --freecam` na linha de comando (a corrida já abre nela), **F1** na corrida (PC) ou o botão **CÂMERA LIVRE** na
  pausa (celular e PC). Sair: **F1**, **Esc** ou o botão **SAIR**.

| PC | Celular | Faz |
| --- | --- | --- |
| W A S D | stick esquerdo | anda (frente/trás/lados, para onde a câmera olha) |
| Q / E | DESCE / SOBE | desce / sobe |
| botão direito do mouse segurado + mover | stick direito | olha em volta |
| Shift segurado | botão 4x (liga/desliga) | 4 vezes mais rápido |
| roda do mouse | — | muda a velocidade (1 a 400 m/s; começa em 20) |
| T | KM | campo "Ir para o km": `1,2` (km) ou `800 m`; leva a câmera ao centro da pista, 6 m acima, olhando o sentido da rota |
| P | FOTO | salva print em `user://shots/<rota>_km<1.234>_<objeto>_<data-hora>.png` |
| H | HUD | esconde/mostra o painel (para print limpo; no celular o botão HUD fica) |

- **Painel no canto**: FPS, chamadas de desenho, objetos visíveis, km da câmera (+ distância lateral e altura acima da pista),
  rota e hora do dia, velocidade da câmera.
- **Mira no centro**: "Sistema > objeto" (ex.: `Roadside3D > lamp_post #6`, `Roadside3D > tree_leafy #2`), o material, a
  distância e o arquivo `.glb` de origem (ou "sem .glb: feito por código" para estrada, prédios e túneis gerados no jogo).
  O `#N` é qual cópia daquele modelo (árvores/postes são desenhados em lote).
- **Onde ficam os prints**: PC `%APPDATA%\Godot\app_userdata\Kaido Bakuso\shots\` (o caminho completo sai no terminal como
  `FREECAM_SHOT:`). Celular (APK de debug): `adb exec-out run-as com.marco.kaidobakuso tar c files/shots > shots.tar`
  (ou tire o print do próprio celular).
- Código: `game/scripts/debug/` (`freecam.gd` câmera e teclas, `freecam_math.gd` contas puras, `freecam_picker.gd` mira,
  `freecam_overlay.gd` painel, `freecam_touch.gd` sticks). Na corrida: 1 linha em `race_scene_3d._process` congela tudo.

## Biblioteca de cenário (T-186)

docs/Modelos só tem 1 espécie de árvore (Gleditsia, 6 variações), 1 poste de luz (o da Ponte A) e 1 personagem (o boneco
do pacote ROAD SIGNS). Todos entraram: 6 Gleditsias + coqueiros (3), cedro, pinheiro, árvore redonda e arbusto (por
código) em bosques por bioma (`road3d/roadside_trees.gd`, desenhados por `Roadside3D` em MultiMesh com 2 LODs);
`lamp_bridge` no viaduto/serra/pontes e `lamp_post` no pedágio/litoral; pessoas (`road3d/people_kit.gd`) no pedágio, no
viaduto por cima e na abertura do duelo (motoristas com camisa na cor do caminhão); retrato do motorista na faixa do duelo
(`ui/duel_band.gd`). Custo medido: +1 a +22 chamadas, FPS no ruído (DECISOES, T-186). Capturas e folhas em
`docs/capturas_t186/`. Não validado no celular (APK novo). **T-192**: pinheiro, cedro, árvore redonda, arbusto e coqueiros refeitos
(galhos/tufos em cartões com textura, `build_foliage_t192.py`, atlas `foliage_leaves.png`), tom por árvore; pendente (Marco,
não agora): copas ralas das Gleditsias adultas e boneco-manequim do retrato.

## Chegada, trem do Marco e serrilhado (T-195)

A estrada continua ~1 km depois da chegada (só desenho) até a cidade destino: pórtico "ゴール CHEGADA", avenida com
postes, quarteirões, prédio-portal e skyline (`road3d/arrival_layout.gd`, `road3d/arrival_city.gd`; `--no-arrival` = antes).
O trem do Marco (`train_loco_b`, locomotiva azul com faixa creme) foi refeito e puxa o 1º trem de cada rota.
MSAA na média (2x) e na alta (4x), folhas com alpha-to-coverage, asfalto molhado sem pontinhos brilhantes fora do Ultra.
Prints e folhas em `docs/capturas_t195/` (`folha_chegada_day/night`, `folha_pos_chegada`, `folha_trem_do_marco`,
`folha_carro_unico`), custo em `custo_antes.txt` / `custo_depois.txt`. **Celular não medido** (MSAA 2x na média).

## Carro acidentado no trânsito (T-183)

Carro arremessado por caminhão não volta mais a andar: desliza, para torto (atravessado ou no acostamento), pisca-alerta
âmbar nas 4 pontas, fumaça leve do capô por 12 s e triângulo 9 m atrás depois de 3 s. Vira obstáculo: caminhões batem
(empurra, ele para de novo), bots e carros desviam ou freiam. Some a 300 m atrás do último caminhão. Estado no snapshot
(**protocolo 8**: gerar APK novo). Código: `sim/wreck.gd` (regras e "pegada" girada), `sim/traffic_look.gd` (o que o carro
enxerga), `sim/thrown_car.gd`, `road3d/wreck_fx.gd` + `wreck_props.gd` (visual). Decisões em `docs/DECISOES.md` (T-183).
Antes/depois: `docs/capturas_t183/` (folhas e `trace_antes.txt` / `trace_depois.txt`).
Não validado: o caso online com um carro acidentado de verdade (nas corridas do `net_test` ninguém arremessou carro; o
snapshot e a interpolação do cliente estão cobertos pelo teste `test_wreck.gd`) e o custo no celular.

## O que existe (resumo por fase)

- **Fase 0**: projeto Godot configurado (Input Map, autoloads, presets Android/Windows/Server).
- **Fase 1**: pipeline Blender. Plano A (pixel art): `blender/scripts/render_truck.py`, `render_parts.py`, cenas `scenes/tools/truck_viewer.tscn`,
  `scenes/race/race.tscn` (2D, mantido). **Plano B (3D PBR, o usado agora)**: `build_truck_3d.py` → `game/assets/vehicles/dekotora/truck/*.glb`.
- **Fase 2–3**: simulação em `game/scripts/sim/` (pista, caminhão, motor, colisão, dano por zona, trânsito, bots, Passing, vácuo,
  chegada, pagamento) + apresentação 3D `game/scripts/road3d/` (estrada em malha, cidade, cenário `.glb`, HUD, efeitos, resultado).
- **Fase 4**: 32 acessórios 3D (`docs/ACESSORIOS.md`), dados em `.tres` (`game/data/`, gerador `game/tools_dev/gen_data.gd`),
  perfil/save (`autoload/game_state.gd`), garagem 3D (peças, mecânica, reparo), menu, campanha de Kanto (3 trechos + chefe).
- **Fase 5**: 66 sons MP3 gerados via ElevenLabs (`tools/gen_audio.py`); `autoload/audio_bus.gd`, `audio/engine_audio.gd`, `audio/race_audio.gd`.
- **Fase 6**: servidor autoritativo (`net/server_main.gd` + `autoload/net.gd`), salas, snapshots, predição/interpolação (`net/client_sync.gd`),
  perfis no servidor (`net/profile_store.gd`), lobby, cliente automático de teste (`net/bot_client.gd`). Docs: `docs/MULTIPLAYER.md`, `docs/REDE_WIFI.md`, `server/README.md`.
- **Fase 7–8**: qualidade gráfica ajustável (Opções), guias `docs/TESTE_AMIGOS.md`, `docs/RELEASE_ANDROID.md`, `docs/LOJA.md`, `docs/POLITICA_PRIVACIDADE.md`, arte da loja em `docs/store/`.

## Decisões que o Claude tomou sem o Marco (confirmar!) — ver `docs/DECISOES.md`

1. **Nome**: Kaidō Bakusō — Chrome Legends (homenagem discreta a *Bakusō Dekotora Densetsu*). Alternativas: "Ichiban Kaidō", "Hoshi Bakusō".
2. **Plano B (3D real) em vez do pixel art**, em resposta a "quero muito mais qualidade nas imagens". O plano A continua no repositório.
3. **32 acessórios** (prompt do Marco) em vez de 16 peças só em sprite; valores de preço/peso/durabilidade das 18 peças extras são **propostas**.
4. Regras que o GDD não definia (1 Fama = 50 ¥; ultrapassagem = 2 Fama; vácuo +20% tração; Passing 4%/s e 35%/s; revenda 50%; reparo de motor 30.000 ¥ e direção 20.000 ¥; Fama mínima para liberar peças).
5. Rivais de Kanto com **nomes provisórios** (Trovão Rosa, Dragão de Aço, Lua Cromada, Imperador da Estrada).
6. Áudio em **MP3** (sem ffmpeg para converter) e músicas com 100 s (não 2:30) para economizar créditos; ~5 mil créditos gastos de ~80 mil.
7. **Eventos de pista (T-139)**: obras com limite de 60 km/h cobrado como **carga sacudindo nas chapas de aço** (não multa);
   1 evento fixo por rota + 45% de chance de mais um; prazo estica +3 a +8 s por evento. Ver `docs/DECISOES.md`.
8. **Batidas (T-141)**: batida lateral forte empurra o outro caminhão para a faixa vizinha (pode ir para o acostamento; leve
   demais quica de volta); carro do trânsito voa/gira acima de 3 m/s; buzina tira o carro da frente (55 m). Ver `docs/DECISOES.md`.
9. **Batida no trânsito custa velocidade (T-152)**: ônibus × 1,35 sobre a penalidade do carro (de frente 34–54%); tranco só
   na batida com o trânsito (não entre caminhões); câmbio sem redução automática depois da batida. Ver `docs/DECISOES.md`.

## PRÓXIMAS TAREFAS (para outra sessão do Claude; pedidas pelo Marco em 2026-10-18)

Contexto: o Marco baixa os modelos só com a licença **Royalty Free License (no AI)** e confere antes. Se algum modelo exigir
crédito ao autor, ele avisa quem é; todos os já usados estão em `game/assets/LICENCAS.md`. Tunnel.obj e van.abc (Downloads)
continuam fora até ele informar link/licença. Nenhuma das tarefas abaixo foi iniciada (só registradas).

1. **T-131 FEITA na T-143 (2026-10-19)**: jipe no trânsito (`car_jeep.glb`, ver T-143 abaixo). Texto original: **T-131, Jipe Suzuki no tráfego** (autorizado pelo Marco). Fonte: `docs/Modelos/Novos modelos/Carro/` (OBJ/FBX, 436 mil triângulos,
   50 texturas 4K, escala ×0,742 para ~3,95 m, "SUZUKI" na grade para apagar; ver `docs/NOVOS_MODELOS.md` e
   `docs/INVENTARIO_MODELOS.md`). Seguir o padrão da T-124: `blender/scripts/build_traffic_cars.py -- --model ...`,
   3 a 6 mil triângulos, `paint_white` trocável, rodas `wheel_f*`/`wheel_r*`, entrar em `traffic_3d.gd` (`MODELS_BY_KIND`),
   placas (T-130), crédito do autor se houver, teste e medida de FPS.
2. **T-132 RESOLVIDA (2026-10-18): o caminhão segue a faixa nas curvas.** Causa: acima da velocidade segura a curva
   empurrava o caminhão para fora (até 4× o excesso, sem limite) e o controle de faixa puxava de volta no máximo; o corpo
   era girado por `lateral_vel` (até 5,4°, apontando para dentro enquanto ele escorregava para fora = "de lado").
   Medido acelerando sem tocar (antes → depois): viaduto 9,9 m → 0,36 m de desvio; montanha 7,9 m → 0,25 m; litoral
   2,8 m → 0,19 m; corpo torto > 2° em 33%/52%/9% do tempo → 0% (máximo 0,16°). Agora (`sim/curve_grip.gd`, usado por
   `TruckSim`, portanto bots, servidor e predição do cliente): até +30% da velocidade segura o pneu raspa (perde
   velocidade, canta, desliza no máximo 0,5 m); acima de +30% perde a faixa de verdade, com aviso "CURVA! ALIVIE" ~2 s
   antes (HUD + vibração) e "DERRAPANDO!" ao escapar. O giro do corpo vem só da troca de faixa (≤ 3°, suave,
   `TruckSim.body_yaw`) em torno do eixo traseiro; a direção do corpo é a corda do eixo traseiro ao dianteiro sobre a
   linha da faixa (`TrackPath.vehicle_transform`), igual para o trânsito (`TrafficSim.body_yaw`). Nenhum `.glb` está
   girado (`tools_dev/check_glb_orientation.gd`: 24 modelos, erro 0,00°). Teste `tests/test_lane_following.gd`
   (8 testes); medidor `tools_dev/measure_lane_following.gd`; capturas `docs/direcao_arte/faixa_curva_*.png`
   (`-- --route=kanto_3_mountain --time=day --cam=top|high|side --nohud --autoplay --start=300 --start-speed=21
   --snap-every=2 --shots=PASTA`; troca de faixa: `--demo=lanes`). **Atenção:** com V8 + turbo duplo (ou 16 t de carga)
   acelerando sem soltar, o caminhão chega a +47% na curva 1,0 do viaduto e escapa (é a regra dos +30%; o aviso vem antes).
   (Original) **T-132, BUG: o caminhão anda "de lado" no asfalto.** O certo é ele seguir a pista de frente, alinhado com a direção da
   estrada (curvas incluídas), e inclinar/guinar só um pouco ao trocar de faixa. Onde olhar: `race_scene_3d.gd:591`
   (`path.vehicle_transform(z, x, t.length, -t.lateral_vel * 0.1, t.lean() * 0.11)`: o guinar vem de `lateral_vel` e o
   sinal/escala podem estar errados), `TrackPath.vehicle_transform` (a direção usa a tangente da pista no ponto do eixo
   traseiro/dianteiro? caminhões longos de 7 a 12 m podem estar usando a tangente de um ponto só), o ajuste de peso da T-113
   (`STEER_RESPONSE`, `LANE_GAIN`, `LANE_MAX_VEL`) e o `Lanes`. Também vale conferir se algum `.glb` novo (Canter, cabines
   `jac`/`americana`/`chata`) está girado em Z. Validar com captura de cima/lado em reta, curva e troca de faixa.
3. **T-133 RESOLVIDA (2026-10-18): rodas girando de verdade.** Causa: o pneu (`wheel_*`) já girava em todos os 13 modelos
   (jogador, rivais e tráfego), mas calotas e rodas da loja eram montadas nos pontos fixos `MOUNT_WHEEL_FRONT_FACE_*`
   (irmãos do pneu, não filhos) e só no eixo da frente. Agora `TruckWheels` (`game/scripts/truck/truck_wheels.gd`, usado
   pelo `TruckNode`) põe a peça de roda escolhida como **filha de cada roda externa** (frente, todos os eixos de trás, a de
   fora do rodado duplo, lado esquerdo espelhado), copiando o encaixe dos pontos FACE; ela gira e estérça junto com o pneu.
   Cada roda gira por velocidade / **raio dela** medido na malha (chata/curta 0,50, americana 0,53, JAC 0,55 na frente;
   0,52 atrás; Canter 0,45/0,43). Garagem: na vista RODAS (ou ao escolher calotas) as rodas giram devagar (1 m/s), nas
   outras vistas nada roda. Custo: peças de roda sem sombra e só até 60 m → corrida decorada ~+10 chamadas, FPS igual
   (~248 sem vsync, antes e depois). Teste `tests/test_wheels_spin.gd` (5 testes); medidor `tools_dev/measure_wheels.gd`;
   capturas `docs/direcao_arte/rodas_girando_*.png` (corrida: `-- --decorated --demo=reta --shots=PASTA --burst=5
   --cam=5.0,-9,1.3,5.0,0,0.7`; garagem: `-- --demo --noparts --parts=fumi_sport_rims --body=canter --hideui --view=wheel
   --zoom=0.4 --shot=ARQ.png --shot-pair`). Texto original da tarefa abaixo.
   (Original) **T-133, BUG: as rodas estão estáticas (não giram).** `TruckNode.animate()` gira os nós `wheel_*`
   (`game/scripts/truck/truck_node.gd:195`), então conferir: (a) se `find_children("wheel_*")` (linha ~80) acha as rodas dos
   `.glb` novos e regerados (Canter, `_jac`, `_americana`, `_curta`, `_chata`; o especialista da T-126 já avisou que as
   calotas/rodas de peça não giram); (b) se `animate()` está sendo chamado para o caminhão do jogador, rivais e tráfego
   (`race_scene_3d.gd:592`, `traffic_3d.gd`); (c) se a rotação não é sobrescrita pelo `_wheel_rest` ou pela troca de rodas
   da garagem; (d) rodas das peças (`wheels`, `hub_*`) montadas como filhos fora de `wheel_*`. Corrigir e criar teste
   (a rotação dos nós `wheel_*` muda com a velocidade, para cada modelo e cabine; rodas de peça acompanham).

4. **T-138 RESOLVIDA (2026-10-18): telas com acabamento final (E1).** Todas as telas (menu, garagem, mercado, lobby, opções,
   pausa, resultado, HUD e toque) são montadas por containers e presas às bordas: `window/stretch/aspect="expand"` (antes
   "keep" punha faixas pretas no celular 20:9). Resultado novo (`ui/result_screen.gd` + `ui/result_text.gd`): "1º LUGAR",
   "DERROTA" ou "TEMPO ESGOTADO" e frases simples (por que, carga estragada e por quê, peças, Fama). Fundo do menu em 2
   opções (`ui/menu_bg/`): A posto à noite (padrão) e B rodovia, em Opções > Gráficos. Garagem com câmera mais perto,
   cromo neutro de estúdio (`matcap_chrome_studio.png`) e botão VER EM MOVIMENTO (rodas). Teste `tests/test_i18n_keys.gd`.
   Capturas antes/depois em `docs/capturas_t138/` (960x540 e 1200x540 = layout de 2400x1080): `bash tools/ui_shots.sh 960x540 PASTA`.
   Detalhes em `docs/DECISOES.md` (2026-10-18, T-138).

Ordem sugerida: T-131 (T-132, T-133 e T-138 já resolvidas).

4. **T-136 FEITA (2026-10-18): baú premium (piloto C3) no baú médio, 4 cabines.** Versão ALTA só no Blender
   (`truck3d/box_high.py`, ~84 mil triângulos: nervuras arredondadas, juntas e rebites, portas estampadas, borracha) gravada
   (`blender/scripts/bake_box_premium.py`, Cycles, ~3–4 min) na versão LEVE do jogo (`truck3d/box_premium.py` + ferragens reais
   em `box_rear.py`): atlas compartilhado `textures/tex_box_albedo/orm/nrm.png` (1024²) e `tex_box_mural_orm/nrm.png`
   (1024×256; o mural continua o PNG trocável). Texturas de base CC0 em `blender/cc0/` (512 px, créditos em
   `game/assets/LICENCAS.md`). Regerar tudo: `source tools/env.sh && bash tools/build_box_premium.sh [--no-bake] [--src RAIZ]`
   e `godot --headless --path game --import`. `build_truck_3d.py --box auto|premium|classic` (auto = premium só no `base`).
   Medidas (viaduto à noite, modo médio, sem vsync; `bash tools/measure_box.sh`): chamadas 302 → 304, triângulos/quadro
   185 → 188 mil, textura 40,9 → 44,1 MB, vídeo ~86 MB, FPS igual (~230–280). Baú: 4,1 mil → 7,8 mil triângulos (casca 4,3 mil +
   ferragens 3,5 mil); .glb base_chata 72,6 → 77,1 mil triângulos, 2,77 → 3,05 MB. Capturas antes/depois (garagem e corrida,
   dia/noite; `bash tools/capture_box.sh PASTA [cabine] [modelo] [rapido]`): `docs/capturas_t136/` (folha
   `comparacao_antes_depois.png`). Teste `tests/test_box_premium.gd` (4). **Para estender** aos baús leve/longo: ~1 sessão
   (ligar `PREMIUM_VARIANTS`, um bake por comprimento para os rebites não esticarem, +3 PNG ≈ +1,5 MB cada; +~3,7 mil
   triângulos por caminhão); Canter: tirar a barra de lanternas do JAC ou as do baú premium (meia sessão).

## PENDENTE — precisa do Marco

- **T-197 (2026-10-22): som dos caminhões e do bonde.** Ouvir `docs/audio_t197/` (fone ou caixa; no celular o grave
  some): `antes_*.wav` × `depois_*.wav` com o mesmo roteiro (lenta 2,5 s, acelera trocando marchas até 15,5 s, solta,
  freia até parar em ~23 s, lenta). `depois_bonde_passando.wav` = bonde passando a 25 m. Dizer qual parte ainda soa
  falsa (lenta, aceleração, troca, freio-motor, escape, freio a ar, bonde). No jogo: GARAGEM > MECÂNICA > OUVIR, ou a
  cena de teste (DIRIGIR). Som antigo: `-- --engine-sound=old`. **Gerar o APK de novo** para ouvir no celular.
- **T-181 (2026-10-21): câmera livre de exploração.** No PC: `godot --path game res://scenes/race/race3d.tscn --
  --route=kanto_3_mountain --freecam`, voar com WASD + botão direito, T e digitar `1,2`, mirar num poste e apertar P.
  No celular: **gerar o APK de novo**, pausar a corrida e tocar CÂMERA LIVRE (sticks e SOBE/DESCE). Dizer se os
  comandos estão bons. Não foi testado no celular de verdade (só no PC; os sticks foram vistos na janela com `--touch`).
- **T-179 (2026-10-21): montanhas nevadas agora aparecem.** Estavam no APK, mas do avesso (escuras, "lâminas"), cortadas
  pela câmera (900 m) e apagadas pela neblina; ver `docs/DECISOES.md` (T-179). Olhar `docs/capturas_t179/` (esquerda =
  antes, direita = depois): `folha_montanha_dia`, `folha_litoral_tarde`, `folha_cidade_noite`. **Gerar o APK de novo**
  (protocolo de rede igual) e jogar o 1º frete (litoral): montanhas com neve atrás dos prédios, à esquerda; a corrida
  rápida (cidade à noite): cordilheira azulada com neve acima dos prédios. Dizer se a quantidade/tamanho está bom.
  O `builds/dekotora.exe` (PC) é de 17/10: **não tem nada da T-169**; para o PC use o Godot ou exporte de novo.
- **T-169 (2026-10-21): modelos de `docs/Modelos` aplicados (+ T-163 e T-164).** Olhar `docs/capturas_t169/` (folhas `folha_*.png`: esquerda = antes, direita = depois) e dizer: (1) se gosta das **montanhas nevadas** no horizonte (quantidade, altura; neve cheia na montanha, só nos picos no litoral/cidade); (2) da **árvore de folhas** (cidade, 25% da montanha, 20% do litoral do lado da terra); (3) do **viaduto rodoviário por cima** (cidade 2.050 m, montanha 2.580 m) e dos **semáforos de faixa** nos túneis (X vermelho quando um evento fecha a faixa à frente; quer também a seta amarela?); (4) do mar com as ondas novas, dos postes com fios, do guard-rail em W e do pilar em T. Como testar no PC: `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_3_mountain --start=2400` (montanhas, postes, viaduto) e `--route=kanto_2_viaduct --start=950` (túnel com semáforos). **Gerar o APK de novo** para ver no celular (nenhuma mudança de protocolo de rede).
- **T-171 (garagem: prévia antes de comprar + pneu sobre o chão):** gerar o APK de novo e, na GARAGEM > DECORAÇÃO, tocar
  num encaixe (ex.: Para-choque frontal) e depois num cartão de peça que você não tem: a peça aparece no caminhão, a
  câmera vai até ela e no alto do painel da direita aparece **PRÉVIA** com COMPRAR E EQUIPAR / VOLTAR AO ATUAL (o
  dinheiro não muda). Arrastar a lista por cima dos cartões deve continuar rolando sem ativar a prévia. No PC: clique no
  cartão, ou Tab/setas até ele e Enter (Esc volta). Cores com "F30/F60" agora podem ser tocadas só para ver. Olhar
  `docs/capturas_t171/folha_previa.png` e `zoom_*.png` (esquerda = antes, pneu cortado; direita = depois). Dizer se o
  botão deve **comprar e já equipar** (como está) ou só comprar.

- **T-165 (2026-10-20): listas do menu/garagem rolam arrastando o dedo sobre os cartões (`TouchScroll`).** Falta o Marco confirmar no
  celular com **APK novo** (garagem > MODELO: arrastar sobre um cartão rola sem selecionar; toque rápido seleciona; repetir em Mercado e
  Opções). Se a rolagem demorar ou toques virarem rolagem, ajustar `DEADZONE` em `game/scripts/ui/components/touch_scroll.gd`.
- **T-177 (2026-10-21): rolagem refeita (PC e celular) e DECORAÇÃO com seções.** A lista não segue mais o mouse sem botão; roda do mouse
  rola; arrastar com botão/dedo rola até o fim; toque parado seleciona. DECORAÇÃO: barra fixa PEÇAS / PINTURA / LUZES / ADESIVOS e encaixes
  em 2 colunas por lugar do caminhão. Falta o Marco confirmar no PC e no celular (APK novo).
- **T-170 (som da seta):** jogar e tocar em < ou > (teclado A/D ou setas): deve ouvir o clique da alavanca e o
  tique-taque enquanto a seta pisca (agora mais devagar, ~1,5 vez por segundo, e acende na hora do toque). Ouvir
  `game/assets/audio/sfx/truck/turn_signal_tick.mp3` e `turn_signal_switch.mp3` (regerar: `python tools/gen_audio.py
  --only turn_signal_tick --force`). **Decidir:** quer também um pisca manual (liga e fica ligado até desligar, com
  botões/teclas próprios, ex. Q/E) ou o da troca de faixa basta? **Gerar o APK de novo** para ouvir no celular.
- **T-173 (som do motor por escapamento, turbina e buzinas):** abrir `godot --path game res://scenes/tools/engine_audio_test.tscn`,
  escolher o **Escapamento** (Reto rouco, Chaminés V8, Cromado estalos), ligar "Acelerar automático" e trocar a **Turbina**;
  tocar as 3 buzinas marcadas "(nova)". Dizer quais dos **15 sons de motor/turbo** e das **3 buzinas** regerar
  (`python tools/gen_audio.py --only nome --force`). No jogo: GARAGEM > MECÂNICA (botão OUVIR nos motores/turbos/escapes;
  seção BUZINA no fim). Confirmar os 2 escapes novos e os preços (BALANCEAMENTO), buzina grátis, e se as chaminés devem
  montar a peça visual `kw_exhaust_stacks`. **Gerar o APK de novo** (protocolo de rede 7).
- **T-172 (peças deluxe, amostras de acabamento):** olhar `docs/capturas_t172/` (`antes_depois_garagem_noite.png`
  primeiro; esquerda = peças antigas, direita = deluxe) e `game/assets/vehicles/dekotora/previews/deluxe_contact_sheet.png`
  (cada peça de dia, de noite e de perto) e dizer: (1) se o nível de detalhe está bom e se seguimos para mais peças;
  (2) se "estura" era estrutura lateral/estribo (foi o que fizemos) ou outra coisa; (3) se o andon 一番星 sobre a cabine
  é o "baú em cima da cabine" que você queria (tamanho/altura); (4) preços propostos em `docs/BALANCEAMENTO.md`.
  Abrir no PC: `godot --path game res://scenes/tools/accessory_viewer.tscn -- --cat=deluxe` ([N] acende/apaga).

- **T-159 (análise de `docs/Modelos/Road_pontes`, nada no jogo ainda):** ler `docs/ANALISE_ROAD_PONTES.md` e as folhas
  em `docs/capturas_t159/`; ~~confirmar a licença do **túnel** (o mesmo `Tunnel.obj` da T-130) e dos outros~~ (licença LIBERADA pelo Marco em 2026-10-20, T-166); dizer se quer
  os postes de energia com fios e o viaduto cruzando por cima da pista; o semáforo de faixa do túnel deve acompanhar os
  eventos? Atenção: as pastas de terceiros agora estão em `docs/Modelos/`; os scripts de geração já procuram lá
  (`docs/Modelos/Modelos Melhorados`, `docs/Modelos/Novas Melhorias`, `docs/Modelos/Novos modelos`) e voltam para as pastas antigas se a nova não existir (T-162).

- **T-156 (abertura frente a frente, campanha 1 contra 1):** jogar um frete e ver a cena (um toque pula); olhar
  `docs/capturas_t156/` (`dia` = praça de pedágio, `noite`/`tarde` = área de descanso, `curta` = revanche, `comboio` =
  4 caminhões) e dizer: (1) se gosta do cenário, da faixa, das falas (texto em `game/data/i18n/pt-BR.json`,
  `rival.*.taunt` e `intro.player_line.*`) e dos nomes dos caminhões dos rivais (Sakura-maru, Tetsuryū-maru,
  Gekkō-maru, Kaidō-Ō); (2) não existe retrato de motorista: a faixa usa um brasão com kanji (dá para trocar por
  retratos se você mandar); (3) **o rival ficou um pouco mais forte** no 1 contra 1 (tabela em `docs/BALANCEAMENTO.md`):
  jogar e dizer se precisa aliviar; (4) a corrida rápida continua com 4 caminhões (manter?); (5) ouvir
  `game/assets/audio/sfx/ui/vs_taiko_hit.mp3`. **Gerar o APK de novo** (protocolo de rede 6).

- **T-155 (acabamento F4):** olhar `docs/capturas_t155/` (folhas `item1_*`, `item2_ficha`, `item3_*`; esquerda = antes,
  direita = depois) e dizer se o mural à noite está na força certa (noite 0,8; dá para subir/descer em
  `game/data/time/*.tres`, campo `mural_glow`), se a ficha compacta ficou boa e se os muros listrados das bocas estão no
  tamanho certo. **Gerar o APK de novo** para ver o mural aceso no celular.

- **T-141 + T-144 (batidas, freada, buzina):** jogar e dizer se a força está boa (empurrão de faixa, inclusive para o
  acostamento; carro voando; ônibus só empurrado), se a fumaça/faíscas/pedaços estão no tamanho certo (`docs/capturas_t141/`) e
  **ouvir** os 4 sons novos (`truck_body_slam`, `truck_side_bang`, `chrome_debris_scatter`, `car_tumble` em
  `game/assets/audio/sfx/crash/`). Decidir se os bots também buzinam. ~~Gerar o APK de novo (protocolo 3)~~ FEITO em 2026-10-19: `builds/kaido-bakuso-debug.apk`, 105 MB (antes 88 MB), chave de debug; falta instalar no celular.

- **T-152 (batida no trânsito custa velocidade):** jogar e dizer se a perda está boa (de frente 25–40%, raspão 8–15%,
  ônibus mais; olhar `docs/capturas_t152/folha_sequencia_carro.png`). Uma batida de frente forte custa ~10 s numa reta
  porque o câmbio fica na 6ª; decidir se o câmbio deve reduzir sozinho depois da batida (~7,5 s) e se o tranco vale também
  entre caminhões. **Gerar o APK de novo** (protocolo de rede 4).

- **T-153 (trechos com 2 faixas):** olhar `docs/capturas_t153/` e jogar os 3 trechos; confirmar as posições (ponte do
  litoral no fim da rota, viaduto antigo logo depois do acidente, túnel antigo nas curvas do começo da montanha), a
  lombada nova do litoral (para a ponte ficar alta), o nome fictício 湯坂隧道 e se o trecho deve esticar o prazo (hoje não:
  os bots perdem 1 a 3 s). **Gerar o APK de novo** (protocolo de rede 5).
- **T-154 (ferrovia):** olhar `docs/capturas_t154/` (`antes_depois.png` primeiro) e dizer: (1) se gosta do amarelo do bonde
  `kaohsiung_circular_light_rail_caf_urbos_3` (a licença Sketchfab Standard está LIBERADA pelo Marco em 2026-10-20, T-166); (2) se os
  lugares das linhas e dos 2 viadutos de trem estão bons; (3) a frequência (1º trem ~10 s, depois a cada 22–40 s); (4) se quer
  som de trem (2 sons no ElevenLabs, ainda não gerados). Se você baixou um pacote de ferrovia, ele não está no PC: coloque em
  `docs/Modelos/Novas Melhorias/` e avise.

- **T-146 (barreiras, placas, outdoors):** olhar `docs/capturas_t146/` (`antes_depois_dia.png` primeiro) e dizer se aprova os
  outdoors (quantidade, lugar, as 4 artes fictícias; troque por artes suas em `game/assets/scenery/billboards/ad_0N.png`), as
  barreiras listradas nas obras/bocas de túnel e os pórticos de treliça. A mureta contínua continua a feita por código (o pacote
  "Metais" é de barreiras de obra, não de guard-rail).

- **T-139 (eventos de pista):** confirmar a regra das obras (60 km/h; passar rápido na chapa de aço custa carga; alternativas: multa em ¥ ou só visual), a chance de 45% de um evento extra por corrida, as posições dos eventos fixos e se quer viatura de polícia no acidente. **Gerar o APK de novo** (o protocolo de rede passou para a versão 2). Autorizar o gasto no ElevenLabs para os 5 sons novos (`python tools/gen_audio.py --only cone_hit,barrier_scrape,steel_plate_clank,event_alert_chime,roadworks_loop`).

- **T-138:** escolher o fundo padrão da tela inicial (A posto à noite, B rodovia; compare `docs/capturas_t138/depois_960x540/menu.png`
  e `menu_fundo_b.png`) e dizer se a câmera da garagem ficou perto o bastante.

- **T-136:** olhar `docs/capturas_t136/comparacao_antes_depois.png` e dizer se o baú premium fica (e se vale estender aos baús leve/longo e ao Canter); conferir a chapa ondulada no celular (APK).
- **T-130:** a licença de `Tunnel.obj` e `van.abc` está LIBERADA pelo Marco em 2026-10-20 (T-166). Mas os dois arquivos
  não estão mais no PC (pasta Downloads vazia): para usá-los, recoloque-os em `docs/Modelos/` e avise. Sem isso ficam fora do jogo. Olhar
  `docs/capturas_t130/` e dizer se as placas/sinais estão no tamanho certo.
- ~~Instalar Android SDK + JDK 17~~ FEITO (ver "Ambiente" no topo; o APK de teste já sai). Falta **instalar e testar o APK no
  celular** (P02, P22, P65, P70, P72): o Android ainda não foi testado num aparelho.
- **Olhar** as imagens (previews em `game/assets/vehicles/dekotora/previews/`, capturas em `docs/store/`) e **aprovar o visual** / escolher plano A ou B.
- **Ouvir** os áudios e pedir regeração dos ruins: `python tools/gen_audio.py --only nome --force` (lista: `python tools/gen_audio.py --list`).
- Jogar e ajustar equilíbrio (0–100 do caminhão padrão é 22 s; V8+turbo duplo 14 s; ver `docs/BALANCEAMENTO.md`).
- ~~GitHub~~ FEITO: `origin` = https://github.com/marcoaluz/dekotora-legends.git (push em 2026-10-16).
- **Arte do caminhão — 1ª rodada FEITA (2026-10-16)**: cabine arredondada (loft), grade/faróis/para-choque, chassi, tanques, eixos, rodas com pneu de sulcos, baú corrugado (código em `blender/scripts/truck3d/`). 2ª rodada feita: porta com contorno, para-lama, carenagem de teto, espelhos, vidros, para-choques com painéis coloridos, garagem com caminhão centralizado (painel direito some quando vazio), câmera da corrida mais alta/atrás. 3ª rodada (2026-10-16, referências em `docs/Textura/`): pneu com sulcos em V (geometria), baú de tábuas com montantes, grade e respiros de chapa perfurada e degraus de chapa xadrez (texturas procedurais em `lib/tex.py`, UV planar), vinco de cintura e juntas de painel; **4 modelos de baú** (`--variant base|leve|longo|carreta`, código em `truck3d/variants.py`: esticam/encolhem o meio do caminhão): baú leve 5,4 m (1 eixo), baú médio 8,2 m, baú longo 9,8 m (3 eixos) e carreta (cavalo + semirreboque ~17 m); escolhidos na garagem ("Modelo do caminhão", `profile.body`; rivais alternam base/leve/longo). Tanque e carroceria aberta foram descartados (Marco quer só baú). **Carreta guardada** (modelo pronto em `dekotora_truck_carreta.glb`, fora da lista da garagem por pedido do Marco). 4ª rodada (2026-10-16): **4 cabines** (**retiradas na T-129**, ver abaixo) (`--cab padrao|classica|aero|alta`, `truck3d/cab.py`) combináveis com os 3 baús = 12 `.glb` (`dekotora_truck_<baú>[_<cabine>].glb`; gerar todos: `for v in base leve longo; for c in padrao classica aero alta: build_truck_3d.py -- --variant $v --cab $c --no-preview`), escolha na garagem (`profile.cab`); textura de sujeira discreta na pintura (`paint_white_panel`) e chapas perfuradas; **UI nova**: tema moderno (`ui_theme.gd`: sliders, interruptores, botões de menu), tela de Opções com categorias e rolagem (`options_panel.gd`, corrigido o corte da tela), menu principal redesenhado; ambiente em hora azul/entardecer com tom menos saturado. **UI premium (referências em `docs/Ult/`)**: etapa B feita (fonte Rajdhani + ícones Lucide em `assets/ui/icons`, licenças em `assets/LICENCAS.md`; componentes em `scripts/ui/components/ui_kit.gd`; transição `SceneFader`); etapa C feita (tela inicial: Continuar = próximo frete liberado, Nova carreira com confirmação, Mercado de fretes = `freight_market.gd` com dados reais das rotas; visão só por fora do caminhão, sem cabine interna). Etapa D feita: galpão industrial 3D (`blender/scripts/build_garage_env.py` → `assets/scenery/garage_hall.glb`, ~20 mil triângulos) usado na garagem e na tela inicial, luz de estúdio (`garage_stage._studio_lights`), garagem com abas MODELO/PEÇAS/MECÂNICA/REPARO, ficha técnica só com dados reais (`garage_info_panel.gd`), cartões em `garage_shop.gd`, botões de vista e zoom na roda do mouse. Etapa E feita: HUD com fontes da identidade e textos com acento via i18n (POSIÇÃO, DESTINO com marcadores de todos, CARGA com % e diagrama de dano, velocidade/marcha/RPM com faixa vermelha, turbo/Passing, chip VÁCUO), botões de toque em vidro escuro com setas desenhadas, pausa em blocos (Continuar, Configurações, Sair para o menu, Sair do jogo; teclado/controle com foco). Combustível não existe na simulação (não entrou). Etapa F (1ª passada): texturas repetíveis de asfalto/rugosidade/grama/areia (`blender/scripts/build_road_textures.py` → `assets/textures/`), estrada com mureta New Jersey além do limite físico da sim (13 m), litoral com guard-rail, praia descendo até o mar animado, palmeiras/arbustos/pedras (`build_scenery_3d.py -- --only palm,rock,bush`), skyline do outro lado da baía; prédios com cor própria, recuo no topo, luz de aviação piscando e letreiros de neon; **corrigido**: objetos de beira de estrada sumiam depois dos primeiros ~450 m (MultiMesh único cortado por distância → agora um bloco por trecho de 150 m). Medido no PC (litoral, `--fps-log`): ~75 FPS (limitado pelo monitor), mas 800–1050 chamadas de desenho e 0,6–0,9 milhão de triângulos por quadro — pesado para celular; otimizar na etapa H (LOD dos caminhões, sombras). Etapa G feita: contratos (origem/destino, carga, peso, valor, capacidade do baú, fragilidade; `scripts/data/contracts.gd`, `data/cargo/`, testes em `tests/test_contracts.gd`); a ficha técnica mostra a capacidade de carga. **Corrigido**: os testes gravavam no perfil real do jogador (`user://profile.json`); agora usam `user://test_profile.json`. Etapa H feita: medição por qualidade (`--fps-log --quality=N` imprime superfícies por parte da cena e média de FPS): baixa ~295 chamadas/~150 mil triângulos; **média (padrão do celular) ~330 chamadas/~125–160 mil triângulos**; alta caiu de ~1.050 para ~570–660 chamadas com sombra em 2 cortes. Testes (90), todas as cenas abrem sem erro e o build Windows exporta e inicia. Falta medir no celular de verdade (APK). Próximas: F mapas, G contratos (precisa de dados novos: origem/destino/carga). Hoje a troca é só visual: **o hitbox da simulação (`Collision.LEN` = 12 m) e as estatísticas ainda são iguais para todos** — falta decidir massa/aceleração/tamanho por modelo. Falta: levar o mesmo nível de detalhe às outras ~28 peças (grade, visor, saias, murais) e conferir o cromo no celular.
- **Arte do caminhão (pedido original do Marco)**: visual 3D aprovado em geral; refinar o modelo para ficar mais próximo de um caminhão real (portas, cabine, chassi, rodas, detalhes), seguindo `docs/dekotora_volvo_3d_references/` (Volvo FH + dekotora). O caminhão é o coração do jogo: investir em detalhe.
  **5ª rodada FEITA (T-106, 2026-10-17): cabine realista + texturas por código** (os módulos `cab*.py` de cabine foram apagados na T-129). Cabine dividida em módulos:
  `truck3d/cab.py` (estilos + casca com recorte do arco da roda), `cab_surface.py` (superfície e "adesivos" 3D que seguem a curva:
  `patch`, `ribbon`), `cab_front.py` (para-brisa envolvente, limpadores, caixa de ar, grade alta + colmeia, faróis que dobram o canto,
  para-choque varrido), `cab_doors.py` (porta, janela, maçaneta, fechadura, pega-mão, espelhos, degraus, para-lama, protetor de lama),
  `cab_roof.py` (defletor por loft, escotilha, lanternas, quebra-sol da clássica). Texturas em `lib/tex_truck.py` (pintura suja por
  altura + normal, plástico com poeira, para-brisa com arcos do limpador, colmeia, fendas, chapa xadrez, pneu); materiais em
  `pbr.truck_set()`. Triângulos: base 61,7 mil → 64,3 mil; leve 49,4 → 51,9 mil; longo 74,2 → 76,8 mil. Textura por .glb 0,06 → ~1,2–1,5 MB
  (12 .glb + carreta = 18 MB; arquivos .glb 27 → ~51 MB). Gerar os 12 leva ~75 s. Folha de conferência: sem `--no-preview` o build grava
  `previews/truck_<tag>_sheet.png` (9 vistas). Capturas no jogo: `godot --path game res://scenes/garage/garage.tscn -- --demo --noparts
  --hideui --cab=jac --view=front --zoom=0.55 --shot=C:/caminho/x.png`. Imagens: `docs/direcao_arte/cabine_realista_*.png`.
  **Texturas compartilhadas (T-118, 2026-10-18):** as texturas grandes do caminhão ficam UMA vez em
  `game/assets/vehicles/dekotora/textures/tex_*.png` (gravadas pelo `build_truck_3d.py` via `lib/shared_tex.py`); cada .glb leva só
  miniaturas 4×4 com a cor média (abre sozinho, só fica liso). `TruckTextures.apply()` (`scripts/truck/truck_textures.gd`, chamado pelo
  `TruckNode` depois do cromo e do mural, e pelo visualizador de acessórios) troca as miniaturas pelas compartilhadas, um material em
  cache por nome. Medido: .glb 51 → 33 MB; texturas no projeto 18,5 MB (12 cópias) → 1,5 MB (uma) + 0,36 MB de miniaturas; .pck de
  teste (Windows) 97,5 → 54,0 MB; corrida no modo médio: memória de textura 53 → 43 MB, vídeo 87 → 77 MB, chamadas iguais (~490),
  FPS igual. Garagem antes/depois praticamente idêntica (diferença média de pixel 0,0008). O mural continua embutido (o TruckNode troca).
  Pendências: (3) sem interior (bancos/painel) atrás do vidro escuro; (4) flocos metálicos e reflexo real no vidro dependem de luz do
  jogo, não da textura. (Os PNGs antigos foram apagados na T-117.)
- **T-125 (2026-10-18): caminhão base Canter + 6ª cabine "curta"** a partir do JAC 1045 (Royalty Free; emblema apagado; créditos em
  `game/assets/LICENCAS.md`). Código: `blender/scripts/truck3d/jac_src.py` (importa o .blend de `docs/Modelos/Modelos Melhorados/`, que fica fora
  do Git), `jac_parts.py` (material/teto de triângulos por peça, pelo nome), `jac_cab.py` (cabine + montagens), `canter.py` (baú 2,3 x 5 m,
  rodas, decoração); `body.py`/`deco.py` aceitam medidas de baú (`BoxDims`). Modelos: `dekotora_truck_canter.glb` (48 mil tri) e
  `dekotora_truck_{base,leve,longo}_curta.glb` (61/49/73 mil; o baú cresce 1,22 m para a frente). No jogo: `BodyDef` (`data/bodies/`)
  dá massa, capacidade, comprimento na pista, agilidade e torque por modelo (Canter 3,5 t, 4 t de carga, 7 m, torque ×0,55);
  `TruckSim.length` substitui o `Collision.LEN` fixo na colisão/vácuo/bots; garagem lista o Canter (cabine fixa) e a cabine curta;
  câmera da corrida chega mais perto do Canter. Corrida (modo médio, litoral) ~75 FPS, ~340 chamadas (base ~380). Capturas em
  `docs/capturas_t125/`; depuração da garagem: `-- --demo --body=canter [--cab=curta]`.
- **T-126 (2026-10-18): 10 peças novas tiradas dos modelos de terceiros** (Kenworth W990, Fumi SC, JAC 1045; lista e custo em
  `docs/ACESSORIOS.md`, números em `docs/BALANCEAMENTO.md`, créditos em `game/assets/LICENCAS.md`). Código: `blender/scripts/lib/extract.py`
  (ilhas por caixa, redução por ilha, corte), `accessories/thirdparty.py` (`build_accessories.py -- --thirdparty`). Encaixes novos
  `exhaust_stacks` e `roof_wing`; ponto `MOUNT_STACK_R/L` criado pelo `TruckNode.add_extra_mounts`. Capturas `docs/capturas_t126/`;
  depuração: garagem `-- --demo --noparts --parts=kw_bumper,fumi_wing [--body=canter] [--cab=curta]`, corrida `-- --decorated --parts=...`.
- **T-129 (2026-10-18): cabines só de modelos de arquivo.** As 4 cabines por código (padrão, clássica, aero, teto alto) saíram
  (scripts `truck3d/cab.py`, `cab_surface.py`, `cab_front.py`, `cab_doors.py`, `cab_roof.py` e os 12 `.glb` sem sufixo/`_classica`/`_aero`/`_alta`
  apagados). Cabines agora: **chata** (CF500, padrão), **jac** "Japonesa alta" (JAC 1045 escala 0,95 x 0,88, teto 2,95 m, escapamentos atrás;
  `jac_src.JAC`), **curta** (JAC 0,84) e **americana** (Kenworth W990: cabine "dia" + capô + grade, 183 mil → 18,6 mil triângulos, fundo e emblema
  nossos, eixo dianteiro em 10,66; `truck3d/kw_src.py` + `kw_cab.py`). Modelos: `dekotora_truck_<baú>_<cabine>.glb` (12) + Canter + carreta
  (agora com a chata). Gerar todos: `source tools/env.sh && bash tools/build_all_trucks.sh` (~3 min; `--preview` grava as folhas).
  Jogo: `CabCatalog` (`scripts/data/cab_catalog.gd`: ids, padrão, `normalize`/`LEGACY`), `GameState.migrate_profile()` (perfil local e do
  servidor), descritor de rede com `"cab"` (antes a corrida online mostrava sempre a cabine padrão), `TruckNode.CAB_FRONT_DELTA` (frente da jac e
  da americana). Teste `tests/test_cabs_t129.gd`. Capturas em `docs/capturas_t129/`.
- **T-130 (2026-10-18): inventário dos modelos + placas de veículo + sinalização japonesa.** Inventário em `docs/INVENTARIO_MODELOS.md`
  (Tunnel.obj = túnel de 2 faixas com semáforos de faixa; van.abc = caminhão aberto de 3 eixos, não uma van; os dois **sem licença,
  fora do projeto**). Placas: `scripts/vehicle/` (`PlateCatalog` textos e atlas, `LicensePlates` MultiMesh que segue os veículos,
  `PlateSpot`/`TruckPlateSpots` acham a lataria por raios em TriangleMesh de uma cópia da malha), `Traffic3D.PLATE_Y` (altura por modelo).
  Sinalização: `road3d/road_signs.gd` (`RoadSigns`), `road3d/sign_atlas.gd` (mapa do atlas), `road3d/atlas_quads.gd` (quads com atlas).
  Atlas gerados por `godot --path game -s res://tools_dev/make_sign_atlases.gd` (precisa de janela). Medido (modo médio, `--fps-log`,
  6 amostras de 5 s): litoral 280 → 283 chamadas, viaduto 295 → 298, Hakone 286 → 289; triângulos +0,2 a +2,6 mil; textura +0,9 MB
  (atlas comprimidos com mipmaps); FPS igual (75). Capturas em `docs/capturas_t130/`. Depuração nova da corrida: `--snap-every=S`
  (com `--shots=`) e `--cam=DZ,LAT,H,LDZ,LLAT,LH` (câmera fixa relativa ao jogador); `--fps-log` imprime `SINALIZACAO:`.
- **T-141 + T-144 (2026-10-19): impacto das batidas, freada forte e buzina.** Simulação: `sim/collision.gd` (empurrão de faixa,
  arremesso), `sim/thrown_car.gd` (carro fora de controle), `sim/hard_brake.gd`, `TruckSim.horn/hard_braking/shove_t`, `TrafficSim`
  (buzina abre caminho, `throw_car`). Rede: comando com `horn`, snapshot com bits buzina/freada/empurrado e giro/altura de cada
  carro (protocolo 3). Visual: `road3d/impact_fx.gd` (faíscas presas ao caminhão, clarão, pedaços num MultiMesh, chacoalhada,
  tremor), `road3d/brake_fx.gd` (fumaça e marcas), `Traffic3D` (pulo e rolagem do carro). Som: `audio/truck_sfx.gd` (buzina
  segurada, chiado, "pssh"), `audio/race_audio.gd` (camadas e distância). HUD: ícones buzina/freada; botão BUZINA; tecla H.
  Chave "Faíscas, pedaços e fumaça dos pneus" em Opções > Gráficos. Medido (modo médio, litoral, sem vsync limitado a 75):
  corrida normal sem diferença (314–318 chamadas com e sem os efeitos); na batida o máximo do período sobe 336 → 342; na freada
  328 → 334; FPS igual (75). Testes `tests/test_impacts.gd` (15). Capturas `docs/capturas_t141/`.

- **T-152 (2026-10-19): batida no trânsito custa velocidade (F1).** Simulação: `sim/collision.gd` (`penalty_fraction`,
  constantes `PEN_*` e `JOLT_TIME`): de frente 25–40% pela força, raspão 8–15%, ônibus × 1,35; o caminhão fica com o menor
  entre a física e a penalidade; `TruckSim.jolt_t/jolt_side/jolts` (tranco de 0,6 s: acelerador sem efeito, freio funciona;
  uma penalidade por batida). Evento `traffic` ganhou `penalty`, `speed_before`, `speed_after`. Rede: tranco no snapshot em
  ticks (protocolo 4); `ClientSync` suaviza o recuo do snapshot da batida (até 6 m). Visual: `ImpactFx` balança o caminhão
  (arfagem/rolagem) e a câmera; velocímetro vermelho no tranco. Testes `tests/test_traffic_penalty.gd` (11). Bots: −1,2 a
  +2,5 s na chegada (tabela em `docs/BALANCEAMENTO.md`). `net_test` (0 ms e 150 ms + 2%) passa; `bot_client` imprime
  `PRED:` (erro de predição máximo/médio). Capturas `docs/capturas_t152/`.
- **T-153 (2026-10-19): trechos com 2 faixas de verdade (F2).** Dados `RouteDef.lane_sections` (+ `RouteDef.bridges`,
  visual); simulação `sim/lane_sections.gd` + `TrackEvents.Kind.SECTION` (a faixa da direita acaba; muretas que entram,
  `EventContact` empurra e obriga a entrar na fila; `Track.events` sempre recebe os trechos, `Track.lanes_at(z)`). Rede:
  `lane_sections` no setup (protocolo 5). Visual: `road3d/road_mesh_narrow.gd` (asfalto, linhas, zebrado, muretas,
  ponte e viaduto antigo no MESMO perfil da sim), `section_props.gd` (placas no lote dos eventos; atlas `event_atlas.png`
  512x704 com 2 artes novas), `section_structures_3d.gd` (pilares, longarinas, cabeceiras da ponte), `Tunnel3D` (túnel
  antigo: arco estreito, concreto escuro, lâmpadas nas paredes, boca de pedra com 湯坂隧道), filtros em
  `RoadFurniture`/`RoadSigns`/`KitProps3D`/`Roadside3D`/`EventProps`. HUD "PISTA COM 2 FAIXAS". Trechos: litoral
  2.400–2.760 m (ponte; lombada nova de 3%), viaduto 2.270–2.510 m, montanha 780–1.060 m (túnel 805–1.040). Testes
  `tests/test_lane_sections.gd` (9). Custo: chamadas iguais (±5), FPS no ruído. Capturas `docs/capturas_t153/`.
- **T-146 (2026-10-19): modelos de `docs/Modelos/Novas Melhorias` (Metais, Placas, Placão) no jogo** (Royalty Free, no AI; inventário
  em `docs/INVENTARIO_MODELOS.md`, créditos em `game/assets/LICENCAS.md`). Gerador: `blender/scripts/build_roadside_kit.py`
  (14 .glb em `assets/scenery/kit/`, 60–280 triângulos cada, só geometria + UV; texturas `assets/textures/kit/` 1024/512 px
  comprimidas na VRAM; determinístico, conferido 2x). Jogo: `road3d/roadside_kit.gd` (materiais pelo nome, malhas em cache,
  formatos das chapas, artes), `road3d/mesh_batch.gd` (junta peças por bloco de pista e material), `road3d/kit_props_3d.gd`
  (outdoors + muros das bocas de túnel); `RoadSigns` (chapas e postes do pacote), `RoadFurniture` (pórtico de treliça),
  `EventProps`/`TrackEvents3D` (barreiras listradas nas obras, cavaletes e destroços no acidente, muro no estreitamento),
  `RoadMesh` (vidro com moldura na barreira de som), `GlbMesh` (agora mantém as tangentes: mapa de normais). `--no-kit` volta ao
  visual antigo. Medido (modo médio, sem vsync, `--fps-log`): mesmo quadro parado em 640 m com/sem kit (`measure_roadside_spot.sh`)
  litoral 425 → 428 chamadas, viaduto 459 → 461, montanha 466 → 470; triângulos +0,2 a +5 mil; textura 42,8 → 46,0 MB (+3,2),
  vídeo +1,5 a +4 MB; FPS no ruído (258–291). Andando (`measure_roadside.sh`, 300 → 550 m): litoral ~283 → ~297, viaduto ~305 →
  ~308, montanha ~298 → ~300 (o sorteio de eventos e o trânsito variam entre execuções). Testes `tests/test_roadside_kit.gd` (5).
  Capturas `docs/capturas_t146/`. Pendências: aprovar visual/artes; medir no celular (APK).
- **T-156 (2026-10-20): abertura "frente a frente" e campanha 1 contra 1 (G1).** Campanha = jogador × rival da rota
  (`StartGrid`, `race_scene_3d._spawn_field`); corrida rápida 4; online 2–4 com comboio (3–4 = trânsito mais leve).
  Abertura só visual: `road3d/duel_plan.gd` (tempos, versão, relógio online), `duel_intro.gd` (controle, pular, sons,
  luzes), `duel_stage.gd` (área de descanso / praça de pedágio a 400 m abaixo do mundo, caixas juntas por material),
  `duel_shots.gd` (câmeras e alinhamento), `duel_cards.gd` (dados da faixa), `ui/duel_band.gd` (faixa, VS, letreiro).
  Os caminhões de verdade da corrida vão ao cenário e voltam. Grid lado a lado a 30 m da pista; rival sem duelo nos 8 s
  iniciais e sem prender no acostamento (`BotDriver`). Online: protocolo 6, servidor espera a abertura
  (`countdown_total`) e todos tocam pelo mesmo relógio; `net_test` imprime `LARGADA:` (os dois clientes previram a
  largada com 4 ms de diferença entre si; o servidor largou ~40 ms antes da previsão e o aviso RACING acerta). Som:
  `vs_taiko_hit` (novo), motor acelerando = camadas do motor, buzina = `horn_musical_1`. Custo (modo médio, sem vsync,
  `tools/measure_t156.sh`): na abertura 89–238 chamadas (pico 286) e 53–151 mil triângulos, contra ~450–500 chamadas e
  ~240 mil na corrida; FPS 380–500 na cena (corrida ~250–300); textura +0,2 a +3 MB na cena e +~5 MB na corrida
  depois dela (cache das letras japonesas). Corrigido no caminho: o VS mudava o tamanho da fonte a cada quadro e
  criava +58 MB de textura. Testes `tests/test_duel_intro.gd` (8) e `tests/test_duel_scene_flow.gd` (2, montam a
  corrida de verdade; `run_tests.gd` agora roda arquivos com `const IN_TREE := true` no 1º quadro). Capturas
  `docs/capturas_t156/`.
- **T-155 (2026-10-19): acabamento visual (F4).** (1) **Mural aceso à noite**: o material do mural (baú e tampas da
  graneleira) ganhou emissão com a própria arte, mais clara perto da saia de LED e da fileira do teto (`truck/mural_glow.gd`,
  textura 512x128 feita uma vez e compartilhada); força pela hora do dia `TimeOfDay.mural_glow` (noite 0,8, fim de tarde
  0,4, dia 0) e 0,75 dentro de túnel; garagem e menu não mudam. A lona preta da graneleira continua escura (é lona).
  (2) **Ficha técnica da garagem** cabe inteira em 960x540 e 2400x1080 (linhas compactas `UiKit.stat_line`; o aviso de
  potência/tanque virou dica do título). (3) **Carro batido** (`lib/traffic_wreck.py`): rodas redondas nossas no lugar do
  pneu esculpido (estrela), lascas abaixo da soleira cortadas, alisamento 8. **Túneis**: corrigida regressão da T-153 —
  o perfil do arco começava no topo, então uma chapa inclinada atravessava o túnel, as **bocas ficavam fechadas** e as
  lâmpadas do túnel antigo iam para o meio da pista; agora bocas abertas, **muros listrados** maiores (4 peças de 1,3 a
  2,3 m na frente da mureta), túnel antigo um pouco mais claro com lâmpadas nas paredes e poças de luz no asfalto
  (`road3d/tunnel_light_pools.gd`, 1 chamada). Também sumiu o erro antigo de normal na malha do morro. (4) Topo deste
  arquivo corrigido (Android já instalado). Custo (modo médio, `tools/measure_t155.sh`): chamadas +0 a +3, triângulos +0,4 mil,
  textura +0,3 MB, FPS no ruído. Testes `test_mural_glow.gd` (4), `test_tunnel_portals.gd` (3). Capturas `docs/capturas_t155/`.
- **T-154 (2026-10-19): ferrovia ao lado da rodovia, trens e viadutos de trem (F3).** Não havia peças de ferrovia de
  terceiros no PC (busca em `docs/` e Downloads, que agora está vazia; ver `docs/INVENTARIO_MODELOS.md`): via dupla, trilhos,
  muro, catenária, viaduto, pilares, bocas de túnel, locomotiva e vagões são **por código** (`blender/scripts/build_railway_kit.py`,
  determinístico, conferido 2x); o **bonde amarelo** é o CAF Urbos 3 do Marco (`docs/Modelos/Modelos Melhorados/`, Sketchfab Standard)
  sem interior, 71 mil → 6,9 mil triângulos, repintado e sem logotipos. Jogo: `road3d/railway_layout.gd` (onde fica em cada rota),
  `rail_line.gd` (geometria da linha), `rail_traffic.gd` (quando passa cada trem; só visual, relógio próprio, determinístico),
  `railway_3d.gd` (via + peças num bloco de 300 m com UMA textura), `trains_3d.gd` (MultiMesh por modelo), `rail_kit.gd`,
  `rail_mound.gd`; `race_scene_3d.gd` (+6 linhas) e `CityBuilder.keep_out` (sem prédio em cima do viaduto de trem). Litoral
  0–2.150 m (boca de túnel nas pontas), cidade a rota inteira elevada + viaduto sobre a pista em 1.500 m, montanha viaduto sobre a
  pista em 240 m + 1.240–2.080 m e 2.380 m–fim (entra e sai do morro do túnel); livre nos trechos de 2 faixas da T-153. 1º trem
  ~10 s depois da largada, depois a cada 22–40 s. Medido (modo médio, sem vsync, `tools/measure_railway.sh`, andando de 300 m):
  litoral 280–284 → 288–291 chamadas, viaduto 307–311 → 314–318, montanha (sem ferrovia nesse trecho) 301–302 → 302; triângulos
  +9 a +27 mil com trem à vista (o bonde duplo tem 14 mil); textura +1,8 a +1,9 MB; FPS no ruído do PC (183–232 com e sem).
  Testes `tests/test_railway.gd` (10). Capturas `docs/capturas_t154/` (cada cena: dia em cima, noite embaixo; `antes_depois.png`,
  `modelos_ferrovia.png`). Pendências: confirmar o bonde e a pintura, aprovar lugares e frequência, som do trem (não existe).
- **T-139 (2026-10-18): eventos de pista** (acidente, obras, estreitamento 3 → 2 faixas). Simulação: `sim/track_events.gd`
  (dados, intervalo fechado por z, sorteio pela semente, folga do prazo, limite das obras) e `sim/event_contact.gd` (cones, batida
  no veículo parado/barreira, raspada na beirada, parede do fim de faixa, chapas de aço); `TruckSim` recusa trocar para faixa
  fechada; `BotDriver._closure` e `TrafficSim._avoid_closure` saem cedo da faixa fechada e respeitam 60 km/h nas obras. Rede: o
  servidor sorteia e manda `events` no `race_setup` (protocolo 2; regra da sala `events`); dano dos eventos vai na atualização de
  dano. Visual: `road3d/track_events_3d.gd` + `event_props.gd` + atlas `assets/textures/event_atlas.png`
  (`tools_dev/make_event_atlas.gd`, precisa de janela); a estrada apaga o tracejado da faixa que acaba (`RoadMesh._lane_ends`).
  HUD: `ui/event_hud.gd` ("ACIDENTE À FRENTE · 350 m", faixas fechadas, "SAIA DESTA FAIXA!", "PRAZO +8 s", "FAIXA FECHADA",
  "100 km/h! A CARGA ESTÁ SACUDINDO"); textos em `data/i18n/pt-BR.json` (`hud.event.*`). Som: reservas com arquivos que já
  existem; 5 nomes novos pedidos em `docs/AUDIO_ELEVENLABS.md`. Eventos fixos: litoral estreitamento (direita) 1.650 m, viaduto
  acidente (meio + direita) 2.000 m, montanha obras (direita) 2.450 m. Custo medido (modo médio, jogador parado no lugar, mesmo
  quadro com e sem o visual): **+3 chamadas** por obra/estreitamento, **+11** no acidente (3 + 2 carros do trânsito); FPS igual
  (75, limitado pelo monitor). Perda de tempo média dos bots difíceis: +0 a +9 s por evento (tabela em `docs/BALANCEAMENTO.md`).
  Testes `tests/test_track_events.gd` (11); medidores `tools_dev/measure_event_times.gd`, `trace_event.gd`,
  `debug_events_3d.gd`, `count_model_surfaces.gd`; capturas `docs/capturas_t139/`. Depuração: `--hide-events-3d` (esconde só o
  visual). Pendências: confirmar com o Marco a regra das chapas e a frequência; gerar os 5 sons; carros batidos ficam escuros à noite
  (só o pisca-alerta aparece bem).
- **T-145 (2026-10-19): carroceria graneleira + regra carga x carroceria.** Modelo "Carroceria_Brasil_Graneleiro" (pasta
  `docs/Modelos/Novas Melhorias/Carroceria/`, fora do Git, Royalty Free (no AI)) reduzido 81 mil → 7,8 mil triângulos por
  `blender/scripts/truck3d/gran_src.py` (piso, fueiros, lona preta, lanternas e para-choque do original; 64 trincos de 964
  triângulos viram caixinhas; parafusos somem) + `truck3d/graneleira.py` (tampas com o mural repetido 3x, cabeceira "torii"
  cromada com o andon da frente, armação traseira com o andon de trás, luzes, placa, neon; pontos de montagem do teto/painel
  lateral movidos para a lona/tampas). Chassi do baú médio (8,2 m, 12 m na pista). Gerar: `build_truck_3d.py -- --variant
  graneleira --cab chata|jac|curta|americana [--body-src OBJ] [--cab-src ...]` (ou `tools/build_all_trucks.sh`) →
  `dekotora_truck_graneleira_<cabine>.glb` (66–78 mil triângulos). Jogo: `data/bodies/graneleira.tres` (14 t, 7.500 kg,
  `cargo_kind = open`), garagem aba Modelo (grátis como os outros), bot 3 da corrida offline, descritor de rede `"body"`.
  Regra (`CargoDef.needs`, `Contracts.missing_body/fits`): eletrônicos/refrigerados/louça só no baú; **grãos e brita (novas)**
  só na graneleira; madeira/aço/peças nas duas; Mercado mostra "SÓ BAÚ"/"SÓ GRANELEIRA" e bloqueia com "PRECISA DE BAÚ"/
  "PRECISA DE GRANELEIRA"/"PESADA DEMAIS"; trocar de modelo sorteia quadro novo se nenhum frete servir
  (`GameState.board_serves_body`); migração do perfil (modelo desconhecido → baú médio; contrato antigo ganha `needs`).
  Medido (modo médio, litoral à noite): 75 FPS igual ao baú médio, ~385 vs ~405 chamadas, textura 46 vs 50 MB. Teste
  `tests/test_graneleira.gd` (10) + graneleira no `test_wheels_spin`; capturas `docs/capturas_t145/`; depuração: garagem
  `-- --demo --body=graneleira [--cab=jac] [--noparts]`, corrida `-- --decorated --body=graneleira`, Mercado
  `res://scenes/menu/main_menu.tscn -- --demo-body=graneleira --screen=market`. **Pendente do Marco:** confirmar a regra de
  carga, o tamanho único (médio), a lona preta, 14 t/7.500 kg e se a graneleira deve custar algo (ver `docs/DECISOES.md`).
- **T-143 (2026-10-19): viatura + carro batido no acidente, jipe no trânsito** (Royalty Free (no AI), confirmado pelo Marco).
  Blender: `build_traffic_cars.py -- --model police,jeep,wreck` (+ `lib/traffic_police.py`, `traffic_jeep.py`, `traffic_wreck.py`;
  lê `docs/Modelos/Modelos Melhorados/`, `docs/Modelos/Novos modelos/` (`--new-dir`) e `docs/Modelos/Novas Melhorias/` (`--wreck-dir`), fora do Git;
  num worktree passe os caminhos absolutos da pasta principal). Viatura `car_police.glb` 7,3 mil tri (preto/branco japonês
  genérico, sem NYPD/Toyota/placa, giroflex vermelho animado por `road3d/police_beacon.gd`), carro batido `car_wreck.glb`
  6 mil tri (picape amassada), jipe `car_jeep.glb` 5,1 mil tri ("SUZUKI" apagado; tipo CARRO do trânsito). Acidente
  (`event_props.gd`): viatura primeiro, batido depois; superfícies do evento 11 → 9, chamadas e FPS iguais (modo médio).
  Teste `tests/test_accident_cars.gd` (4). Capturas `docs/capturas_t143/`. Depuração: `--traffic-model=car_jeep`.
  Pendências: os carros parados do acidente não têm placa; o carro batido é uma malha "esculpida" (T-155: rodas redondas e sem lascas embaixo; o amassado continua irregular de propósito).
- **T-115 (2026-10-17): análise de modelos de terceiros em `docs/NOVOS_MODELOS.md`**; nenhum entra sem o Marco confirmar a licença; Canter descartado (extraído de outro jogo). Aguardando o Marco informar origem/licença.
- **T-121 + T-124 (2026-10-18): 6 carros novos no trânsito** a partir dos modelos de terceiros (licença confirmada pelo Marco):
  Van 01, Ascona, Falcon, SUV (tipo carro), **Fumi SC** (esportivo raro, 104–122 km/h) e **ônibus Jetset** (13,3 m, lento, 12 t).
  Scripts: `blender/scripts/build_traffic_van01.py` e `build_traffic_cars.py -- --model all` (+ `lib/traffic_kit.py`,
  `traffic_classify.py`, `traffic_preview.py`; lêem `docs/Modelos/Novos modelos/` e `docs/Modelos/Modelos Melhorados/`, fora do Git). Cada carro:
  2 materiais (`paint_white` + atlas de cores lisas), rodas `wheel_f`/`wheel_r` que giram, 4,7–6,1 mil triângulos (ônibus 8,8 mil).
  Simulação: `TrafficSim.Kind` (tamanho, velocidade, massa por tipo; fila/ultrapassagem atrás de quem é mais lento), hitbox por tipo
  em `Collision.resolve_traffic`; `Traffic3D.MODELS_BY_KIND`. Medido (kanto_2, 14 veículos, qualidade média): superfícies do
  trânsito 96 → 65, ~420 chamadas de desenho (antes ~440), triângulos ~208 → ~232 mil, 75 FPS nos dois. Comparar:
  `-- --traffic-classic` (só os 4 antigos). Capturas: `docs/capturas_t124/`. Testes: `test_traffic_models.gd`, `test_traffic_kinds.gd`.
- **Plano visual (`docs/PLANO_VISUAL.md`, análise do Marco em `docs/dekotora_analise_visual/`) — V0 a V7 FEITOS (2026-10-17)**:
  V0 rodas giram no eixo certo; V1 três identidades em `docs/DIRECAO_ARTE.md` (**Marco escolhe A, B ou C**); V2 hora do dia por rota
  (`TimeOfDay`, `data/time/night|dusk|day.tres`, céu por shader com estrelas/lua/sol/nuvens/Fuji; `--time=day` para testar);
  V3 via expressa japonesa (`road_furniture.gd`: sem zebra, faixa amarela nas curvas, 速度落とせ/80 pintados, delineadores e olhos de gato,
  pórticos com kanji; cidade em viaduto; túneis por rota em `tunnel_3d.gd`); V4 texturas CC0 do Poly Haven + desgaste;
  V5 efeitos de velocidade e luz com chaves em Opções > Gráficos (`speed_fx.gd`, `light_streaks.gd`); V6 cromo por matcap (`chrome_matcap.gd`,
  ferramenta `scenes/tools/chrome_compare.tscn`); V7 caminhão Dekotora (`blender/scripts/truck3d/deco.py`: fileiras de luzes, andons com kanji
  銀河丸/街道爆走, mural trocável em `game/assets/vehicles/dekotora/murals/mural_side.png` ou `user://mural_side.png`).
  Custo no modo médio: ~345 chamadas de desenho (antes ~330). **V8 (medir no celular) depende do APK.**
- **Lote ATB-1 (2026-10-17, T-099..T-104, base: `docs/REFERENCIA_ART_TRUCK_BATTLE.md`)**: **controle só por faixas** (3 faixas + acostamento; 1º toque liga a seta, 2º toque no mesmo lado em até 1,5 s troca em ~0,7 s; `Lanes`, `TruckSim._lane_input`, botões ◀ ▶ grandes; bots e rede usam a mesma regra, o snapshot leva faixa/seta);
  **prazo de entrega** (`RaceSim.deadline`, `RouteDef.deadline()`, contrato `deadline_s`) e **vitória = 1º E no prazo** (derrota por tempo esgotado ou por chegar depois do rival paga 0 ¥);
  **perda de carga 0–40%** do prêmio por contato/batida e tipos de carga (frágil, pesada, perecível; `CargoDef.trait_kind`), aviso na contagem regressiva; **rival de verdade** (`BotDriver`: trava no trânsito, duelo lado a lado, espelha a seta, empurra, sem borracha);
  **pausa** Continuar/Revanche/Desistir sem escurecer e barra de progresso com marcador do jogador e do rival. Números em `docs/BALANCEAMENTO.md`; capturas em `docs/capturas_atb1/`.
  Depuração das capturas: `godot --path game res://scenes/race/race3d.tscn -- --route=kanto_1_coast --demo=close --shots=PASTA` (`--demo=lanes|close`, `--contract=ceramica`, `--paused`; ver `race_demo.gd`).
  Pendências: ~~erro antigo de malha no túnel~~ (corrigido na T-155); falta jogar para ajustar prazo, empurrão e a regra "derrota paga 0".
- Opcional: contratar VPS (`server/README.md`), chave de assinatura Android (`docs/RELEASE_ANDROID.md`), conta Play Console / itch.io.

## Problemas conhecidos / ideias

- ~~Cromo escuro à noite~~ resolvido com matcap (V6).
- Trânsito e rivais usam carrocerias/modelos simples; sem LOD (160k triângulos, ~400 draw calls na corrida: ok no PC, medir no celular).
- Dano visual dos acessórios: amassado = material opaco + inclinação leve; quebrado = some + detrito genérico.
- Sem login: o código de jogador é a "senha". Servidor aceita perfil do cliente se `rev` for maior (confiança entre amigos).
- Mural riscado só conta batidas laterais; sem textura de risco.
- Teste de rede ainda não foi feito com celular real (só localhost com atraso simulado).

## Lote ATB-2 (2026-10-17, T-107..T-112): alma Dekotora

- **Destaque** (`GameState.destaque()`): peças + escape + pintura (7 cores, `StyleCatalog`) + adesivos; na loja, no topo da garagem, na corrida (Fama) e no resultado.
- **Garagem:** abas MODELO · DECORAÇÃO (destaque, peso, proteção por zona, pintura, luzes, adesivos, peças/calotas) · MECÂNICA · REPARO; botão ☾ NOITE / ☀ DIA (prévia com luz e cromo próprios).
- **Luzes** (`LightPatterns`, shader): fixas · sequencial · alternado · respirando; acendem à noite e nos túneis. **Adesivos** (`DecalCatalog`/`DecalPlacer`): 6 provisórios em `game/assets/decals/` (arte própria: ver `LEIA-ME.md` ali ou `user://decals/`).
- **Rivais recusam** por Fama/destaque (`GameState.rival_refusal`), com fala no Mercado de fretes. **Largada/chegada** com corte lateral, banners e clarão na saída do túnel (`RaceCinema`).
- Capturas em `docs/capturas_atb2/`. Depuração: garagem `-- --demo --decals --lights=sequential --tab=parts --view=rear [--day] [--hideui] --shot=ARQUIVO.png`; corrida `-- --route=kanto_2_viaduct --time=night --decorated --start=300 --demo=lanes --shots=PASTA`. **Os modos de depuração (`--demo`, `--decorated`) gravam em `user://demo_profile.json`, nunca no perfil real** (antes de 2026-10-17 o `--demo` da garagem regravava `profile.json`).
- Pendências: adesivos e padrão de luz só aparecem no aparelho do dono (multiplayer não envia); valores de destaque/Fama dos rivais são propostas; as luzinhas densas são as do modelo (não foram adicionadas fileiras novas).
