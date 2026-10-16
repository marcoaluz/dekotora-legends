# Kaidō Bakusō — Chrome Legends (nome de trabalho; pasta e repositório seguem "dekotora-legends")

Jogo de corrida de caminhões Dekotora para Android e PC, com multiplayer entre amigos.
Arte em pixel art renderizada a partir de modelos do Blender. Feito por Marco + Claude.

## Começando

1. Siga `docs/SETUP.md` para instalar tudo (Godot, Blender, Git, Claude Code).
2. Abra um terminal nesta pasta e rode `claude`.
3. Digite `/model sonnet` e depois `/tarefa P00`. O time de agentes está em `docs/AGENTES.md`.

## Mapa da pasta

| Pasta | O que tem |
| --- | --- |
| `CLAUDE.md` | Contexto e regras que o Claude Code lê sempre |
| `.claude/` | Time de agentes, skills (Blender, Godot, arte), comandos `/tarefa` e `/painel`, quadro e log |
| `docs/` | GDD, arquitetura, multiplayer, arte, áudio, balanceamento, roadmap, prompts |
| `blender/` | Scripts que constroem e renderizam toda a arte |
| `game/` | Projeto Godot (abra `game/project.godot`) |
| `server/` | Como rodar e publicar o servidor do multiplayer |
| `tools/` | Utilitários (exportar builds, conferir assets) |

## Status

Todas as fases do roteiro foram executadas até onde dá sem o celular do Marco. Veja `docs/STATUS.md` (estado e pendências) e `docs/ROADMAP.md`.
