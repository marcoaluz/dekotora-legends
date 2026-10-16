# Arquitetura técnica

Este documento diz **como o código é organizado**. O "o quê" do jogo está no `GDD.md`.

## Princípio central: simulação separada do visual

```
            comandos (input)                 estado
Jogador ──► InputSource ──► [ SIMULAÇÃO ] ──► RaceState ──► [ APRESENTAÇÃO ] ──► tela + som
                              sim/*.gd                       road/, truck/, ui/, audio/
```

- A **simulação** (`game/scripts/sim/`) é código puro: recebe comandos e `dt`, atualiza números.
  Não desenha, não toca som, não lê `Input`.
- A **apresentação** lê o estado e desenha a estrada, os sprites, o HUD e toca o áudio.
- No single-player, a simulação roda no próprio aparelho.
- No multiplayer, a **mesma** simulação roda no servidor; o aparelho só envia comandos e desenha o
  estado que chega (com predição do próprio caminhão, ver `MULTIPLAYER.md`).

## Modelo de mundo (pseudo-3D)

A pista é uma lista de **segmentos** de comprimento fixo (ex.: 2 m). Cada caminhão é descrito por:

| Campo | Tipo | Significado |
| --- | --- | --- |
| `z` | float | Distância percorrida na pista, em metros |
| `x` | float | Posição lateral: −1 = borda esquerda, +1 = borda direita (fora disso = acostamento) |
| `speed` | float | m/s ao longo da pista |
| `lateral_vel` | float | Velocidade lateral (para empurrões) |
| `rpm`, `gear`, `boost` | float/int | Estado do motor e turbo |
| `damage` | dict | Durabilidade atual por peça e por sistema (motor, direção, carga) |

Cada segmento guarda `curve` (quanto a pista vira), `hill` (subida/descida) e objetos de beira de estrada.
A curva **empurra** o caminhão para fora (`x` varia com `curve × speed²`), o jogador compensa virando.

Colisão entre caminhões é testada só entre vizinhos próximos em `z`: se a distância em `z` < comprimento
do caminhão e a distância em `x` < largura, há contato. O lado do contato define a **zona** atingida.

## Pastas e scripts

```
game/
  project.godot
  scenes/
    main.tscn               ponto de entrada, carrega o menu
    menu/                   menu principal, opções
    garage/                 garagem
    race/race.tscn          corrida (estrada + HUD)
    lobby/                  salas multiplayer
    results/                tela de resultado
  scripts/
    autoload/
      game_state.gd         perfil, dinheiro, Fama, garagem (singleton)
      settings.gd           opções do jogador (som, controle, idioma)
      net.gd                conexão com o servidor (singleton)
      audio_bus.gd          música e efeitos globais
    sim/                    *** SEM render, SEM Input ***
      race_sim.gd           avança a corrida um tick: todos os caminhões + tráfego
      truck_sim.gd          física de um caminhão (motor, marcha, peso, curva)
      engine_model.gd       curva de torque, RPM, turbo
      collision.gd          contato entre caminhões e tráfego, impulso, zona
      damage_model.gd       distribui dano por zona → peças → mecânica → carga
      traffic_sim.gd        carros comuns
      bot_driver.gd         IA dos bots (gera comandos como um jogador)
      track.gd              segmentos da rota, carregados de data/routes
      commands.gd           struct dos comandos (steer, throttle, brake, passing)
      race_state.gd         estado serializável da corrida (para rede)
    road/
      road_renderer.gd      desenha a pista pseudo-3D e posiciona sprites por profundidade
      parallax_bg.gd        céu, montanhas, cidade
      sprite_projector.gd   converte (x, z) em posição/escala na tela
    truck/
      truck_view.gd         monta o caminhão em camadas (base + peças + estado de dano)
      fx_view.gd            fumaça, faíscas, peças voando
    input/
      local_input.gd        touch, teclado e controle → Commands
      touch_controls.tscn   botões na tela
    audio/
      engine_audio.gd       mistura de loops por RPM + turbo + freio-motor
      sfx_player.gd         efeitos pontuais
    ui/                     HUD, menus, garagem
    net/
      server_main.gd        entrada do servidor headless
      room.gd               uma sala: jogadores, regras, corrida
      snapshot.gd           empacota/desempacota RaceState
      client_sync.gd        predição e interpolação no cliente
      profile_store.gd      perfis no servidor (um JSON por jogador)
  data/
    parts/*.tres            PartDef: slot, zona, peso, durabilidade, Fama, preço, sprites
    engines/*.tres          EngineDef / TurboDef / ExhaustDef
    routes/*.tres           RouteDef: segmentos, cenário, frete
    rivals/*.tres           RivalDef: nome, caminhão, estilo de IA
    i18n/                   textos de interface
  assets/
    sprites/ backgrounds/ ui/ fonts/ audio/
```

## Recursos de dados (Resources)

```gdscript
class_name PartDef extends Resource
@export var id: StringName
@export var slot: StringName          # front_bumper, visor, roof_lights, side_skirts, andon, rear_bumper, mural, hubcaps
@export var zone: StringName          # front, rear, left, right, roof, wheels, none
@export var weight_kg: float
@export var durability: float         # pontos de vida
@export var fame: int
@export var price: int
@export var sprite_dir: String        # res://assets/sprites/parts/<id>/
```

`EngineDef`, `TurboDef`, `ExhaustDef`, `RouteDef` e `RivalDef` seguem o mesmo padrão. Os valores
iniciais estão em `BALANCEAMENTO.md`.

## Tick e tempo

- Simulação em **passo fixo**: 30 ticks por segundo (`dt = 1/30`), igual no aparelho e no servidor.
- Apresentação a 60 FPS, interpolando entre os dois últimos ticks.

## Salvamento

- Fases 0–5: `user://profile.json` local (via `GameState`).
- Fase 6 em diante: perfil no servidor; o arquivo local vira cache. Ver `MULTIPLAYER.md`.

## Exportação

| Preset | Plataforma | Observação |
| --- | --- | --- |
| `Android` | AAB/APK arm64 | Renderer Compatibility, paisagem fixa |
| `Windows` | x86_64 | Janela redimensionável, escala inteira |
| `Server` | Linux x86_64 | `--headless`, sem assets visuais nem áudio (filtro de recursos) |

O mesmo projeto decide o modo pelo argumento de linha de comando: `--server` inicia `server_main.gd`.
