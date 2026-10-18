# STATUS — contexto para retomar o trabalho (outra sessão/conta)

Atualize ao fim de CADA tarefa. Leia antes: `CLAUDE.md`, `docs/AGENTES.md`, `docs/ROADMAP.md`, `docs/DECISOES.md`.
Última atualização: **2026-10-18**. Todos os prompts P00–P81 foram executados até onde dá **sem o celular/contas do Marco**.

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
| Testes automáticos (192) | `godot --headless --path game -s res://tests/run_tests.gd` (código de saída 0 = passou) |
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

## PRÓXIMAS TAREFAS (para outra sessão do Claude; pedidas pelo Marco em 2026-10-18)

Contexto: o Marco baixa os modelos só com a licença **Royalty Free License (no AI)** e confere antes. Se algum modelo exigir
crédito ao autor, ele avisa quem é; todos os já usados estão em `game/assets/LICENCAS.md`. Tunnel.obj e van.abc (Downloads)
continuam fora até ele informar link/licença. Nenhuma das tarefas abaixo foi iniciada (só registradas).

1. **T-131, Jipe Suzuki no tráfego** (autorizado pelo Marco). Fonte: `docs/Novos modelos/Carro/` (OBJ/FBX, 436 mil triângulos,
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

- **T-138:** escolher o fundo padrão da tela inicial (A posto à noite, B rodovia; compare `docs/capturas_t138/depois_960x540/menu.png`
  e `menu_fundo_b.png`) e dizer se a câmera da garagem ficou perto o bastante.

- **T-136:** olhar `docs/capturas_t136/comparacao_antes_depois.png` e dizer se o baú premium fica (e se vale estender aos baús leve/longo e ao Canter); conferir a chapa ondulada no celular (APK).
- **T-130:** mandar o link e a licença de `Downloads\Tunnel.obj` e `Downloads\van.abc` (sem isso ficam fora do jogo); olhar
  `docs/capturas_t130/` e dizer se as placas/sinais estão no tamanho certo.
- Instalar **Android SDK + JDK 17** e gerar/testar o APK no celular (P02, P22, P65, P70, P72). Sem isso o Android não foi testado.
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
  `game/assets/LICENCAS.md`). Código: `blender/scripts/truck3d/jac_src.py` (importa o .blend de `docs/Modelos Melhorados/`, que fica fora
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
- **T-115 (2026-10-17): análise de modelos de terceiros em `docs/NOVOS_MODELOS.md`**; nenhum entra sem o Marco confirmar a licença; Canter descartado (extraído de outro jogo). Aguardando o Marco informar origem/licença.
- **T-121 + T-124 (2026-10-18): 6 carros novos no trânsito** a partir dos modelos de terceiros (licença confirmada pelo Marco):
  Van 01, Ascona, Falcon, SUV (tipo carro), **Fumi SC** (esportivo raro, 104–122 km/h) e **ônibus Jetset** (13,3 m, lento, 12 t).
  Scripts: `blender/scripts/build_traffic_van01.py` e `build_traffic_cars.py -- --model all` (+ `lib/traffic_kit.py`,
  `traffic_classify.py`, `traffic_preview.py`; lêem `docs/Novos modelos/` e `docs/Modelos Melhorados/`, fora do Git). Cada carro:
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
  Pendências: erro antigo de malha no túnel da rota de Hakone (`tunnel_3d.gd:151`, `set_normal`: aparece no console, não trava); falta jogar para ajustar prazo, empurrão e a regra "derrota paga 0".
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
