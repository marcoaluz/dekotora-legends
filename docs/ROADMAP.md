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
- [x] [T-169] Modelos de docs/Modelos aplicados: montanhas nevadas no horizonte, ondas do mar, árvore de folhas, poste novo; com T-163 (pilar em T, guard-rail em W, postes com fios, `docs/BIBLIOTECA_CENARIO.md`) e T-164 (viaduto rodoviário por cima, semáforos de faixa nos túneis) — concluída em 2026-10-21, `tests/test_scenery_t169.gd`, `docs/capturas_t169/` (escolhas de lugar/quantidade: confirmar com o Marco)
- [x] [T-186] Biblioteca de cenário inteira: inventário de docs/Modelos (`docs/BIBLIOTECA_CENARIO.md`), 6 Gleditsias + coqueiros/cedro por código em bosques por bioma com 2 LODs, 2 postes de luz por trecho, pessoas (pedágio, viaduto, duelo) e retrato do motorista no duelo — concluída em 2026-10-21, `tests/test_scenery_t186.gd`, `docs/capturas_t186/` (visual a confirmar com o Marco)
- [x] [T-156] (G1) Abertura "frente a frente" antes da largada (cheia ~9,4 s, curta 3 s), campanha 1 contra 1, grid lado a lado, comboio online 3–4 e protocolo 6 com relógio comum (concluída em 2026-10-20, `tests/test_duel_scene_flow.gd`, `docs/capturas_t156/`)
- [x] [T-170] Som da seta (pisca de troca de faixa): tique-taque do relé sincronizado com a lâmpada (~1,5 Hz, começa aceso) e clique da alavanca a cada toque em < / >; 2 sons novos no ElevenLabs; só apresentação (concluída em 2026-10-20, `tests/test_turn_signal.gd`)
- [x] [T-171] Garagem: prévia da peça montada no caminhão antes de comprar (toque/mouse/teclado/controle, câmera na vista da peça, COMPRAR E EQUIPAR / EQUIPAR / VOLTAR AO ATUAL, cores travadas só para ver) e pneus apoiados sobre a plataforma do galpão (antes afundavam 10 cm) (concluída em 2026-10-21, `tests/test_garage_preview.gd`, `docs/capturas_t171/`)

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

- [~] [T-172] Peças deluxe (amostras de acabamento fino): andon de cabine 一番星, coroa de lanternas de ônibus, neon de chão (encaixe novo), estrutura lateral cromada, estribo iluminado, barra de 16 lanternas; brilho/acrílico acompanham dia/noite (feito em 2026-10-21, `tests/test_parts_deluxe.gd`, `docs/capturas_t172/`; **PRECISA MARCO** aprovar o visual para seguir com mais peças)

