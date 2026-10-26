---
name: godot-dekotora
description: Use SEMPRE que for escrever, alterar, rodar, testar, exportar ou depurar qualquer coisa do projeto Godot do Dekotora Legends (pasta game/) — GDScript, cenas .tscn, recursos .tres, testes, build Android/Windows/servidor headless, rede ENet. Traz os comandos testados no Godot 4.7.1, armadilhas do GDScript 4 e as regras de arquitetura do projeto.
---

# Godot 4.7 no Dekotora Legends

Leia também `docs/ARQUITETURA.md` (estrutura) e `CLAUDE.md` (regras). Esta skill é o "como".

## Comandos (testados no Godot 4.7.1, rodar na raiz do projeto)

| Para | Comando |
| --- | --- |
| Importar recursos e registrar `class_name` novos | `godot --headless --path game --import` |
| Abrir e fechar (pega erros de cena/autoload) | `godot --headless --path game --quit-after 30` |
| Rodar os testes | `godot --headless --path game -s res://tests/run_tests.gd` (código de saída 0 = passou) |
| Checar a sintaxe de um script | `godot --headless --path game --check-only -s res://scripts/x.gd` |
| Rodar como servidor | `godot --headless --path game -- --server` |
| Exportar | `godot --headless --path game --export-release "Windows" ../builds/dekotora.exe` |
| Exportar Android | `--export-debug "Android" ../builds/dekotora.apk` (precisa do SDK/JDK configurados no editor) |

- **Depois de criar um `class_name` novo, rode `--import`**; sem isso, outros scripts não enxergam a classe no modo sem tela.
- Leia a saída procurando `SCRIPT ERROR`, `Parse Error`, `ERROR:`. Os avisos de importação são normais.
- Argumentos depois de `--` chegam em `OS.get_cmdline_user_args()` (confirmado: `["--server"]`).
- No modo sem tela, `DisplayServer.get_name() == "headless"`.

## Testes

- Executor pronto: `game/tests/run_tests.gd`; base `TestCase` em `game/tests/test_case.gd`.
- Um arquivo por sistema: `game/tests/test_<sistema>.gd`, `extends TestCase`, funções `test_*()`.
- Asserções: `check(cond, msg)`, `check_eq(a, b, msg)`, `check_near(a, b, tol, msg)`.
- Teste a **simulação** (`scripts/sim/`) sempre: ela é código puro e roda sem tela.

## Regras de arquitetura (não negociáveis)

1. `scripts/sim/` **não** usa `Input`, `Node2D/Sprite2D`, `AudioStreamPlayer`, `get_tree()` nem `_process`.
   São classes `RefCounted` com `step(dt: float)`. Passo fixo de 1/30 s.
2. A apresentação lê o estado da simulação e interpola para 60 FPS.
3. Dados de jogo em `Resource` (`.tres`) em `game/data/`; nada de números de equilíbrio soltos no código.
4. Tipagem estática em tudo. Sinais para comunicar sistemas.

## GDScript 4: armadilhas comuns (não use sintaxe do Godot 3)

| Godot 3 (errado) | Godot 4 (certo) |
| --- | --- |
| `yield(obj, "sinal")` | `await obj.sinal` |
| `export var x = 1` | `@export var x: int = 1` |
| `onready var n = $No` | `@onready var n: Node = $No` |
| `connect("sinal", self, "_metodo")` | `sinal.connect(_metodo)` |
| `instance()` | `instantiate()` |
| `Tween.new()` + `add_child` | `create_tween()` |
| `rand_range(a, b)` | `randf_range(a, b)` |
| `PoolStringArray` | `PackedStringArray` |
| `KinematicBody2D` / `move_and_slide(vel)` | `CharacterBody2D` / `velocity = ...; move_and_slide()` |
| `remote func` / `rpc_id` antigo | `@rpc("any_peer", "unreliable")` + `metodo.rpc_id(id, ...)` |

- Arrays tipados: `var xs: Array[float] = []`. Dicionários tipados existem no 4.4+: `Dictionary[String, int]`.
- Divisão inteira: `5 / 2 == 2`; use `5.0 / 2.0`.
- `@tool` só quando o Marco pedir algo que rode no editor.

## Editando `.tscn` e `.tres` à mão

- Prefira criar cenas **por código** em scripts quando forem simples; para cenas novas, gere o arquivo mínimo:
  ```
  [gd_scene format=3]

  [node name="Raiz" type="Node2D"]
  ```
- Ao referenciar arquivos, use `[ext_resource type="Script" path="res://..." id="1_x"]` e não invente `uid`;
  o Godot cria os `uid` na próxima importação. Depois de editar à mão, rode `--import` e `--quit-after`.
- Nunca edite `game/.godot/` (cache).

## Pixel art e tela

- Base 480×270, `stretch/mode = viewport`, `scale_mode = integer`, filtro padrão Nearest (já no `project.godot`).
- Sprites sempre em posições inteiras (`position.round()`) para não tremer.
- Renderizador Compatibility: sem compute shaders. Para o brilho das luzes, use as camadas `*_glow` com
  `CanvasItemMaterial` em modo aditivo; teste antes de depender de efeitos de `WorldEnvironment`.
- Estrada pseudo-3D: desenhe com poucos nós (um `_draw()` ou uma malha); medir FPS no celular desde cedo.

## Rede (Fase 6)

- `ENetMultiplayerPeer.create_server(porta, max_clientes)` / `create_client(ip, porta)` (confirmados no 4.7.1);
  depois `multiplayer.multiplayer_peer = peer`.
- Comandos do cliente: RPC `unreliable` a 30/s. Snapshots do servidor: `unreliable_ordered` a 20/s.
  Eventos importantes (peça quebrou, fim da corrida): `reliable`.
- **Não há SQLite embutido** no Godot (confirmado). Perfis: um JSON por jogador em `user://profiles/`,
  gravando num arquivo temporário e renomeando (escrita atômica).
- Teste local: um processo `-- --server` + dois clientes no mesmo PC.

## Verificar SEMPRE antes de entregar

1. `--import` (se criou `class_name`) → testes → `--quit-after 30` sem `ERROR`.
2. Explique ao Marco onde clicar no editor e o que ele deve ver.
3. Se mexeu em algo visual, peça uma captura de tela ou gere uma build para o celular.

## Capturas de tela (depuração)

- Corrida: `--burst=S` grava 2 quadros seguidos (junto com `--shots=PASTA` e `--cam=...`); garagem: `--shot-pair` grava o par junto com `--shot=ARQ.png`, que também gera `ARQ_2.png`.

## Curvas e faixa (T-132)

- A regra da curva fica em `game/scripts/sim/curve_grip.gd`, usada pelo `TruckSim`. Vale igual para jogador, bots, servidor e predição do cliente.
- O giro do corpo vem de `TruckSim.body_yaw()` e `TrafficSim.body_yaw(c)`, aplicado em `TrackPath.vehicle_transform(z, x, length, body_yaw, roll)` com pivô no eixo traseiro.
- Medidor de faixa: `godot --headless --path game -s res://tools_dev/measure_lane_following.gd` (imprime desvio máximo e % de corpo torto por rota).
- Capturas de cima: `-- --route=kanto_3_mountain --time=day --cam=top --nohud --autoplay --start=300 --start-speed=21 --snap-every=2 --shots=PASTA`.
  - `--cam=high` para 75 m; `--cam=side` para alta de lado; `--demo=lanes` para troca de faixa.

## Capturas de telas (T-138)

- Todas as telas de uma vez: `bash tools/ui_shots.sh 960x540 PASTA [tela...]` (na raiz do projeto). Sem lista de telas, tira todas. Cada tela abre uma janela, por isso não funciona com `--headless`.
- Para 2400x1080 use `1200x540`: a janela não cabe no monitor, mas o layout é o mesmo (só muda a nitidez).
- Gancho `--shot=` de qualquer tela: chame `DebugShot.arm(self)` no `_ready()` da tela (ex.: `scripts/ui/main_menu.gd`). Sem `--shot=` não faz nada.
- Em Control criado já dentro da árvore, use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, não `set_anchors_preset`.
- Toda chave nova de texto precisa entrar em `game/data/i18n/pt-BR.json`. O teste `tests/test_i18n_keys.gd` acusa se faltar.

## Eventos de pista (T-139)

- Flags da corrida (`scripts/road3d/race_demo.gd`):
  - `--event=TIPO:FAIXAS@Z+COMPRIMENTO` força um evento no lugar dos da rota (pode repetir). Ex.: `--event=accident:2-3@900`, `--event=works:3@700+170`, `--event=narrow:1@800`.
  - `--no-events` deixa a pista livre.
  - `--event-seed=N` fixa a semente do sorteio (repete os mesmos eventos).
  - `--hide-events-3d` esconde só o visual (`track_events_3d.gd`), para medir o custo de desenho.
  - `--traffic-model=car_jeep` (depuração/capturas): todo carro comum do trânsito vira esse modelo (`traffic_3d.gd`).
