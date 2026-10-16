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
- **Arte do caminhão (pedido do Marco, prioridade)**: visual 3D aprovado em geral; refinar o modelo para ficar mais próximo de um caminhão real (portas, cabine, chassi, rodas, detalhes), seguindo `docs/dekotora_volvo_3d_references/` (Volvo FH + dekotora). O caminhão é o coração do jogo: investir em detalhe.
- Opcional: contratar VPS (`server/README.md`), chave de assinatura Android (`docs/RELEASE_ANDROID.md`), conta Play Console / itch.io.

## Problemas conhecidos / ideias

- Cromo à noite reflete o céu escuro (parece escuro); ver `docs/ACESSORIOS.md` (ajuste em `road3d/world_env.gd`).
- Trânsito e rivais usam carrocerias/modelos simples; sem LOD (160k triângulos, ~400 draw calls na corrida: ok no PC, medir no celular).
- Dano visual dos acessórios: amassado = material opaco + inclinação leve; quebrado = some + detrito genérico.
- Sem login: o código de jogador é a "senha". Servidor aceita perfil do cliente se `rev` for maior (confiança entre amigos).
- Mural riscado só conta batidas laterais; sem textura de risco.
- Teste de rede ainda não foi feito com celular real (só localhost com atraso simulado).
