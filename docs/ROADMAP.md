# Roadmap

Cada fase termina **rodando no celular do Marco** (e no PC). Sem prazo. Refazer é permitido.
O número entre colchetes é o prompt em `PROMPTS.md`. Claude marca `[x]` ao concluir.

## Fase 0 — Setup
- [ ] Instalar ferramentas (`SETUP.md`) — Marco
- [x] [P00] Claude lê o projeto e confere o ambiente
- [x] [P01] Configurar projeto Godot (resolução, controles, exportações)
- [~] [P02] Primeira build: tela de teste no celular e no PC — Windows OK (builds/dekotora.exe); Android PRECISA MARCO (falta Android SDK + JDK17, ver docs/SETUP.md passo 5)

## Fase 1 — Teste do pipeline Blender (decisão de visual)
- [x] [P10] Biblioteca comum dos scripts Blender
- [x] [P11] Caminhão base em 5 ângulos
- [x] [P12] 3 peças de teste (para-choque, luzes de teto, andon) com 3 estados de dano
- [~] [P13] Visualizador de camadas no Godot (caminhão girando entre ângulos, troca de peças)
- [ ] **Marco aprova o visual (PRECISA MARCO)** ou pede ajustes (repetir P11/P12)

## Fase 2 — Protótipo da estrada
- [x] [P20] Simulação da pista e do caminhão (sem gráficos)
- [x] [P21] Renderizador pseudo-3D com o caminhão real
- [~] [P22] Controles touch, teclado e controle — teclado/controle/toque prontos; build Android PRECISA MARCO (sem SDK)
- [ ] [P23] Cenário de teste (parallax + beira de estrada provisória)
- [ ] **Marco decide: plano A (pseudo-3D) ou plano B (3D PS1)**

## Fase 3 — Corrida contra bots
- [ ] [P30] Tráfego
- [ ] [P31] Bots rivais
- [ ] [P32] Colisões e dano por zona
- [ ] [P33] Passing, vácuo, carga, chegada e pagamento
- [ ] [P34] HUD de corrida
- [ ] [P35] Efeitos visuais de batida (faísca, fumaça, peça caindo)

## Fase 4 — Garagem e economia
- [ ] [P40] Todas as peças do MVP no Blender (8 slots)
- [ ] [P41] Dados das peças e motores em Resources
- [ ] [P42] Tela da garagem (montar, comprar, ver peso/durabilidade/Fama)
- [ ] [P43] Reparo e custo
- [ ] [P44] Motor, turbo, escape e freio-motor na simulação
- [ ] [P45] Save local e campanha de Kanto (3 trechos + chefe)
- [ ] [P46] Bots, tráfego e cenário de Kanto no Blender

## Fase 5 — Áudio
- [ ] Marco gera os sons de `AUDIO_ELEVENLABS.md`
- [ ] [P50] Preparar loops e importar áudio
- [ ] [P51] Som do motor em camadas
- [ ] [P52] Efeitos e música no jogo

## Fase 6 — Multiplayer
- [ ] [P60] Servidor headless + salas por código (2 janelas no mesmo PC)
- [ ] [P61] Corrida sincronizada (comandos → servidor → snapshots)
- [ ] [P62] Predição e interpolação
- [ ] [P63] Colisão e dano no servidor, resultado e pagamento
- [ ] [P64] Perfis no servidor e jogo cruzado celular ↔ PC
- [ ] [P65] Teste em rede Wi-Fi (celular → PC do Marco)
- [ ] [P66] Servidor no VPS + teste com amigos

## Fase 7 — Polimento e teste com amigos
- [ ] [P70] Desempenho no celular
- [ ] [P71] Menus e UI finais
- [ ] [P72] Rodada de testes e lista de ajustes de equilíbrio

## Fase 8 — Publicação (opcional)
- [ ] [P80] Builds de release (AAB assinado, .exe)
- [ ] [P81] Ficha da Play Store / itch.io