- Acidente (T-143): usa `car_police` (viatura, `EventProps.POLICE_MODEL`) e `car_wreck` (carro batido, `EventProps.WRECK_MODEL`). Nenhum dos dois anda no trânsito comum.
- Medidores (headless):
  - `godot --headless --path game -s res://tools_dev/measure_event_times.gd -- --seeds=5 --route=ROTA` (`--seeds` e `--route`).
  - `godot --headless --path game -s res://tools_dev/trace_event.gd -- --route=R --event=... --tseed=N --bot=K` (`--route`, `--event`, `--tseed`, `--bot`, `--seed`, `--from`, `--to`).
- `tools_dev/make_event_atlas.gd` precisa de janela: rode sem `--headless`.
- Todos leem o mesmo intervalo, `TrackEvents.interval(ev, zz)` em `scripts/sim/track_events.gd`. Assim a simulação, os medidores e o visual (`event_props.gd`) ficam iguais.

## Batidas, freada e buzina (T-141/T-144)

- Força das batidas na sim (`sim/collision.gd`, `sim/thrown_car.gd`): empurrão de faixa entre caminhões e carro do trânsito arremessado; o estado do carro (`out_t`, `yaw`, `y`...) vai no snapshot (giro s16 + altura u8). Teste: `tests/test_impacts.gd`.
- Efeitos só na apresentação (`road3d/impact_fx.gd`, `road3d/brake_fx.gd`), todos atrás de `Settings.fx_impact` e cortados por `Settings.quality`. Shader novo de efeito: aqueça no 1º quadro (`warmup`, desenhado embaixo do asfalto) para não soluçar na 1ª batida.
- Efeito que sai do nariz do caminhão: a câmera atrás do baú não vê. Prenda as faíscas ao caminhão (`local_coords`) e jogue pedaços para cima/lados com o embalo do caminhão.
- Em `--quality=1` a escala 3D é 0,6: risco/partícula com menos de ~0,08 m some. Teste o visual com a sonda `tools_dev/fx_probe.gd` (precisa de janela) e na corrida com `--demo=crash|brake`.
- Batida no trânsito custa velocidade (T-152): `Collision.penalty_fraction` + tranco `TruckSim.jolt_t` (acelerador sem efeito; testar o estado com `jolted()`). Estado novo que a predição do cliente usa vai no snapshot EM TICKS (não em centésimos), senão cliente e servidor discordam por 1 tick. Teste: `tests/test_traffic_penalty.gd`; erro de predição online: linha `PRED:` do `tools/net_test.sh`.
- **Armadilha (T-185)**: `CPUParticles3D` com material em billboard (`BILLBOARD_PARTICLES`/`ENABLED`) precisa de
  `billboard_keep_scale = true`. Sem isso a escala de cada partícula é ignorada e as que ainda não nasceram (escala 0,
  cor padrão preta) aparecem em tamanho cheio no emissor: disco preto parado na pista depois de uma freada curta.
- `--fps-log` mostra `max N no periodo` (pico de chamadas de desenho, ex.: na batida) e `PICO:` para quadros acima de 50 ms; `--no-impact-fx` compara sem os efeitos.

## Kit de beira de estrada (T-146)

- `--no-kit` desliga o kit (`road3d/roadside_kit.gd`) e volta às caixas antigas (vigas dos pórticos, placas, barreiras). Use para comparar antes/depois.
- Capturas: `GODOT=... bash tools/capture_t146.sh PASTA [--no-kit]` (3 rotas, dia e noite; grava `PASTA/<rota>_<cena>_<hora>/t01.png`).
- Custo: `tools/measure_roadside_spot.sh` mede o MESMO quadro com e sem kit (FPS médio, modo médio, eventos com semente fixa).
- `MeshBatch` (`road3d/mesh_batch.gd`) junta peças diferentes num único nó por bloco e material: uma chamada de desenho por material e bloco visível. Diferente do MultiMesh, aceita modelos diferentes.
- `GlbMesh` (`road3d/glb_mesh.gd`) mantém as tangentes do .glb (mapa de normais funciona).
- As artes dos outdoors saem de `godot --path game -s res://tools_dev/make_billboard_art.gd`. Precisa de janela: rode sem `--headless`.

## Trechos de 2 faixas (T-153)

- Dados (`scripts/data/route_def.gd`):
  - `RouteDef.lane_sections`: `{start, end, lanes: 2, taper, look}` em metros ao longo da pista. A faixa que acaba é sempre a da DIREITA. `look` (`tunnel` | `bridge` | `old_viaduct`) só muda o visual.
  - `RouteDef.bridges`: lista de `Vector2` (início m, comprimento m), só visual (pilares, guarda-corpo).
- Simulação (`scripts/sim/lane_sections.gd`):
  - Os trechos entram na lista de eventos como `TrackEvents.Kind.SECTION`.
  - O setter de `Track.events` sempre junta os trechos, então `--no-events` e a regra de sala `events: false` não tiram os trechos da pista.
  - `Track.lanes_at(z)` devolve 2 onde a faixa da direita está fechada, senão 3.
- Visual: lê `LaneSections.profile(evs, z)`, que devolve um `Vector3` em metros: x = mureta esquerda, y = mureta direita, z = linha de borda da direita (sem trecho: 13, 13, 5,15).
- Flags:
  - `--no-sections` na corrida (depois de `--`): pista sem os trechos, para medir custo.
  - Testes: `godot --headless --path game -s res://tests/run_tests.gd -- --only=lane_sections` (o filtro é um trecho do nome do arquivo de teste).
- Capturas: `bash tools/capture_t153.sh PASTA [filtro]` (na raiz do projeto, Git Bash). O filtro é um trecho do nome (ex.: `coast`, `tunel`, `night`; `all` = tudo). Grava `PASTA/<rota>_<cena>_<hora>/t01.png`. O script já converte caminho relativo em absoluto, porque o jogo roda com `--path game`. `GODOT=...` troca o executável do Godot.
- Setup online: leva `lane_sections` (protocolo 5, `scripts/net/protocol.gd`). O cliente usa a pista do servidor.

## Ferrovia (T-154)

- Flags da corrida (depois de `--`):
  - `--no-rail` tira a ferrovia (`road3d/rail_kit.gd` lê a flag). Use para comparar antes/depois.
  - `--train=freight|lrt` força o tipo de trem (carga ou bonde amarelo) em `road3d/railway_3d.gd` / `rail_traffic.gd`.
  - `--train-dir=same|opposite` força o sentido do trem (mesmo sentido do caminhão ou contrário).
- Capturas: `GODOT=... bash tools/capture_t154.sh PASTA [cenas]` (na raiz do projeto, Git Bash). Sem lista de cenas, tira todas.
  Cenas: `litoral_trem litoral_boca cidade_trem cidade_cruzamento montanha_cruzamento montanha_boca montanha_trem`.
  Para comparar: `CAPTURE_EXTRA="--no-rail" bash tools/capture_t154.sh PASTA`. As capturas de referência estão em `docs/capturas_t154/`.
- Custo: `GODOT=... bash tools/measure_railway.sh` mede o modo médio nas 3 rotas, com e sem `--no-rail`.
- Onde ficam as linhas: `game/scripts/road3d/railway_layout.gd` (um trecho `match` por rota). Se mudar trechos de 2 faixas da T-153
  ou túneis, ajuste ali. O teste `tests/test_railway.gd` avisa se a linha invadir a pista, um túnel ou um trecho de 2 faixas.
  Na cidade a linha é elevada a 40 m e o teste ignora os trechos estreitos de lá.
- A ferrovia é só visual (sem sim nem rede): cada jogador vê os próprios trens.

## Acabamento (T-155)

- Mural aceso à noite (`game/scripts/truck/mural_glow.gd`, classe `MuralGlow`):
  - A força vem da hora do dia, `TimeOfDay.mural_glow` (em `game/data/time/*.tres`): dia `0.0` (nada muda), entardecer `0.4`.
    `night.tres` não traz a chave, então a noite usa o padrão `0.8` de `scripts/data/time_of_day.gd`.
  - Dentro de túnel o mural usa no mínimo `MuralGlow.TUNNEL` (0,75), mesmo de dia (`race_scene_3d.gd`).
  - A corrida chama `TruckNode.set_mural_glow(energia)` ao criar cada caminhão e de novo só quando a força muda (entrada/saída de túnel, em `_update_truck_lights` de `race_scene_3d.gd`).
  - A emissão fica **sempre ligada** no material (`MuralGlow.setup`); só a força muda (`set_level`). Não ligue/desligue a emissão no meio da corrida: isso recompila o shader e dá soluço.
  - Teste: `game/tests/test_mural_glow.gd`.
