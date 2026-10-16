# STATUS — contexto para retomar o trabalho (outra sessão/conta)

Atualize este arquivo ao fim de CADA tarefa. Leia antes: CLAUDE.md, docs/AGENTES.md, docs/ROADMAP.md.

## Ambiente do PC do Marco (Windows 10, Git Bash + PowerShell)
- Godot 4.7.2: `D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe` (não está no PATH). Templates: `D:\DEV\Godot\dl\*.tpz`.
- Blender 5.2.2 LTS: `D:\Blender\blender.exe` (não está no PATH). bpy + numpy OK.
- No bash: `source tools/env.sh` define `$GODOT` e `$BLENDER`.
- Projeto: `D:\DEV\dekotora-legends\dekotora-legends` (git local iniciado; sem remoto GitHub ainda).
- Android SDK/JDK17: NÃO verificados. Celular: só o Marco testa.

## Segredos / chaves de API
- Arquivo `.chaves.env` na raiz do projeto (formato `NOME=valor`), **ignorado pelo git** (`.gitignore`: `.chaves.env`, `*.env`). NUNCA commitar nem colar o valor em docs/logs.
- Variáveis: `ELEVENLABS_API_KEY` (geração dos sons do jogo, ver docs/AUDIO_ELEVENLABS.md) e `PIXELLAB_API_KEY` (não usada: arte é toda Blender).
- Para usar num script: ler o arquivo em tempo de execução (ex.: `set -a; source .chaves.env; set +a`), sem imprimir o valor.

## Modo de trabalho combinado (2026-10-15)
Marco autorizou seguir os prompts P01→P81 até o fim sem parar e voltará para validar. O que exige
o Marco (celular, áudio ElevenLabs, contratar VPS, chave de assinatura, aprovar visual/plano A×B)
fica marcado como "precisa Marco" em docs/ROADMAP.md e no QUADRO; seguir adiante no que não depende disso.

## Estado atual
Ver lista abaixo (mais recente no fim).

## Histórico
- P00 concluído: ambiente conferido.
- P01 concluído: project.godot (Input Map, 4 autoloads vazios), export_presets.cfg (Android/Windows/Server), --server no main.gd.
- P02 parcial: tela de teste + build Windows OK (`builds/dekotora.exe`, ignorada no git). Android BLOQUEADO: sem Android SDK/JDK17 no PC (Marco). Export templates 4.7.2 já instalados.
- Nome do jogo mudou (pedido do Marco): Kaidō Bakusō — Chrome Legends (ver DECISOES). Alternativas se ele não gostar: "Ichiban Kaidō", "Hoshi Bakusō". Textos de UI devem usar o nome via i18n quando existir.
- P10 concluído (lib em blender/scripts/lib, test_lib.py OK). P11: build_truck_base.py + render_truck.py rodam; aguardando revisão visual.
- P11/P12 concluídos (arte): `blender/scripts/build_truck_base.py`, `render_truck.py`, `render_parts.py`, `parts/*.py`. Folha: blender/renders/parts/contact_sheet.png. Quadro 160x120, ângulos ±20/±10, pitch 7°. Kanji ok (fonte baixada em game/assets/fonts/NotoSansJP.ttf, OFL).
- P13 (visualizador) feito: `game/scenes/tools/truck_viewer.tscn` + `scripts/truck/truck_view.gd`. Teste visual: `godot --path game res://scenes/tools/truck_viewer.tscn`. FALTA Marco aprovar o visual (e Android).
- ATENÇÃO ferramenta: no Bash tool, heredocs grandes com aspas falham; use a ferramenta Write para criar arquivos.
- P20 concluído: sim em game/scripts/sim/ (commands, track, engine_model, truck_sim, race_sim) + game/tests/test_sim_basic.gd (9 testes passam).
- P21 concluído: game/scripts/road/{sprite_projector,road_renderer,race_scene}.gd + scenes/race/race.tscn. ~60 FPS no PC (RX 580). Teste: `godot --path game res://scenes/race/race.tscn` (setas/WASD). Debug: `-- --autoplay --start=600 --touch`.
- P22: local_input.gd, touch_controls.gd, Settings (touch_scale, tilt). Falta testar no celular (Marco). Inclinação: eixo y do acelerômetro, `tilt_invert` se vier invertido.
- 2026-10-16 Marco colou o prompt das peças -> `docs/PROMPT_ACESSORIOS_3D.md` (vale para o P40; seguir as 7 etapas dele, protótipos primeiro: para-choque, suporte de luzes de teto, saia lateral). Reconciliação: os modelos 3D (.glb) são a fonte; os sprites do jogo (plano A) são renderizados deles. Pastas do prompt: assets/vehicles/dekotora/... (dentro de game/). Já existe caminhão base (blender/scripts/build_truck_base.py, +Y frente, metros) para medir encaixes. Marco pediu para AGUARDAR esse prompt: não iniciar a produção das 32 peças antes de apresentar o plano/protótipos.
- P23 concluído (cenário de teste). P30/P31 concluídos (transito e bots, testes passam). P32 em andamento (collision.gd, damage_model.gd, testes em test_collision_damage.gd).
- 2026-10-16 SALTO DE QUALIDADE (pedido do Marco): apresentação 3D = `game/scenes/race/race3d.tscn` (scripts em game/scripts/road3d/, truck/truck_node.gd, truck/fx_3d.gd, ui/race_hud.gd, ui/result_screen.gd). Caminhão PBR: `blender/scripts/build_truck_3d.py` -> game/assets/vehicles/dekotora/truck/dekotora_truck_base.glb (24k tris). Teste: `godot --path game res://scenes/race/race3d.tscn` (setas/WASD; `-- --autoplay --start=0 --debug-events`). ~75 FPS no PC. Plano A (2D) segue em scenes/race/race.tscn.
- P32-P35 concluídos (colisão/dano, passing/vácuo/chegada/pagamento, HUD, efeitos 3D). Testes: 31 passam (`godot --headless --path game -s res://tests/run_tests.gd`).
- Projeto agora usa stretch canvas_items + fractional (3D nítido; HUD em layout 480x270). .blend e previews dentro de game/ têm `.gdignore` (senão o Godot tenta importar .blend e pede o Blender).
- PRÓXIMO: P40 com `docs/PROMPT_ACESSORIOS_3D.md` (32 acessórios GLB), depois P41 (PartDef .tres) ...
- 2026-10-16 P40 CONCLUÍDO (prompt do Marco): 32 acessórios 3D em game/assets/vehicles/dekotora/accessories/, catálogo, demo (`scenes/tools/accessory_viewer.tscn`), testes (37 passam). Documentação completa: docs/ACESSORIOS.md. Marco deve olhar as prévias em game/assets/vehicles/dekotora/previews/assembled_*.png e rodar a demo.
- 2026-10-16 P41/P44/P42/P43/P45 concluídos: dados .tres (game/data/, gerador game/tools_dev/gen_data.gd), motor completo (sim/engine_model.gd), GameState com save (user://profile.json), garagem (scenes/garage/garage.tscn: peças, mecânica, reparo), menu (scenes/menu/main_menu.tscn) e campanha de Kanto (3 trechos em data/routes/, rivais em data/rivals/ com nomes PROVISÓRIOS). main.tscn agora só roteia para o menu. Base de tela agora 960x540 (UI nova em 960x540; HUD/toque em 480x270 dentro de CanvasLayer scale 2). 60 testes passam.
- Para ver: `godot --path game` (abre o menu). Debug garagem: `-- --demo --damage --tab=repair --slot=front_bumper`.
