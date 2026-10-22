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
| Multiplayer | Online, 2 a 4 jogadores, sala privada por código; bots completam vagas; 3–4 = "comboio" (trânsito mais leve) |
| Campanha | Sempre 1 contra 1: jogador × rival da rota (decisão do Marco, T-156) |
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
| Trocar de faixa (toque 1 = seta, toque 2 = troca) | ◀ ▶ grandes à esquerda | A/D ou ←/→ | Analógico esquerdo ou direcional |
| Acelerar | Botão grande à direita | W ou ↑ | Gatilho direito |
| Frear | Botão menor à direita | S ou ↓ | Gatilho esquerdo |
| Passing | Botão redondo | Espaço | A |
| Buzina | Botão BUZINA (entre as setas) | H | X |
| Pausa | Ícone | Esc | Start |
| Trocar a câmera (T-198: perto, padrão, longe, cinema, órbita) | Ícone de câmera (canto de cima, à esquerda) | C | Y |
| Retrovisor liga/desliga (T-198) | Tocar no espelho (desligado: aba pequena no topo) | R | Back |

**Controle por faixas (decisão ATB-1):** 3 faixas + acostamento. O 1º toque para um lado liga a seta (pisca no caminhão e no HUD);
o 2º toque no mesmo lado em até ~1,5 s executa a troca (~0,7 s, com leve inclinação). Não existe volante livre nem botão de bater:
trocar para uma faixa ocupada é a batida/empurrão. Nas curvas o caminhão segue a faixa sozinho: acima da velocidade segura
o pneu canta, ele perde velocidade e desliza no máximo meio metro; só muito acima (+30%) escapa da faixa, com aviso antes.
O corpo só gira (até 3°) ao trocar de faixa; na curva acompanha a pista (T-132).
**Prazo e vitória:** o frete tem prazo que desce desde a largada; vence quem chega primeiro **e** dentro do prazo.
Câmera só externa (primeira pessoa descartada).

Câmbio automático no MVP. Freio-motor entra sozinho ao soltar o acelerador em alta rotação.

### Mecânicas
1. **Peso**: menos aceleração e curva, mais força de empurrão.
2. **Colisões entre caminhões**: bate-lata lateral, batida traseira, empurrão para fora. Batida lateral forte **empurra o
   outro para a faixa vizinha** (o mais pesado ganha; o leve quica de volta). Carro do trânsito atingido com força é
   **arremessado** (gira, quica, sai da faixa) (T-141). A batida no trânsito **custa velocidade** (T-152): de frente na
   traseira do carro perde 25–40% conforme a força, raspão lateral 8–15%, ônibus mais; depois ~0,6 s de **tranco**
   (acelerador sem efeito, o caminhão balança, velocímetro vermelho).
3. **Dano por zona** (frente, traseira, esquerda, direita): peças da zona absorvem primeiro; peça zerada quebra e cai.
4. **Dano mecânico**: motor (potência, fumaça), direção (puxa), carga.
5. **Integridade da carga** reduz o pagamento.
6. **Motor, turbo e marcha** com RPM, turbo lag e sons distintos.
7. **Fama (Kirameki)**: peças inteiras, ultrapassagens, entregas. Libera conteúdo.
8. **Passing**: bots abrem espaço; contra humanos só tremor e susto sonoro.
   **Buzina** (tecla H / botão BUZINA): o carro logo à frente sai da faixa se puder. **Freada forte** em velocidade: chiado,
   fumaça dos pneus e marcas no asfalto (T-144).
9. **Vácuo** em reta.
10. **Tráfego** como obstáculo.
11. **Eventos de pista** (T-139): **acidente** (carros parados fecham 1 ou 2 faixas), **obras** (cones, barreiras,
    caminhão de obra, limite de 60 km/h com chapas de aço na faixa ao lado) e **estreitamento** (3 → 2 faixas: uma faixa
    de fora acaba). Nunca fecham as 3 faixas. Avisos antes (painel de LED e placas a 400 m e 200 m, aviso no HUD), cones
    no afunilamento (cada cone tocado custa um pouco de carga), batida forte no veículo parado/barreira e troca de faixa
    recusada para dentro de uma faixa fechada. Cada rota tem 1 evento fixo e pode sortear mais 1 (45%) pela semente da
    corrida; o prazo estica alguns segundos por evento. Bots e trânsito saem cedo da faixa fechada.
12. **Trechos com 2 faixas** (T-153, parte da pista, não é evento): em cada rota a pista INTEIRA estreita para 2 faixas
    (asfalto, linhas, muretas e acostamentos entram em diagonal, com zebrado; alarga de novo depois). A faixa da
    **direita** (ultrapassagem) acaba; quem está nela entra na fila antes de a mureta fechar (se insistir, raspa na
    mureta, perde carga e é obrigado a entrar). Avisos: painel de LED a 600 m, losango "車線減少" a 400 m e 200 m, placa
    azul "この先 2車線" e "PISTA COM 2 FAIXAS" no HUD. Litoral: ponte sobre o mar no fim da rota; viaduto: viaduto antigo
    depois do acidente; montanha: túnel antigo (湯坂隧道) nas curvas do começo.

Pagamento = frete × integridade da carga + bônus de posição + bônus de Fama. O dano persiste após a corrida.

## 4. Modos e multiplayer
| Modo | Jogadores | Quando |
| --- | --- | --- |
| Corrida com amigos (sala por código) | 2–4 + bots; com 3–4 é o **comboio** (trânsito mais leve) | MVP |
| Campanha de Kanto (3 trechos + chefe) | **sempre 1 contra 1** (jogador × rival da rota) | MVP |
| Corrida rápida (sem rota) | 1 + 3 bots | MVP |
| Garagem | 1 | MVP |
| Corrida pública, Duelo de Rival, Frete Livre | — | Pós-MVP |

**Abertura "frente a frente" (T-156):** antes do duelo da campanha (e online com 2 jogadores), ~6 s de cena numa
área de descanso (noite/fim de tarde) ou praça de pedágio (dia): os dois caminhões estacionados de frente, luzes
piscando, a câmera passeia pelos detalhes com a faixa de cada motorista (nome, caminhão, destaque, provocação), banner
VS com tambor; depois os caminhões alinham lado a lado na pista e vem a contagem. Um toque pula. Revanche, corrida
rápida e online com 3–4 jogadores: versão curta (só alinhamento e contagem, 3 s).

Partida online: criar sala → código de 6 letras → amigos entram (celular ou PC) → cada um com o caminhão da
própria garagem → servidor decide colisões e dano → pagamento e dano ficam no perfil.
Regras da sala: rota, dano (Real / Só na corrida), bots, tráfego, dia/noite.

## 5. Progressão, peças e dano
- ¥ compra e conserta; Fama só acumula e libera regiões (Kanto no MVP; Tokai, Kansai, Kyushu, Tohoku depois).
- Perfil único no servidor para celular e PC.
- Atributos de peça: peso, durabilidade, Fama, zona, preço.
- Slots decorativos: para-choque frontal, viseira, luzes de teto, saias laterais, andon, para-choque traseiro, mural, calotas, cor.
- Peças de motor: motor (6 cil. padrão, 6 cil. preparado, V8), turbo (sem, simples, duplo), escape (padrão, direto, chaminés verticais, cromado cortado — cada um com som próprio do motor, T-173),
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