- Armadilha: `Tunnel3D._arch_of(t)` (`scripts/road3d/tunnel_3d.gd`) precisa ir do pé esquerdo ao topo e descer até o pé direito, sem repetir o topo e com x só crescendo. Se o perfil começar no topo, a boca fica fechada e uma chapa atravessa o túnel. Coberto por `tests/test_tunnel_portals.gd`.
- Capturas (precisam de janela, então não use `--headless`): `bash tools/capture_t155.sh PASTA [mural|ficha|batido|tunel]` (na raiz do projeto, Git Bash). Sem grupo, tira todos. Use caminho absoluto para PASTA. `GODOT=...` troca o executável.
- Folha lado a lado (funciona sem tela), sempre com caminho absoluto em `--out` e nos PNGs:
  `godot --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out=ABS.png A.png B.png ...`
  Opções `--cols=2` e `--w=640`. Ordem: esquerda para a direita, de cima para baixo (antes, depois, antes, depois...).

## Som do motor por escapamento e buzinas (T-173)

- Quem escolhe os arquivos: `scripts/audio/engine_sounds.gd` (`EngineSounds.spec(engine, turbo, exhaust)` /
  `from_descriptor(desc)` devolve um Dictionary; `EngineAudio.setup_spec(spec, jake)` toca). O mapa escapamento → perfil é
  dado: `ExhaustDef.sound_profile` em `data/engines/exh_*.tres` ("" = loops do motor, 4 camadas). Perfil = 3 loops
  `<perfil>_idle/_mid/_high` + `<perfil>_turbo_whine` + `<perfil>_blowoff` em `assets/audio/engines/`. Arquivo faltando =
  volta ao som antigo.
- Nome de som que contém `_idle`, `_mid`, `_high`, `_whine`, `_loop`... vira loop no `AudioBus` (`LOOP_HINTS`): "pssh" e
  buzinas não podem ter esses pedaços no nome.
- Buzinas: `scripts/audio/horn_catalog.gd` (ids, musical ou sustentada, janela de loop medida). Perfil `horn` ("" =
  automática = a da peça); `GameState.installed_horn()/set_horn()`; ação online `set_horn`; descritor `horn` (protocolo 7).
- Garagem: `ui/garage_horns.gd` (seção BUZINA e botão OUVIR); prévia = `audio/sound_preview.gd` (nó filho do `AudioBus`).
- Rivais offline: `EngineSounds.rival_loadout(seed)` / `HornCatalog.rival_horn(seed)` (só som). `EngineAudio.synth_boost`
  inventa o boost de quem não tem turbo na sim.
- Medir som sem ouvir: Blender lê MP3 (`aud.Sound(path).data()` dá numpy) → duração, volume, envelope (ver LOG da T-173).
- Testes `tests/test_engine_sounds.gd`; ferramenta `-- --cycle-profiles` em `scenes/tools/engine_audio_test.tscn`;
  `tools/net_test.sh` imprime `SOM_REDE:` (`HORN=`/`EXH=`).
- Em script de áudio, pegue o `AudioBus` por `(Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")`
  quando o nó pode estar fora da árvore (testes): `get_node("/root/...")` falha fora dela.

## Abertura do duelo (T-156, refeita na T-204)

- Flags da corrida (depois de `--`):
  - `--intro=full|short|none` força a versão: `full` = cena cheia (5 s + 3 s de contagem = 8 s), `short` = só a contagem (3 s), `none` = nenhuma.
  - `--no-intro` tira a abertura. `--start=` e `--demo=` também desligam a abertura, de propósito.
  - `--reduce-flash` liga "Reduzir clarões" sem gravar (`Settings.fx_reduce_flash`).
- Linha do tempo e curvas PURAS em `road3d/duel_plan.gd` (`PHASES`, `flash_alpha`, `soft_alpha`, `bolt_state`, `title_state`,
  `bands_in`, `guard_in`, `black_alpha`); movimentos dos caminhões e câmera em `duel_shots.gd` (`truck_pose`, `studio_view`),
  tudo função do relógio da abertura (online todos veem o mesmo instante). Estúdio `duel_stage.gd`, névoa `duel_fog.gd`,
  controle/sons/prints `duel_intro.gd`, desenho `ui/duel_band.gd` + `ui/duel_bolt.gd`.
- Mudou a duração? `DuelPlan.total_seconds` alimenta o servidor (`room.gd`, `countdown_total`): suba `Protocol.VERSION` e gere o APK.
- Arte: `godot --path game -s res://tools_dev/make_duel_art.gd [-- --only=raijin,fujin,title,aura,fog]` (precisa de janela).
  Kit 2D em `tools_dev/duel_art_kit.gd`: formas = união de círculos (`Geometry2D.merge_polygons`, polígono sempre simples),
  `part()` = contorno + base + meia-lua de sombra (a peça menos ela mesma deslocada) + meia-lua de luz. Depois de gerar:
  `--import` e conferir no `.import` `compress/mode=2` + `mipmaps/generate=true` (o título fica `mode=0`).
- **Armadilha (fundo de cor)**: no Compatibility o `Environment` com `BG_COLOR` e `sky` atribuído desenha o CÉU no fundo
  (a cor é ignorada). No estúdio o céu é quase preto e é ele o fundo (`BG_SKY`), igual nos dois renderizadores.
- **Armadilha (FogVolume)**: câmera DENTRO da caixa de névoa volumétrica = tela inteira roxa. Mantenha o topo da caixa abaixo
  da lente e o fim antes da câmera da arrancada.
- A câmera recebe o `Environment` do estúdio, `far` 160 m e `attributes = null` (a profundidade de campo do Ultra borrava os
  guardiões); o sol da rota (`race_scene._sun`) apaga. Tudo volta em `_leave_studio` (fim ou pular). Teste: `test_duel_scene_flow.gd`.
- Prints de cada etapa (janela, `--fixed-fps 60`): `GODOT=... bash tools/capture_t204.sh PASTA [pc_ultra pc_media cel reduzido dia]`
  (grava `abertura_00.50s_1.png` ... `abertura_07.50s_1.png`, instantes em `DuelPlan.SHOT_TIMES`/`COUNT_SHOT_TIMES`) e folhas
  `bash tools/sheet_t204.sh PASTA`. Vídeo com som: Movie Maker `--write-movie ABS.avi --fixed-fps 30 --quit-after 275`.
- Custo: `GODOT=... bash tools/measure_t156.sh` (linhas `[abertura <fase>] FPS medio`). Duelo sem tela: `tools_dev/measure_duel.gd`.
- Regras de jogo: a campanha é **1 contra 1**. A corrida rápida é 4 caminhões com a versão curta. A revanche é curta.
- Online: 2 jogadores = versão cheia; **3–4 jogadores = "comboio"**: versão curta e trânsito um nível mais leve.
- **Protocolo 9** (`VERSION` em `scripts/net/protocol.gd`): o setup leva `intro` e `countdown_total` (8 s na cheia). Cada cliente
  toca a abertura pelo **relógio comum** do servidor (`DuelPlan.online_elapsed`); som que já passou (>0,3 s) não toca.
- Testes que montam a corrida de verdade (`race3d.tscn`) usam `const IN_TREE := true` no topo do arquivo.
- Texto que cresce na tela: fonte de tamanho **fixo** escalada com `draw_set_transform` (cada tamanho novo cria cache de
  textura). Nome do piloto: o maior de `DuelBand.NAME_SIZES` que couber. O título 対決 é textura (escala sem custo).

## Listas com rolagem no celular (T-165)

- Use **`TouchScroll.new()`** (`scripts/ui/components/touch_scroll.gd`), nunca `ScrollContainer.new()`, em listas de botões/cartões.
  No 4.7 o `ScrollContainer` rola pelo toque via clique de mouse emulado; filhos com `mouse_filter = STOP` (botões, painéis) seguram o evento
  e a lista não rola. O `TouchScroll` põe os descendentes em PASS (também os criados depois) e usa zona morta de 10 unidades.
- Teste de toque sem tela: `tests/test_touch_scroll.gd` (manda o mouse emulado com `device = InputEvent.DEVICE_ID_EMULATION` e depois o
  `InputEventScreenTouch/ScreenDrag`, via `root.push_input(ev, true)`; chame `get_minimum_size()` + `NOTIFICATION_SORT_CHILDREN` para montar o layout
  no mesmo quadro). Clique de mouse "real" (device 0) não chega aos botões no modo sem tela; teste mouse na janela.
