# Kaidō Bakusō: Chrome Legends — GDD (v0.2, 15/10/2026)

Versão em Markdown para o Claude Code. A versão editável com diagramas fica no claude.ai
(documento "Dekotora Legends — Game Design Document"). Se as duas divergirem, a do claude.ai vale;
peça ao Claude para atualizar esta.

## 1. Visão geral

Jogo de corrida de caminhões Dekotora para **Android (foco) e PC Windows**, com pixel art renderizada a
partir de modelos 3D do Blender. O jogador entrega cargas pelo Japão, bate de frente com os caminhões dos
amigos no multiplayer e gasta o que ganha para consertar e decorar o caminhão.

**Pitch:** cada peça cromada traz Fama e protege o caminhão nas batidas, mas pesa — e, quebrada, custa caro para consertar.

| Item | Definição |
| --- | --- |
| Gênero | Corrida arcade com batidas + customização, no espírito de Bakusou Dekotora Densetsu (PS1) |
| Plataformas | Android (foco) e PC Windows, jogo cruzado |
| Câmera | Plano A: estrada pseudo-3D vista de trás. Plano B: 3D low-poly estilo PS1 |
| Multiplayer | Online, 2 a 4 jogadores, sala privada por código; bots completam vagas |
| Motor | Godot 4 (GDScript) |
| Arte | Blender por scripts Python → pixel art |
| Áudio | ElevenLabs |
| Público | Marco e amigos primeiro |
| Modelo | Projeto pessoal, sem prazo |

### Pilares
1. **Exagero é virtude.** O visual Dekotora é o produto.
2. **Cromo é armadura.** Cada peça muda peso, durabilidade e Fama.
3. **Batida tem consequência.** Empurrar o amigo é parte do jogo; o reparo sai do bolso.
4. **Sessões curtas.** Corridas de 3 a 5 minutos.

## 2. Referências e tom
Bakusou Dekotora Densetsu 1 e 2 (PS1): corrida contra rival para entregar a carga. Art Camion Geijutsuden (PS2):
dinheiro vira tuning e decoração. OutRun / Road Rash: estrada pseudo-3D com sprites e combate.
Tom: orgulho de estrada, exagero visual, humor leve, noite japonesa com neon. Sem violência contra pessoas:
é caminhão contra caminhão.

## 3. Gameplay
Loop: aceitar frete → correr a rota (bots ou amigos) → entregar → reparar e decorar → repetir.

### Controles
| Ação | Android | PC teclado | PC controle |
| --- | --- | --- | --- |
| Virar | ◀ ▶ à esquerda ou inclinação | A/D ou ←/→ | Analógico esquerdo |
| Acelerar | Botão grande à direita | W ou ↑ | Gatilho direito |
| Frear | Botão menor à direita | S ou ↓ | Gatilho esquerdo |
| Passing | Botão redondo | Espaço | A |
| Pausa | Ícone | Esc | Start |

Câmbio automático no MVP. Freio-motor entra sozinho ao soltar o acelerador em alta rotação.

### Mecânicas
1. **Peso**: menos aceleração e curva, mais força de empurrão.
2. **Colisões entre caminhões**: bate-lata lateral, batida traseira, empurrão para fora.
3. **Dano por zona** (frente, traseira, esquerda, direita): peças da zona absorvem primeiro; peça zerada quebra e cai.
4. **Dano mecânico**: motor (potência, fumaça), direção (puxa), carga.
5. **Integridade da carga** reduz o pagamento.
6. **Motor, turbo e marcha** com RPM, turbo lag e sons distintos.
7. **Fama (Kirameki)**: peças inteiras, ultrapassagens, entregas. Libera conteúdo.
8. **Passing**: bots abrem espaço; contra humanos só tremor e susto sonoro.
9. **Vácuo** em reta.
10. **Tráfego** como obstáculo.

Pagamento = frete × integridade da carga + bônus de posição + bônus de Fama. O dano persiste após a corrida.

## 4. Modos e multiplayer
| Modo | Jogadores | Quando |
| --- | --- | --- |
| Corrida com amigos (sala por código) | 2–4 + bots | MVP |
| Campanha de Kanto (3 trechos + chefe) | 1 + bots | MVP |
| Garagem | 1 | MVP |
| Corrida pública, Duelo de Rival, Frete Livre | — | Pós-MVP |

Partida online: criar sala → código de 6 letras → amigos entram (celular ou PC) → cada um com o caminhão da
própria garagem → servidor decide colisões e dano → pagamento e dano ficam no perfil.
Regras da sala: rota, dano (Real / Só na corrida), bots, tráfego, dia/noite.

## 5. Progressão, peças e dano
- ¥ compra e conserta; Fama só acumula e libera regiões (Kanto no MVP; Tokai, Kansai, Kyushu, Tohoku depois).
- Perfil único no servidor para celular e PC.
- Atributos de peça: peso, durabilidade, Fama, zona, preço.
- Slots decorativos: para-choque frontal, viseira, luzes de teto, saias laterais, andon, para-choque traseiro, mural, calotas, cor.
- Peças de motor: motor (6 cil. padrão, 6 cil. preparado, V8), turbo (sem, simples, duplo), escape (padrão, direto),
  freio-motor, pneus, câmbio (automático no MVP).
- Dano: inteira → amassada → quebrada. Reparo = preço × % de dano × fator.
- Valores: `BALANCEAMENTO.md`.

## 6. Arte
Blender por script → pixel art. 480×270 base; caminhão ~96×72 px; 5 ângulos; 3 estados por peça; toon, sem
suavização, contorno 1 px, paleta de 40 cores; brilho das luzes no Godot. Peças em camadas com holdout.
Detalhes: `PIPELINE_ARTE_BLENDER.md`.

## 7. Áudio
ElevenLabs. Motor em camadas (4 loops por motor + turbo + pssh + freio-motor + escape + dano), efeitos de
caminhão, batidas, ambiente, UI, multiplayer e música (city pop, synthwave, rock, enka-rock).
Prompts: `AUDIO_ELEVENLABS.md`.

## 8. Stack
Godot 4.7 (Compatibility, 2D), Blender, Android SDK + JDK 17, Claude Code, ElevenLabs, Git + GitHub + LFS,
VPS Linux na Fase 6. Android min API 26, alvo API 36. Servidor = projeto Godot headless.
Detalhes: `ARQUITETURA.md`, `MULTIPLAYER.md`.

## 9. MVP e roadmap
MVP: Kanto, bots e amigos online, garagem com dano e reparo, Android e PC.
Fora: outras regiões, clima, câmbio manual, ranking, compras no app.
Fases 0 a 8 em `ROADMAP.md`. O visual Blender é testado primeiro (Fase 1); a rede entra com a corrida pronta (Fase 6).

### Decisões abertas
- Visual Blender aprovado? (após Fase 1)
- Plano A ou B? (após Fase 2)
- Dano padrão nas salas: Real ou Só na corrida
- Nome final, idioma, VPS, rivais de Kanto
