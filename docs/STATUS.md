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