- **T-177: o arraste é do próprio `TouchScroll`** (`_gui_input` fica com o botão esquerdo, o movimento e a roda; o arraste nativo do
  `ScrollContainer` nunca começa). Motivo: o nativo ficava preso em "arrastando" quando o botão clicado redesenhava a lista (a garagem faz isso
  em todo clique: o botão sai da árvore e o "soltar" morre junto) e a lista passava a seguir a seta do mouse sem botão. Regras:
  só rola com o botão/dedo apertado (`button_mask`), embalo ao soltar, roda rola 1/8 da altura e não vaza para a câmera 3D.
- Cartão que vira toque (`GaragePreviewUi.make_tappable`): só conta se `TouchScroll.of(card).scrolling()` for falso. Não use
  `Input.is_mouse_button_pressed` sozinho para separar clique de teclado: nos testes (`push_input`) o `Input` não sabe do clique.
- Testes: `tests/test_touch_scroll_mouse.gd` (PC, roda, arraste, lista que se redesenha no clique) e `tests/test_garage_deco_nav.gd`
  (garagem de verdade; `_settle()` força o layout dos containers no mesmo quadro).
- Garagem > DECORAÇÃO tem seções (`GarageDecoNav`, `ui/garage_deco_nav.gd`): barra fixa PEÇAS / PINTURA / LUZES / ADESIVOS fora da rolagem;
  encaixes em 2 colunas por lugar (frente, teto, laterais, traseira). Encaixe novo precisa entrar em `GarageDecoNav.AREAS` (o teste acusa).
  Captura de uma seção: `--deco=parts|paint|lights|decals`.
## Seta / pisca (T-170)

- "Seta" no jogo = o pisca da troca de faixa (`TruckSim.signal_dir`, 1º toque liga, 2º troca). Não existe outro pisca.
- Ritmo único: `SignalBlink` (`scripts/truck/signal_blink.gd`, 0,33 s aceso/apagado, começa aceso). Quem mostra ou toca
  a seta (TruckNode, RaceHud, TurnSignalAudio) tem a sua instância e chama `update(signal_dir, SignalBlink.now())`
  todo quadro; assim lâmpada, HUD e som andam juntos. Não use `Time.get_ticks_msec() / N % 2` para piscar a seta.
- Som sincronizado com algo visual: toque um arquivo curto em cada borda (acende/apaga) em vez de um loop gerado,
  cujo ritmo não bate. O clique da alavanca vem da borda de `TruckSim.tap_prev` (igual offline e online); contadores
  como `lane_changes` podem contar duas vezes no cliente online (a reconciliação reaplica comandos).
- Teste: `tests/test_turn_signal.gd` (`TurnSignalAudio.step(...)` com o relógio da simulação; fora da árvore só conta).
- Nos testes, o `_ready` do AudioBus ainda não rodou: o barramento "SFX" pode não existir (o `bus` volta "Master").

## Garagem: chão do palco e prévia (T-171)

- A origem do `TruckNode` é o chão da pista (pneu em y = 0 em todos os .glb). Em cenário com piso elevado (plataforma da
  garagem, 0,10 m), suba o caminhão pelo topo da malha: `TruckGround.top_of(cenario, "turntable")` e
  `TruckGround.wheel_bottom(modelo)` (`scripts/truck/truck_ground.gd`). O `GarageStage` já faz (`floor_y`). Conferir:
  `tools_dev/measure_wheel_ground.gd`.
- Prévia de peça/cor: estado em `GaragePreview` (nunca no perfil), o palco monta com `preview.loadout(gs)` /
  `preview.paint(gs)`. Mudança de encaixe/aba chama `preview.clear()`; `preview.settle(gs)` em todo redesenho encerra a
  prévia que virou realidade. Cartão tocável: `GaragePreviewUi.make_tappable` (só clique de mouse conta, o toque do
  Android chega como mouse emulado; soltar a até 12 unidades = toque, senão era rolagem; foco por teclado = prévia).
- Para não perder o foco do teclado, atualize a prévia sem redesenhar as listas (`_show_preview` na `garage_screen.gd`).
- Depuração: `-- --demo --noparts --preview=ID`, `--preview-paint=#hex`, `--fame=N`. Teste: `tests/test_garage_preview.gd`.
## Peças deluxe e brilho que acompanha dia/noite (T-172)

- `AccessoryGlow` (`scripts/truck/accessory_glow.gd`), um por caminhão (`TruckNode.glow`): materiais `glow_*` viram shader aditivo (mancha calculada pela UV, cor da 1ª lâmpada `lamp_*` da peça) e `acrylic_*` só mudam a força da emissão. A força vem de `TruckNode.set_lights_on` (1 noite/túnel, 0,4 prévia de dia, 0,12 apagado). Chame `glow.apply(n)` DEPOIS da variante e ANTES do `LightPatterns` (que tira o nome dos materiais `lamp_*`).
- Peças só desse lote: `tier = "deluxe"` no catálogo; visualizador `scenes/tools/accessory_viewer.tscn -- --cat=deluxe [--day] [--shot=ARQ.png]` ([N] liga/desliga as luzes).
- `tools_dev/gen_data.gd -- --only=id1,id2` grava só essas peças. **Sem `--only` regrava as rotas e apaga `lane_sections`/`bridges` (T-153).**
- Capturas `GODOT=... bash tools/capture_t172.sh PASTA_ABS [garagem|corrida]`; custo `bash tools/measure_t172.sh`.

## Cenário T-169/T-164 (montanhas, mar, árvores, viaduto, semáforos)

- Flags da corrida (depois de `--`), para comparar antes/depois:
  - `--no-backdrop`: volta aos cones de montanha e ao mar antigo (`road3d/backdrop_kit.gd`).
  - `--no-pontes-kit`: volta ao visual antigo das pontes (pilares de caixa, guard-rail de lâmina, sem postes); também desliga o viaduto e os postes (`road3d/pontes_kit.gd`).
  - `--no-poles`: tira só os postes de energia e os fios (`road3d/pontes_kit.gd`, `road3d/power_lines_3d.gd`).
  - `--no-overpass`: tira só o viaduto que cruza por cima (`road3d/overpass_3d.gd`).
  - `--no-lane-signals`: tira os semáforos de faixa dos túneis (`road3d/tunnel_signals_3d.gd`).
- T-179: as montanhas ficam a 1–6 km; a câmera da corrida vê até `BackdropKit.CAMERA_FAR` (8 km; `--view-far=900` volta ao antigo) e o shader delas usa neblina própria (`fog_disabled`). Conferir o que o jogador vê de verdade (câmera de jogo, hora da rota, modo médio): `bash tools/capture_t179.sh PASTA` + `bash tools/sheet_t179.sh ANTES DEPOIS`. Capturas com `--cam` fixa e `--time` forçado (capture_t169) escondem problemas da corrida normal.
- Onde configurar viadutos: `OverpassLayout.for_route(route_id)` em `game/scripts/road3d/overpass_layout.gd`. Devolve `[{z, angle}]` por rota (90 = perpendicular à pista). Hoje: `kanto_2_viaduct` (z 2050, 76°) e `kanto_3_mountain` (z 2580, 70°). O vão mínimo é a constante `CLEAR` (7,6 m).
- Achar trecho reto para um viaduto novo: `godot --headless --path game -s res://tools_dev/find_overpass_spots.gd` (lista os z retos de cada rota).
- Conferir um viaduto: `godot --headless --path game -s res://tools_dev/probe_overpass.gd -- --route=kanto_2_viaduct` (distância até a pista e vão livre a cada 10 m).
- Capturas (precisam de janela, sem `--headless`): `GODOT=... bash tools/capture_t169.sh PASTA [FILTRO] [extras]`. FILTRO é um trecho do nome (ex.: `montanha`, `arvore`, `night`); `all` = tudo. Antes: `bash tools/capture_t169.sh PASTA_ANTES all --no-backdrop --no-pontes-kit`.
- Custo: `GODOT=... bash tools/measure_t169.sh [QUADROS] [day|night]` (padrão 1500 quadros, noite). Comparar: `MEASURE_EXTRA="--no-backdrop --no-pontes-kit --no-lane-signals" bash tools/measure_t169.sh`.

## Câmera livre / explorador (T-181)

- Código em `game/scripts/debug/` (`Freecam`, `FreecamMath`, `FreecamPicker`, `FreecamOverlay`, `FreecamTouch`). A corrida cria com
  `Freecam.attach(...)` (null online ou sem permissão) e congela com `if ... _freecam.active: return` no `_process`.