## Fase 5 — Áudio
- [x] Sons de `AUDIO_ELEVENLABS.md` gerados pelo Claude via API (tools/gen_audio.py) — Marco precisa OUVIR e pedir regeração dos ruins
- [x] [P50] Preparar loops e importar áudio
- [x] [P51] Som do motor em camadas
- [x] [P52] Efeitos e música no jogo
- [x] [T-173] Variedade de som: 3 escapamentos com som próprio do motor (reto rouco, chaminés graves, cromado com estalos), turbina com assobio e "pssh" de cada perfil, 3 buzinas novas escolhidas na aba MECÂNICA (botão OUVIR), rivais com som sorteado, online com buzina/escape do descritor (protocolo 7) (concluída em 2026-10-21, `tests/test_engine_sounds.gd`; Marco precisa OUVIR)

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
- [x] [T-189] PC em Forward+ com qualidade Ultra (SDFGI, SSR, névoa volumétrica, LUT por hora) + vida do cenário; celular segue Compatibility (não medido no aparelho)
- [x] [T-188/T-192] Cenário novo (terreno com morros, montanhas em 3 camadas, quarteirões com neon, litoral com casas, pedras, placas com texto, céu/noite) nas 3 rotas inteiras; pinheiro/cedro/árvore redonda/arbusto/coqueiros refeitos com folhagem em camadas; pintura 速度落とせ dentro da faixa (concluída em 2026-10-22, `tests/test_scenery_t188.gd` e `test_scenery_t192.gd`, `docs/capturas_t192/`; celular não medido)
- [x] [T-193] Modelos das pastas novas de docs/Modelos: trens com locomotiva/vagões variados, 2 carros no trânsito, 8 prédios texturizados + skyline na cidade, neon kanji, carro único 1 vez por corrida (2026-10-22, `tests/test_scenery_t193.gd`, `docs/capturas_t193/`; celular não medido)
- [x] [T-195] Trem do Marco (locomotiva azul refeita sem derreter, 1º trem de cada rota), antisserrilhado MSAA + folhas suaves, asfalto molhado sem chuvisco, fim da pista contínuo até a cidade destino (pórtico CHEGADA, avenida, prédio-portal, skyline), sujeira na mureta, morro da ferrovia sem triângulo preto (2026-10-22, `tests/test_scenery_t195.gd`, `docs/capturas_t195/`; celular não medido)
- [x] [T-198] Câmeras da corrida (C: perto, padrão, longe, cinema com cortes e letterbox, órbita girando o caminhão; blend suave, limite pela mureta/túnel, lembra por rota) e retrovisor (R ou tocar no espelho; SubViewport 288×84 a 25 fps, borda acende com caminhão perto atrás; automático desligado no celular médio/baixo) (2026-10-22, `tests/test_race_cameras*.gd`, `docs/capturas_t198/`; celular não medido)
- [x] [T-199] Polimento do cenário: prédios/casas com beiral, antenas, ar-condicionado, varandas, escadas de incêndio, marquises e letreiros; Gleditsias mais cheias; mureta com juntas, marcos de km, telefones e pichações; pontes com viga de borda; fachadas com desgaste; retrato do duelo com rosto; bugs da noite (placas, halos, grão do asfalto = textura sem mipmap, CHEGADA) (2026-10-22, `tests/test_scenery_t199.gd`, `docs/capturas_t199/`; celular não medido)
- [x] [T-202] HUD da corrida estilo Art Truck Battle: velocímetro analógico 0–140 (agulha com inércia, luz de fundo dia/noite/túnel, vidro no PC), setas verdes + lâmpadas (farol, pisca-alerta, buzina, freio), 5 segmentos de status com detalhe, relógios 走行時間/残り時間 + barra de progresso numerada, radar vertical à esquerda; celular com DPI, área segura e longe dos botões (2026-10-22, `tests/test_hud_t202.gd`, `tests/test_hud_scene_t202.gd`, `docs/capturas_t202/`; celular não testado)
- [x] [T-208] Abertura do duelo: abre mais rápido (menu lê a corrida em segundo plano, tela preta com neblina desde o clique, shaders aquecidos antes do relógio), cena de 8,9 s + 3 s de contagem com fase das faixas, servidor espera todos montarem a corrida (protocolo 11). Medidas em `docs/capturas_t208/medidas.txt`
- [x] [T-204] Abertura do duelo no ritmo do original: estúdio preto com neblina roxa (volumétrica no Ultra), caminhões reais entram em ângulo e param lado a lado, guardiões Raijin/Fujin (arte nossa) com aura, 対決 com taiko, faixas dos pilotos, raio com UM clarão de 0,15 s (opção "Reduzir clarões") e trovão sintetizado, arrancada e contagem no grid; 8 s; protocolo 9 (2026-10-23, `tests/test_duel_intro.gd`, `docs/capturas_t204/`; celular não testado, APK novo pendente)
- [x] [T-207] Pedágio de verdade: pista dividida em 2 passagens em volta da ilha central com cabine, funil de barreiras, física na simulação (bater na ilha = batida com dano; bots/rival/trânsito escolhem uma passagem), cobertura com luzes, placas ETC/一般, cancelas, zebra e faixas pintadas; protocolo 10 (2026-10-23, `tests/test_toll_plaza.gd`, `tests/test_toll_visual.gd`, `docs/capturas_t207/`; celular não testado, APK novo pendente)
- [x] [T-211] Oficina, lote 1: encaixes e zonas protegidas medidos nos 18 caminhões (`truck/sockets/*.json`), 17 deques frontais e 14 viseiras novos (cor L/R com preço, letreiro de nomes prontos, dia/noite, dano sem buraco), teste de encaixe 558/558 (`tests/test_part_fit.gd`, `docs/REPORT_ENCAIXE.md`), proposta das lacunas e tabela de cores (`docs/REFERENCIA_PECAS.md` seções 18–19, `docs/capturas_t211/`); protocolo 12 (2026-10-24; aguardando o Marco aprovar a folha)
- [x] [T-214] Refino do lote 1: deque e viseira assentados no teto/testa REAIS de cada cabine (grades medidas por raios no Blender, `truck/sockets/*.surf.json`; assento e enchimento na cor da peça; canhões sem base, cada um apoia sozinho), mais detalhe (caixas de LED com parafusos, cantoneiras, rebites, frisos) e textura de detalhe da estrutura, LED com lente, cor dos LEDs e do neon separada da peça (11 luzes); teste de contato por raios em todos os caminhões (2026-10-24, `tests/test_part_fit.gd`, `docs/capturas_t214/`)
- [x] [T-215] Peças antigas de teto fora do jogo (reembolso do preço cheio, save antigo continua abrindo), deque de 2 níveis (caixa em cima de canhões e o contrário) com tabela de encaixe por caminhão (`truck/stack_fit.json`), +8 cores de peça; protocolo 13 (2026-10-24, `tests/test_deck_stack.gd`)
- [x] [T-216] Canhões embaixo da caixa ficam à frente dela, com pés cromados atrás (a caixa recua onde a viseira não deixa os canhões avançarem); 1.500 de 1.728 duplas × caminhões cabem (2026-10-24, `docs/capturas_t216/folha_t216.png`)
- [x] [T-217] Ambientação das 3 rotas na linha do original: pista contrária com canteiro (cerca viva + guard-rail) e trânsito vindo de frente (carros, ônibus, caminhões de docs/Modelos), muros de pedra 谷積み nos cortes, túnel gêmeo com portal de concreto, ventiladores e brilho da saída, adaptação de exposição no PC, danchi na cidade, floresta densa e neblina nos vales, postes de braço curvo, placas azuis com texto, farol/porto/banhistas no litoral, cachoeira/obra/ponte pênsil na montanha (2026-10-26, `docs/capturas_t217/`, `docs/BIBLIOTECA_CENARIO.md` seção 6-7)
- [x] [T-218] Caminhões de homenagem ao Art Truck Battle, feitos do zero (marca fictícia HAYATE): baú de alumínio, lona verde (銀河運輸), baú rosa com mural de gueixa + neon, tanque cromado e caçamba; 2 cabines novas, 3 LODs, compra na garagem, rivais e bots, carga Combustível, protocolo 14 (2026-10-26, `docs/capturas_t218/`, `tests/test_homage_t218.gd`)
- [x] [T-219] Peso do caminhão: `game/data/feel/truck_feel.tres` (um arquivo para ajustar), inércia na simulação (arrancada, troca de faixa com "arrasto", carga e peças pesam), baú que inclina/cabeceia/afunda com mola, emendas do viaduto, câmera com atraso, congelamento de 75 ms nas batidas, fumaça de pneu, sons procedurais (pancada grave, rangido, vibração), vibração do celular com opção; protocolo 15 (2026-10-26, `docs/capturas_t219/`, `tests/test_truck_feel_t219.gd`; números são PROPOSTA)
- [ ] [T-211+] Próximos lotes da oficina (ordem da seção 16.2 do catálogo), um por vez com folha aprovada
- [ ] [T-192b] Pendências do Marco (não agora): copas ralas das Gleditsias adultas (d/e/f) e boneco com cara de manequim no retrato do duelo
- [ ] [V8] Medir no celular — PRECISA MARCO (Android SDK + JDK 17 para gerar o APK)

## Fase 8 — Publicação (opcional)
- [x] [P80] (guia docs/RELEASE_ANDROID.md; chave e AAB PRECISAM MARCO) Builds de release (AAB assinado, .exe)
- [x] [P81] (docs/LOJA.md, docs/store/, docs/POLITICA_PRIVACIDADE.md) Ficha da Play Store / itch.io
