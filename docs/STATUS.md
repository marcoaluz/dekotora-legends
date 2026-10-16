# STATUS — contexto para retomar o trabalho (outra sessão/conta)

Atualize ao fim de CADA tarefa. Leia antes: `CLAUDE.md`, `docs/AGENTES.md`, `docs/ROADMAP.md`, `docs/DECISOES.md`.
Última atualização: **2026-10-16**. Todos os prompts P00–P81 foram executados até onde dá **sem o celular/contas do Marco**.

## Ambiente do PC do Marco (Windows 10, Git Bash + PowerShell)

- Godot 4.7.2: `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe` (fora do PATH). Modelos de exportação completos em
  `%APPDATA%\Godot\export_templates\4.7.2.stable` (extraídos de `D:\DEV\Godot\dl\*.tpz`).
- Blender 5.2.2 LTS: `D:\Blender\blender.exe` (fora do PATH). `bpy` + numpy OK.
- No bash: `source tools/env.sh` define `$GODOT` e `$BLENDER`.
- Projeto em `D:\DEV\dekotora-legends\dekotora-legends` (git local; **sem remoto GitHub** ainda; LFS ativo para mp3/ttf/blend).
- Android SDK / JDK 17: **não instalados** (bloqueia APK). Python do sistema não tem numpy/Pillow (use o Python do Blender, ver `tools/image_resize.py`).
- Chave da API de áudio: `.chaves.env` (ignorado pelo git; variáveis `ELEVENLABS_API_KEY`, `PIXELLAB_API_KEY`). Nunca imprimir o valor.
- **Ferramenta Bash do Claude Code**: comandos grandes com heredocs/aspas às vezes falham ("unexpected EOF"). Crie arquivos com a
  ferramenta Write e rode patches Python por arquivo. `rm -rf $VAR/*` é bloqueado: use `"${VAR:?}"/*`.

## Como validar tudo (o Marco pode rodar)

| O quê | Comando (na raiz do projeto) |
| --- | --- |
| Testes automáticos (84) | `godot --headless --path game -s res://tests/run_tests.gd` (código de saída 0 = passou) |
| Jogo (menu) | `godot --path game` |
| Corrida direto | `godot --path game res://scenes/race/race3d.tscn` (WASD/setas, Espaço = Passing, Esc = pausa) |
| Garagem | menu → GARAGEM (debug: `-- --demo --damage --tab=repair --slot=front_bumper`) |
| Demonstração dos acessórios | `godot --path game res://scenes/tools/accessory_viewer.tscn` |
| Som do motor | `godot --path game res://scenes/tools/engine_audio_test.tscn` |
| Multiplayer ponta a ponta | `bash tools/net_test.sh` e `bash tools/net_test.sh 150 0.02` |
| Servidor (PC) | `tools\run_server.bat` (guia: `docs/REDE_WIFI.md`) |
| Build Windows | `godot --headless --path game --export-release "Windows" ../builds/dekotora.exe` (testado: roda a corrida 3D com áudio) |

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

## PENDENTE — precisa do Marco