- Liga: `-- --freecam`, F1, ou botão CÂMERA LIVRE da pausa. Permissão: `FreecamMath.allowed(online, debug, Settings.explorer_mode, flag)`.
- Mira = raio contra triângulos (`TriangleMesh.intersect_ray`), sem física. Malha nova copiada de um .glb: ponha
  `out.resource_name = path` para a mira mostrar o arquivo (`GlbMesh.source_of`).
- **Armadilha (headless)**: sem tela o `MultiMesh` não guarda a posição de cada cópia (`get_instance_transform` volta identidade,
  `get_aabb` vazio). Teste com a posição do próprio nó ou numa janela.
- Script `-s` que cita classe que usa autoload (Settings, AudioBus) com tipo estático não compila (autoloads ainda não existem):
  use variáveis sem tipo nesses scripts de sonda, ou carregue a cena em tempo de execução.
- Testes: `-- --only=freecam` (`tests/test_freecam.gd`, IN_TREE).

## Carro acidentado (T-183)

- Regra na sim: `sim/wreck.gd` (`Wreck.footprint(c)` = retângulo do corpo GIRADO, pivô no eixo traseiro = `TrackPath.REAR_AXLE`;
  use isso, e não `c.x`/`c.lane`, para saber se um acidentado ocupa uma faixa). `TrafficSim.Car.wrecked`/`crash_t`.
  O que o carro do trânsito enxerga: `sim/traffic_look.gd`. Bots: `BotDriver._obstacle_ahead` marca `"wreck": true`.
- Rect2 é float32: nas contas de carro NORMAL continue usando os floats (`c.z`, `c.length`), senão os números mudam.
- Visual só lê o estado: `road3d/wreck_fx.gd` (pisca no ritmo `SignalBlink`, fumaça por `crash_t`, triângulo quando o
  carro fica parado 0,3 s — a sim anda a 30/s, um quadro parado não basta).
- `--demo=crash --cam=wreck` (câmera no acidentado) e linhas `ACIDENTADO` no console; `tools/capture_t183.sh`;
  `tools_dev/trace_wreck.gd` (sem tela, roda também no código antigo: lê campos novos com `get()`).
- Testes `-- --only=wreck`. Snapshot: 1 byte por carro (protocolo 8).

## Biblioteca de cenário: bosques, LOD, pessoas (T-186)

- Árvores: `road3d/roadside_trees.gd` (`RoadsideTrees.place`, puro, mistura por bioma em `MIX`) + `Roadside3D` desenha. Modelo
  com `<nome>_lod1.glb` ganha 2 MultiMesh por bloco (perto até `TREE_LOD_M` = 140 m, leve até 450). Flags: `--old-trees`,
  `--old-lamps`, `--no-people`, `--no-tree-lod`. Gleditsia nova: `BackdropKit.tree_mesh_of(nome, tod)` (atlas `<nome>_leaves.png`).
- **Armadilha (visibility_range)**: a distância é medida até o CENTRO do AABB do nó. Um MultiMesh com cópias espalhadas
  pela rota inteira (ex.: pessoas do pedágio em 150 m + do viaduto em 2.580 m) tem centro no meio da pista e some sempre.
  Um grupo (nó) por lugar.
- **Armadilha (MultiMesh no Compatibility)**: `use_custom_data = true` SEM `use_colors` faz os dados da cópia chegarem
  ao shader como `COLOR` (a cor por vértice some). Ligue `use_colors` e ponha `Color.WHITE` em cada cópia (`PeopleKit.group`).
- Prints da câmera livre sem teclado: `-- --freecam --freecam-tour=PASTA --tour=nome@km,lateral,altura,giro,inclinacao;...`
  (`debug/freecam_tour.gd`; giro positivo = para a esquerda); imprime `TOUR rota pose km draw tri fps`. Script pronto:
  `tools/capture_t186.sh`. Testes `-- --only=scenery_t186`.

## Cenário trecho-piloto (T-188)

- Opção da corrida (depois de `--`): `--t188=off|segment|all` (código em `game/scripts/road3d/scenic_zone.gd`).
  - `all`: **padrão desde a T-192** (etapa 2 aprovada): cenário novo na rota inteira.
  - `segment`: só o antigo trecho-piloto (`ScenicZone.pilot(rota)`), para comparar com os prints da T-188.
  - `off`: volta ao visual antigo em todas as rotas (use para os "antes" das capturas e medições).
- T-192 (rota inteira): prints `bash tools/capture_t192.sh PASTA [day night] [-- extras]` (8 poses por rota: início,
  emendas, túneis, ponte, viaduto antigo, fim, pintura do asfalto), folhas `bash tools/sheet_t192.sh`, custo em 3 pontos
  por rota (média Compatibility x Ultra) `bash tools/measure_t192.sh [QUADROS=3000] [day|night]`
  (`MEASURE_EXTRA="--t188=segment"` = antes; `MEASURE_Q=media` só a média). Testes `-- --only=scenery_t192`.
- **Armadilha (medida)**: na qualidade média o PC passa de 200 FPS; com poucos quadros (`--quit-after 1200`) a corrida
  acaba antes da 1a média de 5 s e não sai nenhuma linha `FPS medio`. Use 3000 quadros.
- **Armadilha (pintura do asfalto)**: as curvas guardam `curve` em float32; `0.9 >= SHARP_CURVE (0.9)` dá falso. Curva
  de 0,9 não ganha "速度落とせ/80" (só as de 1,0 ou mais).
- Árvores por código (T-192): `BackdropKit.FOLIAGE` + `is_card_tree(nome)` decidem quem usa o material de cartões; o
  MultiMesh dessas árvores liga `use_colors` (tom por árvore, `Roadside3D.tree_tint`). Trocar o .glb exige
  `godot --headless --path game --import` antes de rodar o jogo.
- Capturas (precisam de janela, sem `--headless`): `GODOT=... bash tools/capture_t188.sh PASTA [day night] [-- extras]`. Para o "antes": `bash tools/capture_t188.sh PASTA_ANTES day night -- --t188=off`.
- Folhas antes | depois: `bash tools/sheet_t188.sh [PASTA]` (usa `PASTA/antes` e `PASTA/depois`; padrão `docs/capturas_t188`).
- Custo: `GODOT=... bash tools/measure_t188.sh [QUADROS] [day|night]`. Para o "antes": `MEASURE_EXTRA="--t188=off" bash tools/measure_t188.sh [QUADROS] [day|night]`.
- Testes: `godot --headless --path game -s res://tests/run_tests.gd -- --only=scenery_t188` (`tests/test_scenery_t188.gd`).
- Log: ao montar a rota, `scenic_stretch.gd` imprime no console uma linha `SCENIC_T188 <rota> zona=... terreno=... tri cordilheira=... floresta=... predios=...`.
- **Armadilha 1 (MultiMeshInstance3D vazio)**: um `MultiMeshInstance3D` sem `multimesh` (ou com `multimesh.mesh` nulo) quebrava `_print_surface_budget` (`race_scene_3d.gd`). Hoje isso já está protegido; se a contagem de superfícies falhar de novo, confira esse nó primeiro.
- **Armadilha 2 (cores do terreno)**: as cores do shader do terreno (`scenic_shaders.gd`, `TERRAIN`) precisam ser bem escuras, porque as cores são sRGB. A noite também precisa do `night_lift` (uniform do shader, luz de lua), porque o céu noturno é escuro demais para iluminar o terreno.



## PC Forward+ / Ultra e vida do cenário (T-189)

- PC = Forward+ (padrão do 4.7: o editor APAGA `renderer/rendering_method` do `project.godot`; sem a linha = Forward+),
  celular = `rendering_method.mobile="gl_compatibility"`. Tudo que é só Forward+ (SDFGI, SSR, névoa volumétrica, Decal,
  FSR2) passa por `UltraLook.available()` / `UltraLook.active(q)` (`road3d/ultra_look.gd`). Qualidade 3 = Ultra.
- Simular o celular no PC: `godot --path game --rendering-method gl_compatibility ... -- --quality=1 --life=off`.
- Vida do cenário: `road3d/race_life.gd` (atrás de `Settings.fx_life`, desligado no celular por padrão). Nunca entra na
  sim nem na rede. Novo efeito de partícula: pool perto do jogador (`LifeEmitters`), não um emissor por fonte.
- Vento: `LifeWind.apply(roadside)` troca a malha de cada MultiMesh de árvore por uma CÓPIA com shader (o .glb em cache
  fica intacto). Não chame funções de `convert` etc.: `convert` é função global do GDScript (erro de parse).
- `--rain`/`--no-rain`, `--life=on|off`, `--motion-blur` (não gravam). As opções salvas no PC do Marco podem ter chuva
  ligada: nas capturas passe `--no-rain`.
- Captura que às vezes não grava nenhum quadro: rode de novo (o `tools/capture_t189.sh` já tenta 2 vezes).

## Modelos novos de docs/Modelos (T-193)

