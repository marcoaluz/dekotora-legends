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
- [x] [P23] Cenário de teste (parallax + beira de estrada provisória)
- [ ] **Marco decide: plano A (pseudo-3D) ou plano B (3D PS1)**

## Fase 3 — Corrida contra bots
- [x] [P30] Tráfego
- [x] [P31] Bots rivais
- [x] [P32] Colisões e dano por zona
- [x] [P33] Passing, vácuo, carga, chegada e pagamento
- [x] [P34] HUD de corrida
- [x] [P35] Efeitos visuais de batida (faísca, fumaça, peça caindo)
- [x] [T-139] Eventos de pista: acidente, obras (limite 60 km/h) e estreitamento 3 → 2 faixas; simulação, rede (servidor sorteia), bots, trânsito, visual (3 chamadas por evento), HUD, sons e prazo (concluída em 2026-10-18, `tests/test_track_events.gd`, `docs/capturas_t139/`)
- [x] [T-141] Impacto das batidas: força no espírito do Art Truck Battle (empurrão de faixa entre caminhões, carro do trânsito arremessado na simulação), faíscas, clarão, pedaços de cromo/lanterna/vidro, chacoalhada, tremor e sons em camadas (4 sons novos no ElevenLabs) (concluída em 2026-10-19, `tests/test_impacts.gd`, `docs/capturas_t141/`)
- [x] [T-144] Freada forte (som de freio, "pssh" ao soltar, fumaça dos pneus, marcas no asfalto) e buzina (tecla H / botão X / botão BUZINA, ícones no HUD, trânsito abre caminho, vai pela rede) (concluída em 2026-10-19)
- [x] [T-146] Modelos de `docs/Novas Melhorias` (Metais, Placas, Placão): barreiras listradas nas obras/acidente/estreitamento e nas bocas dos túneis, chapas e postes reais nas placas, pórticos de treliça, outdoors com arte trocável, vidro com moldura na barreira de som (concluída em 2026-10-19, `tests/test_roadside_kit.gd`, `docs/capturas_t146/`)
- [x] [T-155] (F4) Acabamento visual: mural aceso à noite (baú e graneleira), ficha da garagem sem corte, carro batido com rodas redondas, bocas de túnel abertas com muros listrados maiores, túnel antigo mais claro, STATUS do Android corrigido (concluída em 2026-10-19, `tests/test_mural_glow.gd`, `tests/test_tunnel_portals.gd`, `docs/capturas_t155/`)
- [x] [T-154] (F3) Ferrovia ao lado da rodovia: trem de carga, bonde amarelo, viadutos de trem e bocas de túnel; só visual, sem sim nem rede (concluída em 2026-10-19, `tests/test_railway.gd`, `docs/capturas_t154/`)
- [x] [T-156] (G1) Abertura "frente a frente" antes da largada (cheia ~9,4 s, curta 3 s), campanha 1 contra 1, grid lado a lado, comboio online 3–4 e protocolo 6 com relógio comum (concluída em 2026-10-20, `tests/test_duel_scene_flow.gd`, `docs/capturas_t156/`)

## Fase 4 — Garagem e economia
- [x] [P40] Todas as peças do MVP no Blender (8 slots)
- [x] [P41] Dados das peças e motores em Resources
- [x] [P42] Tela da garagem (montar, comprar, ver peso/durabilidade/Fama)
- [x] [P43] Reparo e custo
- [x] [P44] Motor, turbo, escape e freio-motor na simulação
- [x] [P45] Save local e campanha de Kanto (3 trechos + chefe)
- [x] [P46] Bots, tráfego e cenário de Kanto no Blender
- [x] [T-121/T-124] Carros de tráfego com modelos de terceiros (Royalty Free): Van 01, Ascona, Falcon, SUV, Fumi SC e ônibus (ver `docs/MODELOS_MELHORADOS.md`, seção Status)
- [x] [T-125] Caminhão Canter e cabine curta a partir do JAC 1045 (concluída em 2026-10-18, commit 1637c2c)
- [x] [T-126] 10 peças de personalização de terceiros (Kenworth W990, Fumi SC, JAC 1045), concluída em 2026-10-18, commit 674b053
- [x] [T-129] Cabines só de arquivo: jac (JAC grande) e americana (Kenworth) novas, 4 cabines por código retiradas, migração de perfis (concluída em 2026-10-18)
- [x] [T-133] Rodas girando: peças de roda presas ao pneu, todas as rodas, garagem gira na vista RODAS (concluída em 2026-10-18, referência `docs/direcao_arte/rodas_girando_*.png`)
- [x] [T-132] Caminhão segue a faixa nas curvas: atrito acima da velocidade segura, deslizada de até 0,5 m, escape só acima de +30% com aviso, giro do corpo só na troca de faixa (≤ 3°, eixo traseiro); bots, servidor, predição e trânsito com a mesma regra (concluída em 2026-10-18, `tests/test_lane_following.gd`, `docs/direcao_arte/faixa_curva_*.png`)