- Instalar **Android SDK + JDK 17** e gerar/testar o APK no celular (P02, P22, P65, P70, P72). Sem isso o Android não foi testado.
- **Olhar** as imagens (previews em `game/assets/vehicles/dekotora/previews/`, capturas em `docs/store/`) e **aprovar o visual** / escolher plano A ou B.
- **Ouvir** os áudios e pedir regeração dos ruins: `python tools/gen_audio.py --only nome --force` (lista: `python tools/gen_audio.py --list`).
- Jogar e ajustar equilíbrio (0–100 do caminhão padrão é 22 s; V8+turbo duplo 14 s; ver `docs/BALANCEAMENTO.md`).
- ~~GitHub~~ FEITO: `origin` = https://github.com/marcoaluz/dekotora-legends.git (push em 2026-10-16).
- **Arte do caminhão — 1ª rodada FEITA (2026-10-16)**: cabine arredondada (loft), grade/faróis/para-choque, chassi, tanques, eixos, rodas com pneu de sulcos, baú corrugado (código em `blender/scripts/truck3d/`). 2ª rodada feita: porta com contorno, para-lama, carenagem de teto, espelhos, vidros, para-choques com painéis coloridos, garagem com caminhão centralizado (painel direito some quando vazio), câmera da corrida mais alta/atrás. 3ª rodada (2026-10-16, referências em `docs/Textura/`): pneu com sulcos em V (geometria), baú de tábuas com montantes, grade e respiros de chapa perfurada e degraus de chapa xadrez (texturas procedurais em `lib/tex.py`, UV planar), vinco de cintura e juntas de painel; **4 modelos de baú** (`--variant base|leve|longo|carreta`, código em `truck3d/variants.py`: esticam/encolhem o meio do caminhão): baú leve 5,4 m (1 eixo), baú médio 8,2 m, baú longo 9,8 m (3 eixos) e carreta (cavalo + semirreboque ~17 m); escolhidos na garagem ("Modelo do caminhão", `profile.body`; rivais alternam base/leve/longo). Tanque e carroceria aberta foram descartados (Marco quer só baú). **Carreta guardada** (modelo pronto em `dekotora_truck_carreta.glb`, fora da lista da garagem por pedido do Marco). 4ª rodada (2026-10-16): **4 cabines** (`--cab padrao|classica|aero|alta`, `truck3d/cab.py`) combináveis com os 3 baús = 12 `.glb` (`dekotora_truck_<baú>[_<cabine>].glb`; gerar todos: `for v in base leve longo; for c in padrao classica aero alta: build_truck_3d.py -- --variant $v --cab $c --no-preview`), escolha na garagem (`profile.cab`); textura de sujeira discreta na pintura (`paint_white_panel`) e chapas perfuradas; **UI nova**: tema moderno (`ui_theme.gd`: sliders, interruptores, botões de menu), tela de Opções com categorias e rolagem (`options_panel.gd`, corrigido o corte da tela), menu principal redesenhado; ambiente em hora azul/entardecer com tom menos saturado. **UI premium (referências em `docs/Ult/`)**: etapa B feita (fonte Rajdhani + ícones Lucide em `assets/ui/icons`, licenças em `assets/LICENCAS.md`; componentes em `scripts/ui/components/ui_kit.gd`; transição `SceneFader`); etapa C feita (tela inicial: Continuar = próximo frete liberado, Nova carreira com confirmação, Mercado de fretes = `freight_market.gd` com dados reais das rotas; visão só por fora do caminhão, sem cabine interna). Etapa D feita: galpão industrial 3D (`blender/scripts/build_garage_env.py` → `assets/scenery/garage_hall.glb`, ~20 mil triângulos) usado na garagem e na tela inicial, luz de estúdio (`garage_stage._studio_lights`), garagem com abas MODELO/PEÇAS/MECÂNICA/REPARO, ficha técnica só com dados reais (`garage_info_panel.gd`), cartões em `garage_shop.gd`, botões de vista e zoom na roda do mouse. Etapa E feita: HUD com fontes da identidade e textos com acento via i18n (POSIÇÃO, DESTINO com marcadores de todos, CARGA com % e diagrama de dano, velocidade/marcha/RPM com faixa vermelha, turbo/Passing, chip VÁCUO), botões de toque em vidro escuro com setas desenhadas, pausa em blocos (Continuar, Configurações, Sair para o menu, Sair do jogo; teclado/controle com foco). Combustível não existe na simulação (não entrou). Etapa F (1ª passada): texturas repetíveis de asfalto/rugosidade/grama/areia (`blender/scripts/build_road_textures.py` → `assets/textures/`), estrada com mureta New Jersey além do limite físico da sim (13 m), litoral com guard-rail, praia descendo até o mar animado, palmeiras/arbustos/pedras (`build_scenery_3d.py -- --only palm,rock,bush`), skyline do outro lado da baía; prédios com cor própria, recuo no topo, luz de aviação piscando e letreiros de neon; **corrigido**: objetos de beira de estrada sumiam depois dos primeiros ~450 m (MultiMesh único cortado por distância → agora um bloco por trecho de 150 m). Medido no PC (litoral, `--fps-log`): ~75 FPS (limitado pelo monitor), mas 800–1050 chamadas de desenho e 0,6–0,9 milhão de triângulos por quadro — pesado para celular; otimizar na etapa H (LOD dos caminhões, sombras). Etapa G feita: contratos (origem/destino, carga, peso, valor, capacidade do baú, fragilidade; `scripts/data/contracts.gd`, `data/cargo/`, testes em `tests/test_contracts.gd`); a ficha técnica mostra a capacidade de carga. **Corrigido**: os testes gravavam no perfil real do jogador (`user://profile.json`); agora usam `user://test_profile.json`. Próximas: F mapas, G contratos (precisa de dados novos: origem/destino/carga). Hoje a troca é só visual: **o hitbox da simulação (`Collision.LEN` = 12 m) e as estatísticas ainda são iguais para todos** — falta decidir massa/aceleração/tamanho por modelo. Falta: levar o mesmo nível de detalhe às outras ~28 peças (grade, visor, saias, murais) e conferir o cromo no celular.
- **Arte do caminhão (pedido original do Marco)**: visual 3D aprovado em geral; refinar o modelo para ficar mais próximo de um caminhão real (portas, cabine, chassi, rodas, detalhes), seguindo `docs/dekotora_volvo_3d_references/` (Volvo FH + dekotora). O caminhão é o coração do jogo: investir em detalhe.
- Opcional: contratar VPS (`server/README.md`), chave de assinatura Android (`docs/RELEASE_ANDROID.md`), conta Play Console / itch.io.

## Problemas conhecidos / ideias

- Cromo à noite reflete o céu escuro (parece escuro); ver `docs/ACESSORIOS.md` (ajuste em `road3d/world_env.gd`).
- Trânsito e rivais usam carrocerias/modelos simples; sem LOD (160k triângulos, ~400 draw calls na corrida: ok no PC, medir no celular).
- Dano visual dos acessórios: amassado = material opaco + inclinação leve; quebrado = some + detrito genérico.
- Sem login: o código de jogador é a "senha". Servidor aceita perfil do cliente se `rev` for maior (confiança entre amigos).
- Mural riscado só conta batidas laterais; sem textura de risco.
- Teste de rede ainda não foi feito com celular real (só localhost com atraso simulado).