- Trens: `RailTraffic.make_train(tipo, rng)` sorteia locomotiva (`LOCOS`) e 6–9 vagões (`WAGON_POOL`); comprimento por
  modelo em `RailTraffic.LENS`. Modelo novo de trem precisa entrar em `Trains3D.MODELS` (o teste `railway` acusa).
- Prédios texturizados: `road3d/city_models.gd` (`CityModels`, chamado por `CityBlocks._building`): 1 malha por trecho de
  250 m até `LOD_M` (420 m), depois caixas. `--no-city-models` desliga (também o skyline). Linha `SCENIC_T188 ... modelos_t193=N (tri)`.
- Neon: `NeonSigns` tem 2º atlas (`neon_t193_atlas.png`, filho "NeonT193"); 1 em 3 letreiros, sem número aleatório extra.
- Carro único: `road3d/unique_car.gd` (`UniqueCar.spot_z`, `--no-unique-car`, linha `UNIQUE_T193 rota z=... lateral=...`);
  sonda `godot --headless --path game -s res://tools_dev/probe_unique_t193.gd`.
- Prints: `bash tools/capture_t193.sh PASTA [day night] [-- extras]`; folha dos modelos `tools_dev/model_sheet_t193.gd` (janela).
- Testes `-- --only=scenery_t193`.
- **Armadilha (RoadMesh.sound_wall_at)**: o viaduto da cidade tem muro de som em blocos alternados de 300 m; o que fica
  ao lado, no chão, só aparece da pista onde não há muro.

## Som do motor e do bonde (T-197)

- Motor = **diesel sintetizado** (`tools/synth_truck_audio.py`, numpy do sistema): loops `syn_<voz>_<on|off|jake|open>_<rpm>.wav`
  com chunk `smpl` (o Godot importa já em loop; `AudioBus` também liga o loop de `.wav` sem `smpl` pelo nome). Regras de
  mistura em `audio/diesel_mix.gd` (puras); `EngineAudio` usa o ramo diesel quando o spec tem `"voice"`.
  Camadas diesel são "preguiçosas" (só tocam com peso > 0): teste com `active_layers()` (volume), não `playing`
  (no executor de testes os nós não tocam: "Playback can only happen when a node is inside the scene tree").
- Som antigo (ElevenLabs): `EngineSounds.spec(..., legacy = true)` ou `-- --engine-sound=old`; arquivos sintetizados ausentes = antigo.
- Troca de marcha vista pelo áudio: RPM caindo > 1500 rpm/s com o pé no fundo (sem tocar na sim). Doppler dos rivais/bonde
  é feito à mão (`DieselMix.doppler`, ±6%), não pelo `doppler_tracking` do Godot (cortes de câmera dariam pulos).
- **Gravar o som exato do jogo**: Movie Maker com janela (headless trava): `godot --path game --write-movie X.png
  --fixed-fps 30 CENA -- ...` grava `X.wav` (32 bits estéreo 48 kHz) + um PNG por quadro. Script pronto:
  `tools/render_t197_audio.sh`; análise/espectrograma: `tools/audio_t197_report.py` (Python do sistema).
- O executor de testes não roda o `_ready` dos autoloads: para barramentos novos chame `AudioBus._setup_buses()` no teste.

## Som do motor procedural e análise (T-220)

- Diesel procedural = `audio/diesel_synth.gd` (`DieselSynth`, puro: `render(frames, rpm, load, health)`, conta `fired`/
  `misfires` para teste) + `audio/engine_synth_voice.gd` (`EngineSynthVoice`, AudioStreamGenerator; ressonâncias como
  efeitos do barramento `EngineSynth`, em C++: em GDScript seriam ~1 ms por quadro). Voz = `EngineVoiceDef`
  (`data/audio/voice_<voz>.tres`; sem arquivo = loops). Modo = `EngineSoundMode` (`loops|synth|mix`).
- **Armadilha**: o perfil do PC pode ser o Canter (voz `i4`): para testar o 6 cil. na corrida use
  `--decorated --body=base` (perfil de demonstração). `--synth-log` imprime `ENGINE_SOUND voz=.. modo=..` e `SYNTH_CPU`.
- Gerador só enche dentro da árvore e com janela; nos testes use `DieselSynth` direto. Custo: `tools_dev/bench_engine_synth.gd`.
- Ver o espectro de um WAV sem ouvir: `tools/audio_t220_analyze.py` (loops: fundamental × rpm/20), `tools/audio_t220_compare.py`
  (rampa gravada: fundamental ao longo do tempo e "periodicidade" 200 Hz–4 kHz; 1 = toda explosão igual). Gráficos com
  `tools/audio_plot.py` (fonte 5×7 e PNG só com numpy). Excitação sem os efeitos: `tools_dev/render_engine_synth.gd -- --out=ABS.wav --set=campo:valor`.
- Gravação real → loop: `tools/cut_loops.py` (lê mp3/flac pelo Blender). Saída `rec_<voz>_<on|off>_<rpm>.wav`; o jogo só usa
  quando os 10 existem (`EngineAudio.recordings_complete`).

## Chegada "infinita", trem do Marco e serrilhado (T-195)

- **Continuação só visual depois da chegada**: `TrackPath.new(track, ArrivalLayout.runout(rota))` estende a linha
  central ~1 km (`ArrivalLayout.RUNOUT`: reta, curva, reta). `path.track` continua sendo a pista da SIM: quem distribui
  coisas pela rota usa `track.length_m` (nada muda antes da chegada). Quem desenha a continuação usa `path.end_m()`,
  `path.seg_total()` e `path.curve_seg(i)`: RoadMesh, TerrainField/TerrainPatch, ViaductPiers3D, câmera livre e
  `ArrivalCity` (pórtico ゴール/CHEGADA, quarteirões via `CityBlocks.force_city/sides`, postes via
  `Roadside3D.extra_objects`, prédio-portal, skyline, faixas largas de chão). `--no-arrival` = fim antigo.
  Linha no console: `ARRIVAL_T195 rota fim=... continuacao=... predios=... skyline=...`. Teste `-- --only=scenery_t195`.
- **Armadilha (chão plano grande)**: um disco plano na altura do fim da rota cortava os morros da montanha no meio da
  rota (as rotas sobem e descem). Chão extra tem que seguir a estrada (faixas por `path.world_point`).
- **Armadilha (Roadside3D.extra_objects)**: só objetos que NÃO sorteiam (postes). Árvores consomem o `rng` e mudariam
  arbustos/pedras da rota inteira (`_extras` roda depois).
- Trem do Marco = `train_loco_b` (docs/Modelos/train): `build_t193_rail.py -- --only train_loco_b` (dissolve planar +
  redução só nos truques abaixo de `LOCO_LOW_Z`; pintura em faixas pela altura na célula 32 do `rail_atlas.png`, escrita
  pelo próprio script). Lidera o 1º trem de cada rota e o do cruzamento; 75% dos demais (`RailTraffic.LEAD_MARCO`).
- Antisserrilhado: `UltraLook.MSAA_BY_QUALITY` (baixa 0, média 2x, alta 4x; Ultra = FSR2). Folhas/cartões/treliça com
  alpha-to-coverage (StandardMaterial: `alpha_antialiasing_mode`; shader: `ALPHA_ANTIALIASING_EDGE` +
  `ALPHA_TEXTURE_COORDINATE`). Depuração/medida: `--msaa=0|2|4`. Sem Ultra o asfalto molhado não usa textura de
  rugosidade (`RoadMesh.soft_spec`): era o "chuvisco" de pontos brilhantes à noite (aliasing especular).
- Prints: `bash tools/capture_t195.sh PASTA chegada|unico|serra|trem [day night]` (`Q=3` = Ultra); custo
  `bash tools/measure_t195.sh` (`MEASURE_EXTRA="--msaa=0 --no-arrival"` = antes). Um processo por vez (memória).

## Câmeras da corrida e retrovisor (T-198)

- Só apresentação: `road3d/race_cam_rig.gd` (modos, limite pela geometria, blend, órbita), `race_cam_director.gd`
  (tomadas do cinema), `race_cam_view.gd` (cola: teclas, letterbox, opções), `rear_mirror.gd` (SubViewport),
  `ui/race_cam_button.gd`. O `race_scene_3d` só chama `_camv`. A PADRÃO usa os números de sempre (não é limitada).
- Pose montada em coordenadas da pista `Vector3(z, lateral_m, altura)` → `RaceCamRig.clamp_point` (mureta e trechos de
  2 faixas via `LaneSections.profile`, túnel com descida suave perto da boca, fora do baú do jogador) → `to_world`.