- [x] [T-145] Carroceria graneleira (aberta com lona, 4 cabines, garagem/perfil/rede/bots) e regra carga x carroceria nos contratos: baú leva carga fechada, graneleira leva granel (grãos, brita), madeira/aço/peças vão nas duas (concluída em 2026-10-19, `tests/test_graneleira.gd`, `docs/capturas_t145/`; regra a confirmar pelo Marco)

## Fase 5 — Áudio
- [x] Sons de `AUDIO_ELEVENLABS.md` gerados pelo Claude via API (tools/gen_audio.py) — Marco precisa OUVIR e pedir regeração dos ruins
- [x] [P50] Preparar loops e importar áudio
- [x] [P51] Som do motor em camadas
- [x] [P52] Efeitos e música no jogo

## Fase 6 — Multiplayer
- [x] [P60] Servidor headless + salas por código (2 janelas no mesmo PC)
- [x] [P61] Corrida sincronizada (comandos → servidor → snapshots)
- [x] [P62] Predição e interpolação
- [x] [P63] Colisão e dano no servidor, resultado e pagamento
- [x] [P64] Perfis no servidor e jogo cruzado celular ↔ PC
- [x] [P65] (guia docs/REDE_WIFI.md; teste real no celular PRECISA MARCO) Teste em rede Wi-Fi (celular → PC do Marco)
- [x] [P66] (docs + scripts; contratar VPS PRECISA MARCO) Servidor no VPS + teste com amigos

## Fase 7 — Polimento e teste com amigos
- [~] [P70] — PC: 75 FPS (limite do vsync), ~400 draw calls; presets de qualidade criados; medir no celular PRECISA MARCO Desempenho no celular
- [x] [P71] Menus e UI finais
- [x] [P72] (guia docs/TESTE_AMIGOS.md; APK e a rodada em si PRECISAM MARCO) Rodada de testes e lista de ajustes de equilíbrio

## Plano visual (docs/PLANO_VISUAL.md)
- [x] [V0] Correção das rodas + protótipo noturno
- [~] [V1] 3 propostas de direção de arte (`docs/DIRECAO_ARTE.md`) — **escolha PRECISA MARCO**
- [x] [V2] Sistema de hora do dia por rota
- [x] [V3] Estrada com cara de via expressa japonesa (viaduto, pórticos, túneis)
- [x] [V4] Texturas CC0 com desgaste
- [x] [V5] Sensação de velocidade (com chaves nas Opções)
- [x] [V6] Cromo por matcap
- [x] [V7] Caminhão com cara de Dekotora (luzes, andons, mural trocável)
- [x] [T-106] Cabine realista (portas, vidros curvos, para-lamas, degraus, faróis e grade com perfil) + texturas por código (sujeira, normal, colmeia, pneu)
- [ ] [V8] Medir no celular — PRECISA MARCO (Android SDK + JDK 17 para gerar o APK)

## Fase 8 — Publicação (opcional)
- [x] [P80] (guia docs/RELEASE_ANDROID.md; chave e AAB PRECISAM MARCO) Builds de release (AAB assinado, .exe)
- [x] [P81] (docs/LOJA.md, docs/store/, docs/POLITICA_PRIVACIDADE.md) Ficha da Play Store / itch.io
