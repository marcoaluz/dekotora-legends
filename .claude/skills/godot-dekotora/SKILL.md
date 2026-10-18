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