- Flags (não gravam nas opções): `--race-cam=near|standard|far|cinema|orbit`, `--mirror=on|off`, `--cine-shot=NOME`
  (side_low, front_low, tele_rear, crane, rival, overtake), `--letterbox=off`.
- Retrovisor: SubViewport compartilha o World3D; câmera com `environment` cópia leve (sem SSAO/SSIL/SSR/SDFGI/névoa
  volumétrica), sem sombra de poste (`positional_shadow_atlas_size = 0`), `far` 260 m, atualização `UPDATE_ONCE` a
  25 fps (30 no Ultra). Efeito preso na câmera principal (chuva, folhas, borrão) vai para a camada 20 com
  `RearMirror.hide_from_mirror(_cam)`: senão aparece como retângulo flutuando no espelho.
- Botão de HUD clicável: `_gui_input` com `InputEventMouseButton` (o toque chega como clique emulado; não trate os dois).
- Testes que mexem na câmera da corrida de verdade: ponha `_camv._save = false` (senão grava no settings.cfg do jogador).
- Prints `bash tools/capture_t198.sh PASTA [day night]` (`CAMS=`, `ROUTE=`, `Q=`), folha `bash tools/sheet_t198.sh`,
  custo `bash tools/measure_t198.sh [3000] [night]` (`CASES="standard:off standard:on ..."`). Um processo por vez.

## Polimento do cenário (T-199)

- Detalhes dos prédios/casas: `road3d/city_details.gd` (`CityDetails`, RNG próprio: lotes e prédios da `CityBlocks`
  não mudam). Caixas em MultiMesh por trecho de 200 m: camada PERTO (ar-condicionado, varandas, escadas de incêndio,
  marquises, letreiros verticais; some a 360 m) e LONGE (beiral, rodapé, antenas; 1,1 km). Material `CityLook.props`.
- Beira da pista: `road3d/road_details.gd` (`RoadDetails.add`, chamado no fim do `RoadFurniture.build`): juntas da
  mureta, refletores do guard-rail do litoral, marcos de km (dígitos do `SignAtlas` via `RoadFurniture.faces_layer()`),
  telefones de emergência, pichações discretas (Label3D até 140 m).
- Gleditsias: `road3d/tree_crown.gd` (`TreeCrown.thicken`) duplica os cartões de folha girados e encolhidos dentro do
  mesmo surface (sem chamada nova). Retrato do duelo: `ui/duel_bust.gd` desenha rosto/óculos/hachimaki/gola por cima.
- **Armadilha (textura sem mipmap)**: textura 3D importada com `mipmaps/generate=false` (o `detect_3d` só converte no
  editor, não no `--import` sem tela) vira grão/chuvisco à distância. Toda textura de chão/parede/folha precisa
  `mipmaps/generate=true` no `.import` (T-199 corrigiu asfalto, grama, areia, concreto, folhas).
- Glow: na noite o limiar é 1,1 (`night.tres`); nível 5 do glow 0,55 na média, Ultra 4=0,45/6=0,25 (antes halos enormes).
- Prints sem painel: `--tour-clean` na câmera livre; `bash tools/capture_t199.sh PASTA [day night]` (`Q=3` Ultra,
  `ROUTES=`, `POSES=`), folhas `bash tools/sheet_t199.sh` (`GRID=rota/hora` = grade rápida). Testes `-- --only=scenery_t199`.

## HUD da corrida (T-202)

- Código em `game/scripts/ui/hud/`; `RaceHud` (`ui/race_hud.gd`) só monta, posiciona (`HudLayout`) e copia o estado
  (`_feed`). Contas puras testáveis sem tela: `GaugeNeedle` (ângulo/agulha), `HudStatus` (5 segmentos, pisca-alerta),
  `RadarModel` (radar), `HudLayout` (onde cada peça vai; recebe `TouchControls.button_layout(size, escala)`).
- Peça nova no HUD: desenhe em unidades locais com fonte de tamanho FIXO e escale o nó inteiro (`scale`), como o
  `SpeedGauge`; coloque o retângulo em `HudLayout` e um caso no `test_hud_t202.gd` (sem sobrepor nada, longe dos botões).
- Texto claro sobre a pista some em cima da faixa branca: dê sombra/fundo escuro (ex.: rótulos dos segmentos).
  `draw_string` com largura limitada CORTA o texto ("FRENT"): centralize à mão com `HudStyle.text_width`.
- Capturas (janela): `GODOT=... bash tools/capture_t202.sh PASTA [casos]`; flags `--window=2400x1080` (janela maior que o
  monitor), `--no-touch`/`--touch`, `--hud-scale=1.25`, `--safe-area=L,T,R,B`, `--hud-demo`. Recorte ampliado sem tela:
  `-s res://tools_dev/crop_image.gd -- --in=ABS --out=ABS --rect=x,y,w,h --zoom=2`. Testes `-- --only=hud_`.
- Dano das peças fica salvo no perfil entre corridas: segmento amarelo numa corrida normal pode ser dano real.

## Pedágio com física (T-207)

- Sim: `sim/toll_plaza.gd` (geometria pura: ilha `nose_z..tail_z` em |x| < 1,8 m, funil `outer_face_m(z)`, zebra `gore(z)`, tabelas
  `block_z/clear_z` por faixa) e `sim/toll_contact.gd` (chamado no fim de `EventContact.truck/car/wall_x`). Fica em `TrackEvents.toll`,
  FORA de `list` (índices dos eventos, `to_array` e HUD de avisos não mudam); `lane_blocked_between`, `next_block`, `is_empty` enxergam.
  `Track.set_toll(z)` (z < 0 tira); `RouteDef.build_track` põe em 150 m. Contato com `"event": -1` → evento `event_obstacle/scrape`
  com `"event": "toll"`. Pista de teste própria: `Track.new()` + `add_section` + `set_toll(150)` (`make_test_track` NÃO tem pedágio).
- Teste que mede curvas nas rotas inteiras precisa ignorar a praça (troca de faixa forçada perto da largada): ver `_measured` em
  `tests/test_lane_following.gd`.
- Visual: `road3d/toll_plaza_3d.gd` monta com `TollGeo` (quads com normal própria, UV do atlas ou métrica; `fp` = quadro rígido no centro
  da cabine, `rp` = na pista) em 5 materiais (atlas, concrete, paint, band, glow). Atlas `TollAtlas` gerado por
  `tools_dev/make_toll_atlas.gd` (janela; depois `--import` e conferir `compress/mode=2`, `mipmaps/generate=true` no `.import`).
- **Armadilha (Compatibility)**: `emission_texture` do StandardMaterial é ignorada: a emissão sai lisa e branqueia o que for colorido.
  Emissão só em material de cor única; o resto vai para um shader `unshaded` com a textura (`GLOW_SHADER`).
- Câmera: `RaceCamRig.toll_h_max(z)` limita a altura (5,6 m) perto da cobertura e do pórtico em TODOS os modos (inclusive a PADRÃO).
- Flags: `--no-toll` (sem a praça, sim e visual), `--old-toll` (só o visual antigo). Prints `tools/capture_t207.sh`, custo
  `tools/measure_t207.sh`, bots `tools_dev/trace_toll.gd --sweep`. Testes `-- --only=toll`.

## Peças da oficina: encaixes, cor L/R, dano sem buraco (T-211)

- `TruckSockets` (`truck/truck_sockets.gd`) lê `assets/vehicles/dekotora/truck/sockets/<modelo>.json` e cria os nós
  `SOCKET_<encaixe>` (TruckNode._ready). Peça do catálogo com `"socket"` monta ali com escala `TruckSockets.fit_scale`.
- Regras/teste: `PartFit` (`truck/part_fit.gd`), `tests/test_part_fit.gd` (todas as cabines × baús × peças),
  relatório `tools_dev/report_part_fit.gd` → `docs/REPORT_ENCAIXE.md`. Fora da árvore use `PartFit.aabb_in` (soma as
  transformações dos pais) em vez de `global_transform`.
- Cor/letreiro: `DecoStyle.apply(no, entrada, cor, celula)` ANTES de `AccessoryGlow`/`ChromeMatcap`/`LightPatterns`;
  `TruckNode.apply_loadout(defs, gs.part_styles())`. Cores em `data/deco_colors/*.tres` (`DecoColorDef`); `.tres` não
  aceita `Color("#hex")`: use `Color(r, g, b, a)`.
- Perfil `part_style` {id: {color, sign}}; ações `set_part_color` ("id:cor") e `set_part_sign` ("id:n"); descritor com
  `style` por peça (protocolo 12). Garagem: `ui/garage_deco_style.gd`. Vista `top` na garagem (`--view=top`).

## Assento real, luzes e deque de 2 níveis (T-214/T-215)

- Encaixe `fit: "seat"` (deque/viseira): `AccessoryCatalog.attach` chama `SocketSeat.seat` (grades do `<modelo>.surf.json`).
  Nós `SEAT_*` (assento/enchimento) são criados no jogo com material `deco_trim`/`deco_body` (o `DecoStyle` pinta).
- Teste de contato por raios: `PartFitSeat.problems` (TriangleMesh do caminhão sem rodas/peças). `PartFit.aabb_in` usa os
  vértices quando a peça está inclinada/cisalhada (a AABB girada "incha" e reprovava à toa).
- Sondas: `tools_dev/probe_seat_t214.gd -- --model=STEM --part=ID [--corner=x,z]`, `tools_dev/probe_pitch_t214.gd`.
  Prints de perto sem a garagem (janela): `tools_dev/shot_fit_t214.gd -- --body= --cab= --parts=a,b,c --top=ID
  --view=q34|side|front|back [--night] [--led=id:luz] --out=ABS.png` (monta no 2º quadro: no `_initialize` os nós ainda
  não estão na árvore e o `TruckNode._ready` não rodou).
- Luzes: `DecoLightDef` (`data/deco_lights/`), perfil `part_style.led/neon`, `GameState.set_part_light`. LED usa material
  `lamp_x@lens` (`LightPatterns.LENS_SUFFIX`, uniform `lens`); use `LightPatterns.is_animated(nome)` em vez de `ANIMATED.has`.
- Peças fora de linha: `RetiredParts` (migração com reembolso em `GameState._retire_old_parts`, idempotente).
- 2º nível: perfil `installed.andon_top`, `GameState.stack_ok/install_top/stack_candidates`, estilo `top: true` (cópia em
  `part_styles()` e no descritor), `TruckNode._mount_top`. "Cabe" = tabela `truck/stack_fit.json` (StackFit); mudou peça do
  deque, encaixe ou caminhão: `godot --headless --path game -s res://tools_dev/gen_stack_fit.gd` (o teste acusa se esquecer).
- T-216: canhões embaixo + caixa em cima = `StackArrange` (canhões 0,24 m à frente, caixa recua onde a viseira não deixa,
  pés `SEAT_post_*` atrás). Sonda: `tools_dev/probe_stack_t216.gd -- --model=STEM --lower=ID --upper=ID`.

## Ambientação (T-217)

- Flags da corrida (depois de `--`), código em `game/scripts/road3d/` (usadas para os "antes" das capturas e medições):
  - `--no-opposite`: sem a pista contrária (`OppositeLayout.enabled()`, `opposite_layout.gd`).
  - `--no-opp-traffic`: sem os carros da pista contrária; a estrada continua (`route_ambience.gd`).
  - `--no-opp-road`: sem a estrada da pista contrária; **também tira o tráfego**, porque o tráfego é criado dentro desse ramo (`route_ambience.gd`).
  - `--no-walls`: sem os muros de pedra dos cortes (`CutLayout.enabled()`, `cut_layout.gd`).
  - `--no-danchi`: sem os blocos de conjunto habitacional (`DanchiLayout.enabled()`, `danchi_layout.gd`).
  - `--no-landmarks`: sem os marcos de identidade de cada rota (`RouteLandmarks.enabled()`, `route_landmarks.gd`).
  - `--no-signs-t217`: sem as placas novas da T-217 (`SignsT217`, `route_ambience.gd`); as placas antigas continuam.
  - `--old-forest`: volta à floresta antiga; usa 1 tentativa de árvore por trecho (`slope_forest.gd`).
  - `--old-lamps`: volta ao poste antigo (`lamp_post`) em vez do poste de braço curvo (`roadside_3d.gd`, `lamp_model`).
  - `--no-exposure`: desliga a adaptação de exposição, só no Ultra (`exposure_adapt.gd`).
  - `--opp-near=a,b`: medição; define a faixa (em metros, à frente da câmera) em que os carros usam o modelo completo; fora dela entram os proxies. `0,0` deixa só os proxies (`opposite_traffic_3d.gd`).
- Registros por pista (static, por caminho da pista): `OppositeLayout.of(path)`, `CutLayout.of(path)`, `DanchiLayout.of(path)`.
  Quem registra é `RouteAmbience.prepare` (antes dos outros construtores); `of(path)` devolve `null` quando não há.
  Tudo é limpo por `RouteAmbience.release()` (chama os três `clear_all()`), que roda no `_exit_tree` de `race_scene_3d.gd`,
  para as tabelas não vazarem para outra cena ou teste.
- **Armadilha (MultiMesh)**: `visible_instance_count = 0` ainda desenha 1 cópia no renderizador Compatibility: esconda o nó (`visible = false`).
- Capturas (precisa de janela, sem `--headless`; **rode um processo Godot por vez** para não estourar a memória do PC):
  - `bash tools/capture_t217.sh PASTA [day night] [-- extras]`: prints com as mesmas poses antes/depois, câmera livre sem painel (`--tour-clean`).
    Lê o topo do script para o uso: `Q=3` = Ultra, `ROUTES=` e `POSES=` filtram rota e pose, `GAME=` aponta para outra pasta (o "antes" usa um worktree).
  - `bash tools/measure_t217.sh [QUADROS=3000] [day|night] [RES=1280x720]`: FPS médio, chamadas e triângulos em 6 pontos das 3 rotas, corrida de verdade.
    `MEASURE_EXTRA="--no-opposite ..."` para medir o antes; `MEASURE_Q="media ultra"` mede as duas qualidades (padrão só a média).
- Texturas novas de cenário 3D: `bash tools/import_textures_3d.sh [PASTA_res ...]` (padrão `game/assets/textures/t217`). Põe VRAM (`compress/mode=2`),
  mipmaps e mapa de normais nos arquivos `*_nrm*`/`*_normal*`, e roda `--import`. Sem isso a textura vira grão à distância (T-199).
- Todos os scripts usam `GODOT=` para apontar o executável (padrão `/d/DEV/Godot/Godot_v4.7.2-stable_win64.exe`).

## Caminhões de homenagem (T-218)

- `--rival-body=ID` (depois de `--`): força o modelo do rival na corrida (`game/scenes/race/race3d.tscn`, `race_scene_3d.gd`,
  função `_bot_body`). Sem a flag, o rival da rota usa o dele ou sorteia entre `RIVAL_POOL`.
- `--demo --body=ID`: na garagem (`garage_debug.gd`), compra o modelo no perfil de teste (`user://demo_profile.json`) se não
  for dono, e monta com a cor de fábrica. Nunca grava no perfil real.
- Testes da T-218: `godot --headless --path game -s res://tests/run_tests.gd -- --only=homage` roda só
  `game/tests/test_homage_t218.gd` (o filtro `--only=` casa com o trecho do nome do arquivo).

## Peso do caminhão (T-219)

- Dados: `TruckFeel` (`game/scripts/data/truck_feel.gd`), valores em `game/data/feel/truck_feel.tres`.
  `TruckFeel.current()` devolve o que está em uso; `TruckFeel.use(f)` troca; `TruckFeel.legacy()` devolve os números de antes (comparação).
- Campos `sim_*` mudam a simulação: exigem subir o protocolo de rede (hoje 15, `game/scripts/net/protocol.gd`) e APK novo.
  Os demais campos são só visual, som ou haptic.
- Visual: `RaceFeel` (`game/scripts/road3d/race_feel.gd`); `TruckMotion` (`game/scripts/truck/truck_motion.gd`) calcula
  rolagem, cabeceio e emendas; `TruckNode.set_body_motion` aplica no modelo; `TruckWheels.apply` compensa as rodas para ficarem no chão.
- Haptics: `game/scripts/input/haptics.gd` (duração escalada pelo feel).
- Flags da corrida: `--feel-log=ARQ.csv` (telemetria por quadro); `--reduce-shake` (tremor reduzido, depuração, não grava).
- `measure_duel` (`game/tools_dev/measure_duel.gd`): `--feel=legacy`, `--feel-set=campo=valor,campo=valor`, `--no-hysteresis`,
  `--modes=1x1` (modos: `antigo`, `1x1_old`, `1x1`).
- Captura: `bash tools/capture_t219.sh PASTA_ABS [casos]` (casos: `crash lanes crash_lado brake_lado`).
  Gráfico: `godot --path game -s res://tools_dev/plot_feel_t219.gd -- --out=ABS.png`.
- Armadilha: `-s` com janela precisa de `root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED`, senão o desenho sai esticado.
- Armadilha: Movie Maker grava em D: (o C: fica sem espaço; cada caso gera ~450 MB de PNG).
- Pendência: `tools/capture_t219.sh` passa `--feel=res://...` via `EXTRA`, mas a corrida ainda não lê esse flag (só `measure_duel` lê `--feel=legacy`).
