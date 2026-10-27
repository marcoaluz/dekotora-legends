# Registro de decisões

Mais recente no topo. Toda decisão que muda o design ou a stack entra aqui.

| Data | Decisão | Motivo |
| --- | --- | --- |
| 2026-10-26 | **Som do motor (T-220, pedido do Marco, item 16) — ANÁLISE + SINTETIZADOR NOVO PARA O MARCO OUVIR; padrão do jogo NÃO mudou.** Medido com numpy: os loops do ElevenLabs estão todos errados (a fundamental ouvida fica em 27–77 Hz em qualquer giro; a 2300 rpm deveria ser 116 Hz). Os loops sintetizados da T-197 (som atual) têm a fundamental certa, mas são "limpos demais" (toda explosão igual: periodicidade 0,71) e 57% da energia fica abaixo de 300 Hz, que o alto-falante do celular não toca. Novo: diesel procedural (`DieselSynth` + `EngineSynthVoice`, AudioStreamGenerator; ressonâncias do escapamento no barramento `EngineSynth`, em C++), tom contínuo, explosões diferentes entre si; modos `loops` / `synth` / `mix` em Opções > Áudio > Som do motor e em `game/data/audio/engine_audio.tres`; só o 6 cil. padrão (`voice_i6.tres`) até o Marco aprovar. Custo: 0,15 ms por quadro no PC, versão leve 0,09 ms (celular não medido). | Pedido do Marco (T-220). Detalhes na seção "T-220" no fim |
| 2026-10-26 | **Peso do caminhão (T-219, pedido do Marco, item 15) — PROPOSTA, números num arquivo só (`game/data/feel/truck_feel.tres`).** Simulação: arrancada e trocas de marcha mais lentas, troca de faixa com mais inércia e "arrasto" no fim, carga acima de 4 t (×1,25) e peças (×1,5) pesam a mais na inércia; padrão 0–100 km/h 22,6 → 23,7 s, troca de faixa 1,00 → 1,13 s (baú cheio 1,17 → 1,67 s). Visual: baú inclina para fora com mola (atraso e volta), cabeceio, suspensão nas baixadas e emendas do viaduto, câmera com mais atraso e FOV com teto, congelamento de 75 ms nas batidas (online só a câmera), fumaça de pneu/poeira, pancada grave, rangido, vibração da carroceria, vento; opções "Vibração do celular" e "Reduzir tremor da câmera". Bot que ficava preso atrás de um lento corrigido. Protocolo 15. | Pedido do Marco (T-219). Detalhes na seção "T-219" no fim |
| 2026-10-23 | **Pedágio de verdade, com física (T-207, pedido do Marco) — visual A CONFIRMAR PELO MARCO.** No km 0,15 de toda rota a pista se divide em **duas passagens** em volta de uma **ilha central** (a faixa do meio inteira, ±1,8 m, de 132 a 164 m) com a cabine; o acostamento acaba num **funil** de barreiras (60 m) e cada passagem tem 3,8 m (faixas 1 e 3 sempre cabem). **Bater no nariz da ilha = batida de frente como num veículo parado** (mesma regra/massa dos obstáculos da T-139: dano, carga, para a 6 m/s e sai para a passagem do lado, x = 0 vai para a esquerda); de lado = empurrado para fora (batida lateral ou raspada); encostar = raspada; acostamento = raspa e entra na passagem. Bots, rival e trânsito saem da faixa do meio antes (mesmas consultas de faixa fechada), o bot preso ao lado de alguém cai para trás dele para entrar ("zíper"), troca de faixa para a ilha é recusada perto dela. **Sem limite de velocidade nem parada** (é corrida: o ETC real pede 20 km/h). Passagem da esquerda **ETC/一般** (verde), da direita **ETC専用** (roxa); saiu o 止まれ/pare do acostamento. Duelo (largada nas faixas 1 e 3): custo 0 s; corrida rápida (jogador larga no meio, entre 2 bots): o último a passar perde ~4 s. Protocolo 10. | Pedido do Marco (T-207). Detalhes na seção "T-207" no fim |
| 2026-10-23 | **Abertura do duelo mais lenta e abrindo na hora (T-208, relato do Marco: "demorou para abrir e foi rápido demais").** Cena de **8,9 s + 3 s de contagem = 11,9 s** (antes 5 + 3): entrada 2,6 s (param em 2,1 s e respiram), guardiões 1,3 s, 対決 sozinho 1,2 s, **fase nova "faixas" 1,9 s** (faixas dos pilotos paradas ~2,5 s para ler), raio 0,9 s, arrancada 1,0 s. O relógio da cena começa no **1º quadro liso**: antes dele um preparo com tela preta + neblina roxa aquece os shaders (pista uma vez, estúdio com tudo aceso uma vez). O menu lê a corrida em segundo plano e a troca de tela mostra preto + neblina desde o clique. **Online: o servidor só começa a contar quando todos montaram a corrida** (`c_race_loaded`, no máximo 30 s) e avisa todos no mesmo instante (`s_state(COUNTDOWN)`); protocolo 11. | Relato do Marco no celular (T-208). Medidas em `docs/capturas_t208/medidas.txt`; detalhes na seção "T-208" no fim |
| 2026-10-23 | **Abertura do duelo refeita (T-204, pedido do Marco) — visual A CONFIRMAR PELO MARCO.** Estúdio preto com neblina roxa rasteira (volumétrica só no PC Ultra; no celular, planos de névoa baratos); os 2 caminhões DE VERDADE entram pelos lados em ângulo e param lado a lado de frente para a câmera, faróis e neon acesos; atrás deles sobem os guardiões **Raijin** (atrás do jogador, à esquerda) e **Fujin** (atrás do rival, à direita), arte NOSSA desenhada por código, cada um numa aura de chamas; **対決** entra com o taiko; as faixas dos dois pilotos aparecem juntas embaixo (sem a fala de provocação: não dá tempo de ler); um **raio** cai entre os dois com **UM clarão de 0,15 s** e trovão (opção nova **"Reduzir clarões"** troca por um brilho violeta suave e também suaviza o clarão da saída do túnel); corte: os dois arrancam para a câmera; na pista a contagem começa com eles já lado a lado no grid. **8 s no total (5 s de cena + 3 s de contagem)**, antes 9,4 s. Protocolo de rede 9. Saíram: área de descanso/praça de pedágio, detalhes de para-choque/viseira/mural, banner VS e o pisca-pisca de farol de provocação. | Pedido do Marco (T-204). Detalhes na seção "T-204" no fim |
| 2026-10-21 | **Cenário novo em UM trecho-piloto por rota (T-188, etapa 1) — AGUARDA APROVAÇÃO DO MARCO pelos prints.** Litoral 0,6–1,6 km, cidade 1,3–2,05 km, montanha 1,1–2,05 km (`ScenicZone`, `--t188=off|segment|all`, padrão `segment`): terreno com relevo e textura (grama em 3 tons, terra, rocha, copa de floresta, areia na costa, margem do outro lado da baía), montanhas em 3 camadas (morros perto, cordilheira do meio por código, maciços do horizonte com textura, normais suaves e perspectiva aérea), floresta nas encostas, quarteirões com calçada/ruas/telhados variados/8 fachadas/letreiros de neon com kanji (recuo ≥ 40 m do eixo), casas nos morros do litoral, pedras novas, placas do pórtico com texto na textura. **Global** (não dá para cortar por km): céu novo (estrelas pequenas, lua, nuvens com volume), luar azulado + brilho da cidade no horizonte à noite, neblina com a cor do horizonte; neve dos maciços do litoral/cidade 0,8 → 0,5 (para aparecer floresta). Texturas feitas por código (numpy/Blender e Noto Sans JP, OFL); nada baixado | Pedido do Marco (T-188). Custo medido no PC (modo médio): chamadas −1 a +10, triângulos +5%, textura +1,4 MB, FPS no ruído. Detalhes na seção "T-188" no fim |
| 2026-10-21 | **Biblioteca de cenário inteira no jogo (T-186) — escolhas visuais A CONFIRMAR PELO MARCO.** Inventário completo de docs/Modelos em `docs/BIBLIOTECA_CENARIO.md`. Lá só existe UMA espécie de árvore (Gleditsia, 6 variações), UM poste de luz (dentro da Ponte A) e UM personagem (o boneco do pacote ROAD SIGNS): as 6 Gleditsias, o poste da Ponte A (`lamp_bridge`) e o boneco (`person`) entraram; coqueiros (3 formas), cedro, pinheiro, árvore redonda e arbusto são **por código**. Árvores em **bosques por bioma** (nunca em fila), 2 LODs, MultiMesh; poste antigo na praça do pedágio e no litoral, poste da ponte no viaduto, na serra e nas pontes; pessoas no pedágio, no viaduto por cima e na abertura do duelo; **retrato** do motorista (busto com a camisa na cor do caminhão) na faixa do duelo, para o jogador e o rival. Só visual. Canter (`canter.obj`) continua fora (extraído de outro jogo) | Pedido do Marco (T-186). Detalhes na seção "T-186" no fim |
| 2026-10-21 | **Modelos novos e antigos de docs/Modelos aplicados (T-169, com T-163 e T-164).** Licença não é mais restrição (Marco). Entraram: **montanhas nevadas** no horizonte das 3 rotas no lugar dos cones (4 maciços do "Fundo Montanha Gelo", ~900 triângulos cada; neve cheia na montanha, só nos picos no litoral e na cidade; 16/10/6 maciços), **ondas do mar** (mapa de normais do pacote "Agua"), **árvore de folhas** (Gleditsia, 279 triângulos, 6,5 m: no lugar da árvore redonda na cidade, 25% na montanha, 20% no litoral do lado da terra), **poste** (coluna, caixa e suporte do poste novo no poste de energia da T-163), **pilar em T, guard-rail em W, postes com fios** (T-163), **viaduto rodoviário cruzando por cima** (cidade 2.050 m, montanha 2.580 m, seção da Ponte A) e **semáforos de faixa nos túneis** (seta verde / X vermelho ligados aos eventos, T-164). Tudo só visual; `--no-backdrop`, `--no-pontes-kit`, `--no-overpass`, `--no-poles`, `--no-lane-signals` desligam. Escolhas de lugar e quantidade feitas pelo Claude: **confirmar** | Pedido do Marco (T-169) e decisões da T-159. Detalhes na seção "T-169" no fim |
| 2026-10-21 | **Variedade de som do motor e buzinas (T-173) — números e sons A CONFIRMAR PELO MARCO.** (1) **O escapamento define o som do motor**: `exh_straight` (reto esportivo, rouco) = perfil `exh_rasp`; **novos** `exh_stack` (chaminés verticais, grave potente) = `exh_stack` e `exh_chrome_cut` (cromado cortado, estalos) = `exh_pop`; o escape padrão continua com os loops do próprio motor (`i6_std`/`i6_tuned`/`v8`). Cada perfil tem 3 loops (lenta, média, alta) que **substituem** os do motor; o motor só muda o tom (V8 ×0,9, 6 cil. preparado ×1,06). (2) **Turbina**: com turbo simples ou duplo toca o assobio do perfil (duplo 10% mais agudo e +2 dB) e o "pssh" do perfil ao soltar; no escape padrão, os sons de turbo antigos. (3) **Escapes novos na loja** (propostas, ver BALANCEAMENTO): chaminés +2% torque, +16 destaque, 28.000 ¥; cromado cortado +2,5%, +12, 22.000 ¥. As chaminés são só o som/estatística: **não montam** a peça visual `kw_exhaust_stacks` (ligar as duas é decisão pendente). (4) **Buzina escolhida na garagem** (aba MECÂNICA, seção BUZINA, **grátis**): automática (a da peça, como antes) ou uma das 6 (3 antigas + 3 novas: grave de navio, dupla de dois tons, musical dekotora). Vai no descritor de rede (`horn`, **protocolo 7**). (5) **Rivais offline**: motor/turbo/escape/buzina **sorteados só no som** (semente = rota + lugar no grid); a simulação deles não muda. Online: cada um ouve o motor e a buzina do descritor do outro (antes todos ouviam o 6 cilindros padrão). (6) A buzina de ar básica só sustenta ~0,3 s: o loop de "segurar" agora usa a janela medida de cada buzina (antes repetia silêncio). | Pedido do Marco ("3 de cada para validar"). 18 sons gerados no ElevenLabs, 627 créditos |
| 2026-10-20 | **Respostas do Marco sobre a T-159 (docs/Modelos/Road_pontes):** (1) todos os modelos que o Marco fornece são "Royalty Free (no AI)", sem exigência de crédito — vale também para os próximos; (2) o "Outdor" era mesmo um pórtico de placas; não será usado (os pórticos da T-146 ficam); (3) **sim** aos postes de energia com fios; (4) **sim** ao viaduto rodoviário cruzando por cima da pista; (5) **sim** ao semáforo de faixa no túnel (seta verde / X vermelho) ligado aos eventos de faixa fechada. Os modelos também servem de **referência para fases novas**: cada fase não precisa ter todos os itens; o coordenador mantém um catálogo de peças selecionadas para distribuir depois (docs/BIBLIOTECA_CENARIO.md) | Marco, 2026-10-20 |
| 2026-10-20 | **Campanha sempre 1 contra 1; amigos 2 a 4 com "comboio" (T-156, G1) — DECISÃO DO MARCO.** A corrida da campanha (Continuar, Mercado de fretes) é só o jogador contra o rival da rota (antes: + 2 bots). A **corrida rápida** (sem rota) continua com o jogador + 3 bots (o Marco não citou; **confirmar**). Online continua 2 a 4 jogadores (bots completam se a sala quiser); com **3 ou 4 jogadores é o modo "comboio": trânsito um nível mais leve** que a regra da sala (normal → leve, pesado → normal), aplicado pelo servidor e mandado no setup. | Pedido do Marco (G1). Detalhes na seção "T-156" no fim |
| 2026-10-20 | **Abertura "frente a frente" antes da largada (T-156) — visual e números A CONFIRMAR PELO MARCO.** Só apresentação (a simulação espera na largada e começa no fim da contagem, como antes). **Cheia (~9,4 s: 6,4 s de cena + 3 s de contagem)**: os dois caminhões de verdade (peças, pintura, adesivos, padrão de luz) estacionados de frente num cenário montado com peças que já existem — **área de descanso** (noite e fim de tarde: loja, máquinas de bebida, postes de sódio, neon) ou **praça de pedágio** (dia: 2 pedágios da pista, cabines, placas ETC/一般, pinheiros); faróis piscando de provocação; câmera nos detalhes (para-choque, viseira + andon, mural) com a **faixa** de cada um (brasão, nome do motorista e do caminhão, destaque das peças, fala curta); banner **VS** com mancha de tinta vermelha, 対決 e tambor; na pista, o **alinhamento** (os dois entram na faixa, câmera alta descendo) e a contagem com o corte lateral de sempre. **Curta (3 s)**: revanche (mesma rota e rival de novo, até fechar o jogo), corrida rápida e online com 3–4. Um toque/tecla/botão pula para a contagem. **Grid lado a lado** (StartGrid): duelo com uma faixa livre entre os dois (jogador na direita, rival na esquerda), 3–4 = três lado a lado + um atrás; a largada passou para 30 m da pista (atrás do zero não existe asfalto e a câmera ficava em cima do baú). **Rival da IA**: sem duelo nos 8 s iniciais, não prende o jogador no acostamento e não anda abaixo de 80% do ritmo só para ficar ao lado. Sem retratos (não existem): brasão com um kanji na cor do caminhão. **Online**: protocolo 6 (`intro`, `countdown_total` no setup; o servidor espera a abertura inteira) | Pedido do Marco (G1, inspirado no Art Truck Battle sem copiar). Detalhes, custo e medidas na seção "T-156" no fim |
| 2026-10-19 | **Acabamento visual F4 (T-155) — força do mural A CONFIRMAR PELO MARCO.** (1) **Mural aceso à noite sem luz real**: emissão no material do mural (baú e tampas da graneleira) com a própria arte, 1,0 perto da saia de LED, 0,78 no topo e 0,62 no meio, tingida de branco quente (e da cor do rival); força por hora do dia em `TimeOfDay.mural_glow` (noite 0,8, fim de tarde 0,4, dia 0) e 0,75 dentro de túnel de dia; garagem e menu ficam como estavam (têm luz de estúdio). A emissão fica sempre ligada no material (só a força muda) para não recompilar shader no meio da corrida. A **lona preta** da graneleira continua escura (lona real; só as tampas acendem). (2) **Ficha técnica compacta**: rótulo e valor na mesma linha para caber inteira em 540 de altura (16:9 e 20:9), "FICHA TÉCNICA" ao lado do nome, botão PERSONALIZAR visível; o aviso "potência e tanque não existem" virou **dica do título** (não cabia sem cortar). (3) **Carro batido**: rodas redondas nossas (20 lados, a da frente esterçada 9°) no lugar do pneu esculpido; lascas abaixo de 0,34 m cortadas (fora das rodas). (4) **Túneis**: muros listrados da boca viram 4 peças de 1,3 a 2,3 m de altura, 0,66 m de largura, com a face 0,15 m na frente da mureta; túnel antigo um pouco mais claro (concreto 0,42 + 0,78 × lâmpada), lâmpadas 0,2 × 0,3 × 1,3 m e poças de luz fracas (alfa 0,42) no asfalto. Corrigida regressão da T-153 no perfil do arco (bocas fechadas, chapa inclinada dentro dos túneis). | Pedido do Marco (F4, pendências vistas nas imagens). Custo medido (modo médio, sem vsync, `tools/measure_t155.sh`, 5 pontos): chamadas +0 a +3, triângulos +0,4 mil, textura +0,3 MB, FPS no ruído (184–196 → 190–238) |
| 2026-10-19 | **Trechos com 2 faixas de verdade (T-153) — posições e detalhes A CONFIRMAR PELO MARCO.** (1) São **parte da pista** (`RouteDef.lane_sections {start, end, lanes: 2, taper, look}`), não evento: valem com `--no-events` e com a regra de sala `events: false`, não esticam o prazo e o servidor manda a lista no setup (`lane_sections`, **protocolo 5**). Na simulação viram `TrackEvents.Kind.SECTION`, então jogador, bots, trânsito, recusa de troca e predição usam as mesmas regras de faixa fechada da T-139. (2) **Acaba a faixa da DIREITA** (a de ultrapassagem no Japão); a mureta da direita entra de 13 m para 3,0 m e a da esquerda de 13 m para 7,8 m, com transição suave; a linha de borda corre na frente da mureta e o meio fica zebrado. Quem insiste raspa na mureta (perde carga) e é obrigado a entrar na fila. (3) **Onde**: litoral = **ponte** sobre o mar em 2.440–2.745 m (trecho 2.400–2.760; a rota ganhou uma lombada de 3% em 2.400–2.800 m para a ponte ficar ~10 m acima da água); viaduto = **viaduto antigo** 2.270–2.510 m (logo depois do acidente fixo); montanha = **túnel antigo de 2 faixas** "湯坂隧道" (nome fictício) em 805–1.040 m, nas curvas do começo (trecho 780–1.060; túnel novo, o de 2.080 m continua largo). As posições evitam a janela onde o evento sorteado cai (senão o litoral e a montanha ficariam sem evento extra). (4) Eventos sorteados ficam a 120 m ou mais da zona do trecho (antes: 400 m de aviso + 200 m entre eventos), e placas de evento não ficam dentro do trecho. (5) Placas japonesas fictícias (atlas dos eventos ganhou 2 artes): painel de LED "この先 2車線 / 追越車線 終わり" a 600 m, losango 車線減少 a 400/200 m, placa azul "この先 2車線"; HUD "PISTA COM 2 FAIXAS". | Pedido do Marco (F2). Custo: chamadas de desenho iguais (±5), FPS no ruído (modo médio, sem vsync, 200–250); bots +1 a +3 s por corrida (média) |
| 2026-10-19 | **Ferrovia ao lado da rodovia (T-154) — A CONFIRMAR PELO MARCO.** Não havia peças de ferrovia de terceiros no PC: via, catenária, muro, viaduto, bocas de túnel, locomotiva e vagões **feitos por código**; o **bonde Urbos** do Marco virou o "trem amarelo" (repintado, sem logotipos). Linha do lado da terra (esquerda) no litoral (0–2.150 m), na cidade (rota inteira, elevada) e na montanha (1.240 m–fim, com o túnel); viaduto de trem por cima da pista na cidade (1.500 m) e na montanha (240 m). Trem só visual, relógio próprio, 1º ~10 s depois da largada e depois a cada 22–40 s, mesmo sentido ou contrário (mão inglesa), sempre "marcado" para passar pelo jogador; no viaduto, um trem em cima da pista quando o jogador passa (1 vez por corrida). Detalhes na seção "T-154" no fim | Pedido do Marco (F3). Custo medido em `docs/STATUS.md` (T-154) |
| 2026-10-19 | **Respostas do Marco sobre a T-152:** (1) "pode ser assim": a batida forte continua custando ~10 s, sem redução automática de marcha (kickdown) por enquanto; (2) tranco só nas batidas com o trânsito, por enquanto — o Marco vai testar e avisar; (3) números ok (frente 25–40%, raspão 8–15%, ônibus ×1,35) | Marco, 2026-10-19 |
| 2026-10-19 | **Carroceria graneleira (T-145) — A CONFIRMAR PELO MARCO.** (1) **Tamanho único = baú médio** (8,2 m de carroceria no mesmo chassi, 2 eixos traseiros, 12 m na pista, cresce para a frente nas cabines curta/jac como os baús): é o tamanho típico de uma graneleira de caminhão "truck", reaproveita chassi/rodas/hitbox e não cria um 4º comprimento para balancear. (2) **Fica com a lona preta do modelo** (graneleira de grão roda enlonada; a lona serve para qualquer carga e não precisa de um visual de carga por contrato). (3) **Mural nas tampas**: o PNG trocável do mural repete 3 vezes nas tampas (0,7 m de altura), já que a carroceria aberta não tem parede alta; a peça "painel lateral" desce para as tampas. (4) Dekotora de carroceria aberta: **cabeceira "torii" (鳥居)** cromada atrás da cabine com o andon da frente e luzes, **armação traseira** com o andon de trás. (5) **Regra de carga**: baú fechado leva eletrônicos, alimentos refrigerados e louça (`needs = box`); **graneleira leva granel — grãos e brita (cargas novas, `needs = open`)**; madeira, aço e peças industriais vão nas duas (`any`). Bloqueio no Mercado: "PRECISA DE BAÚ" / "PRECISA DE GRANELEIRA" / "PESADA DEMAIS" (graneleira acima de 14 t). O 1º contrato de cada trecho sempre serve no modelo atual, e trocar de modelo na garagem sorteia um quadro novo se nenhum frete servir. (6) **Números**: 14 t de capacidade, 7.500 kg vazia (500 kg mais leve que o baú), resto igual ao baú médio; **sem preço** (os outros modelos também são grátis na garagem); bots da corrida offline usam baú leve, longo e graneleira | Pedido do Marco ("carroceria nova… continua lógico com os baús também lógico"). Modelo "Carroceria_Brasil_Graneleiro" (Royalty Free License (no AI), confirmado pelo Marco) reduzido 81 mil → 7,8 mil triângulos; o .glb inteiro tem 66–78 mil (base_chata 77 mil). Medido no modo médio (litoral à noite): 75 FPS igual ao baú médio, chamadas ~385 vs ~405, textura 46 vs 50 MB |
| 2026-10-18 | **Baú premium no baú médio (T-136, piloto C3):** o baú `base` das 4 cabines passa a ser a versão LEVE de um modelo ALTO feito no Blender (chapa ondulada de verdade, trilhos, montantes, colunas, portas com ferragens reais) com os detalhes finos (rebites, juntas, vincos, borracha, desgaste, lascas, poeira) GRAVADOS em mapas: um atlas 1024² compartilhado (`tex_box_albedo/orm/nrm.png`, ORM = oclusão/rugosidade/metálico) + normais/oclusão do mural (1024×256); o mural continua PNG trocável. Texturas de base CC0 (Poly Haven Blue Metal Plate, ambientCG Metal012/Rubber004, 512 px em `blender/cc0/`). `--box auto` = premium só no `base`; leve, longo, Canter e carreta seguem com o baú antigo até o Marco aprovar. Escolhas técnicas sem o Marco: alumínio com metálico 0,55 (100% fica preto no Compatibility), 45% da oclusão também na cor, texturas do baú com compressão de VRAM e mipmaps, peças de poucos cm sem chanfro | Pedido C3 do Marco (detalhe nível premium dentro do orçamento de celular). Medido (viaduto à noite, modo médio, sem vsync): chamadas 302→304, triângulos por quadro +~2,7 mil, memória de textura 40,9→44,1 MB, FPS igual (~230–280, ruído); .glb do baú médio +4,5 mil triângulos (chata 72,6→77,1 mil) e +0,3 MB; pacote ~+5 MB (4,7 MB de textura comprimida) |
| 2026-10-18 | **Curva com controle por faixas (T-132): o caminhão SEGUE A FAIXA sozinho.** Até +30% da velocidade segura da curva o pneu raspa: custa velocidade (atrito forte perto do limite), o pneu canta e ele desliza no máximo 0,5 m para fora. Acima de +30% perde a faixa de verdade (o controle de faixa perde a força, a curva joga para fora e o pneu deslizando freia menos); o aviso "CURVA! ALIVIE" (HUD + vibração) aparece ~2 s antes, "DERRAPANDO!" ao escapar. O corpo só gira na troca de faixa (no máximo 3°, suave, em torno do eixo traseiro); na curva acompanha a pista (direção = eixo traseiro → dianteiro). A mesma regra vale para bots, servidor, predição do cliente e trânsito | Pedido do Marco (C2), com a medição dele: desvio de até 9,9 m e corpo torto > 2° em até 53% do tempo acelerando sem tocar. Depois: < 0,4 m e < 0,2° nas 3 rotas (`tests/test_lane_following.gd`). Números em `BALANCEAMENTO.md` |
| 2026-10-18 | **Peça de roda acompanha o pneu (T-133).** Calota/roda da loja escolhida vale para TODAS as rodas externas (frente, cada eixo traseiro, a de fora do rodado duplo; esquerda espelhada) e é filha do nó do pneu, então gira e estérça com ele; os pontos `MOUNT_WHEEL_*_FACE_*` viram só referência de encaixe. Cada roda gira por v / raio dela. Garagem: rodas giram devagar só na vista RODAS. Peças de roda sem sombra e escondidas além de 60 m (o pneu já tem aro cromado) | Pedido C1 do Marco. Feito em tempo de execução (`TruckWheels`), sem regerar .glb; com isso o custo ficou igual ao de antes (~+10 chamadas na corrida decorada) |
| 2026-10-18 | **Licença dos modelos: o Marco só baixa "Royalty Free License (no AI)" e confere antes; se algum exigir crédito, ele informa o autor.** Jipe Suzuki entra no tráfego (T-131). Prioridade nova: caminhão andando de lado (T-132) e rodas estáticas (T-133) | Pedido do Marco (T-130). Tunnel.obj e van.abc seguem fora até ele passar link/licença |
| 2026-10-18 | **Cabines só de modelos de arquivo (T-129).** Saem as 4 cabines feitas por código (padrão, clássica, aerodinâmica, teto alto; `truck3d/cab*.py` apagados). Ficam 4: **cara chata** (CF500, padrão dos perfis novos), **japonesa alta** (`jac`: JAC 1045 em escala 0,95 de altura e 0,88 de largura, teto 2,95 m e 2,5 m de largura como o baú, escapamentos atrás), **curta japonesa** (JAC 0,84, baú colado) e **americana** (Kenworth W990 só a cabine "dia" + capô + grade, sem dormitório, sem marcas; eixo dianteiro 0,46 m mais à frente). Perfis, perfis do servidor e descritores de rede com id antigo caem na nova mais parecida (`CabCatalog.LEGACY`: padrão/clássica/teto alto → chata, aerodinâmica → jac), sem mudar `rev`. A carreta guardada passa a usar a chata. Na interface os nomes não citam marcas ("Japonesa alta", "Americana"). | Pedido do Marco ("colocar a cabine JAC que tá nos arquivos e as outras e retirar as feitas por código"). Chata como padrão: é a cab-over japonesa grande com dormitório, a mais próxima do Dekotora clássico. A JAC grande foi escalada diferente da curta (mais alta e larga) para não ficar repetida. **Confirmar com o Marco:** nomes na garagem, padrão = chata, rivais sem a americana (bots: chata/jac/curta) |
| 2026-10-18 | **10 peças de personalização tiradas dos modelos de terceiros (T-126)**: Kenworth W990 (escapamentos altos, tanque, degraus, para-sol, para-choque, grade), Fumi SC (aerofólio de teto, rodas esportivas), JAC 1045 (rodas de aço, caixa de ferramentas); marcas e emblemas fora, materiais nossos, ≤ 3,6 mil triângulos cada. Dois encaixes novos (`exhaust_stacks`, `roof_wing`) e um ponto de montagem criado em tempo de execução (`MOUNT_STACK_R/L`, `TruckNode.add_extra_mounts`) para não regerar os 20 .glb do caminhão. Preços/destaque/Fama são proposta (Fama necessária pela regra do preço) | Pedido do Marco (todos Royalty Free). Medido na corrida (modo médio): 75 FPS antes e depois, +~10 mil triângulos e chamadas iguais (~350–400) |
| 2026-10-18 | **Trânsito com tipos de veículo (T-124):** carro, **ônibus** (13,3 m, lento, 12 t) e **esportivo** raro e rápido; tipo fixo pelo índice do veículo; quem alcança um mais lento troca de faixa ou segue atrás (ninguém atravessa ninguém); hitbox e massa por tipo. **6 modelos de terceiros no tráfego** (Van 01, Ascona, Falcon, SUV, Fumi SC, ônibus Jetset), reduzidos para 4,7–8,8 mil triângulos e **re-texturizados só com cores lisas** (atlas 4×4 próprio): nenhuma textura do autor vai para o jogo e o emblema da grade some; os 4 carros antigos continuam na mistura | Pedido do Marco (todos os modelos confirmados Royalty Free em 2026-10-18; os Sketchfab Standard entram pela mesma regra). Números de velocidade/massa/frequência são proposta (`BALANCEAMENTO.md`). Medido no modo médio: superfícies do trânsito 96 → 65, chamadas de desenho iguais ou menores, +~12% de triângulos, FPS igual |
| 2026-10-18 | **Caminhão base Canter e 6ª cabine "curta" (T-125), da malha do JAC 1045** (CGTrader, Royalty Free): Canter = cabine/chassi/motor/suspensão/tanque/lanternas do JAC em escala 0,74 (6,9 m, cabine 2,1 m) + baú NOSSO de 5 m (2,3 m de largura, teto a 3,0 m, mais alto e largo que a cabine), rodas nossas e decoração V7; só existe com a cabine dele (a escolha de cabine do perfil fica guardada para os outros baús). Cabine curta = cabine do JAC em escala 0,84 nos baús leve/médio/longo; como ela é ~1 m mais curta, **o baú cresce 1,22 m para a frente** (mesmo comprimento total) e os escapamentos verticais atrás da cabine saem. Pontos de montagem do Canter com **escala** (0,88 cabine/rodas, 0,92 baú): as peças do caminhão grande encolhem junto. **Balanceamento por modelo** (`BodyDef`, `data/bodies/*.tres`): Canter 3,5 t vazio, 4 t de carga, 7 m na pista (hitbox), agilidade 1,1, torque ×0,55; leve/médio/longo continuam com os números de antes (só a capacidade muda) | Pedido do Marco (T-120 virou T-125 com a malha). Valores do Canter são proposta para testar; dar números próprios ao leve/longo fica para o Marco decidir |
| 2026-10-18 | **Texturas do caminhão compartilhadas (T-118):** uma cópia só em `assets/vehicles/dekotora/textures/`, aplicada em runtime por `TruckTextures` (achada pelo nome `tex_*` da miniatura extraída do .glb); os .glb levam miniaturas 4×4 com a cor média como reserva. O mural continua embutido (já é trocado pelo TruckNode). Quem carregar um .glb do caminhão sem o TruckNode precisa chamar `TruckTextures.apply(no)` | Opção (b) aprovada pelo Marco na T-106. Medido: .pck 97,5 → 54 MB, memória de textura na corrida 53 → 43 MB, mesmas chamadas de desenho |
| 2026-10-18 | **Identidade visual: as três, uma por fase** (A noite de neon, B fim de tarde, C dia de verão). Tóquio = noite, Litoral = fim de tarde, Hakone = dia; fases futuras escolhem a hora no `.tres` da rota. Mais um caminhão base "Canter" (cabine pequena e baú um pouco maior que o dos nossos baús) e uma 5ª cabine "cara chata" (referência: International CF500) | Decisão do Marco (T-090 resolvida). Modelos de terceiros do CGTrader só entram com licença confirmada (`docs/NOVOS_MODELOS.md`): por enquanto cabine e Canter são refeitos por código usando os modelos só como referência de proporção |
| 2026-10-17 | **Modelos de terceiros: só entram no jogo com licença confirmada (link e tipo) e com marcas/logotipos apagados; os arquivos originais nunca vão para o Git** (`docs/Novos modelos/` está no .gitignore) | T-115. **Proposta (2026-10-18), baseada no texto de licença que o Marco colou. Rótulos informados por ele: Van 01 (foad3d) = Royalty Free; International CF500 (dany-sanchez) = Royalty Free (no AI); Canter do CGTrader = Royalty Free, mas é outro arquivo (1.296 polígonos), diferente do `canter.obj` da pasta, que continua descartado; carro Suzuki = rótulo ainda não informado; Mercedes 3131 = Editorial (fora):** só licença "Royalty Free" do CGTrader (nunca "Editorial" nem "Custom" sem ler as condições); modelo entra reduzido e re-texturizado, nunca como arquivo original; no export, as pastas desses modelos vão em `.pck` criptografado (a licença Royalty Free exige medida razoável contra extração dos arquivos 3D); autor entra em `game/assets/LICENCAS.md` como crédito (as páginas de download pedem "Give credit to ..."). |
| 2026-10-17 | **Cabine "realista" (T-106), nas 4 cabines:** casca com cantos verticais mais redondos, frente levemente curva vista de cima e **recorte de verdade do arco da roda** (antes era um arco preto pintado por cima). Vidros, faróis, grade e frisos agora **acompanham a curva da casca** (`truck3d/cab_surface.py`: coordenada q ao redor da frente). Porta com vinco contornando a roda, janela com borracha, maçaneta em concha, fechadura, pega-mão, dobradiças aparentes só na clássica; espelho com haste e espelho grande-angular; espelho de canto do lado do passageiro (costume japonês); para-brisa envolvente com limpadores estacionados e grelha da caixa de ar; degraus rebaixados atrás da roda; para-lama com aba, forro da caixa de roda e protetor de lama; para-choque envolvente por perfil varrido (pintado no padrão/aero/alta, cromado com borracha na clássica); defletor de teto por loft. A faixa rosa desceu para a linha de cintura (1,62 m) para não cobrir a maçaneta. Triângulos: +2,5 mil por modelo (~4%) | Pedido do Marco: "melhorar a cabine, as portas e tudo mais, ficar o mais realista". Referência Volvo FH (docs/dekotora_volvo_3d_references/) |
| 2026-10-17 | **Texturas do caminhão feitas por código (numpy, `lib/tex_truck.py`), sem baixar nada:** pintura com sujeira por altura (poeira/lama embaixo, escorridos de chuva, lascas de pedra redondas, riscos), rugosidade variável (verniz brilhante, sujeira fosca) e mapa de normais (ondulação da chapa + casca de laranja); plástico preto com poeira clara embaixo; para-brisa com película de poeira fora dos arcos dos limpadores; grade em colmeia; grelha de fendas; chapa xadrez com relevo; pneu com banda gasta mais clara e flanco com poeira. UV "por altura" (`mesh3d.uv_height`). **Sem flocos metálicos por pixel** (não aparecem a 30 m e o PNG não comprimiria). Texturas extraídas pelo Godot marcadas como compressão de GPU (VRAM) e mapas de normais como tal | Mesmo pedido ("textura melhor, feita por você"). Custo: ~1,2–1,5 MB de textura por .glb (antes 0,06 MB); cada .glb carrega a sua cópia (ver pendência de texturas compartilhadas no STATUS) |
| 2026-10-17 | **Controle SÓ por faixas, em todas as plataformas** (celular e PC): 3 faixas + acostamento; 1º toque liga a seta, 2º toque no mesmo lado em até ~1,5 s executa a troca (~0,7 s). Volante livre e inclinação do celular saem. Trocar para faixa ocupada vira empurrão/batida lateral (é assim que se "fecha" o rival; não existe botão de bater). Curva: o caminhão segue a faixa sozinho (só escapa se entrar rápido demais) | Lote ATB-1 (referência Art Truck Battle, `docs/REFERENCIA_ART_TRUCK_BATTLE.md`). Decisão do Marco |
| 2026-10-17 | **Prazo de entrega:** tempo restante desce desde a largada; acabou o tempo = derrota. **Vitória = chegar primeiro E dentro do prazo**; chegar depois do rival = derrota | Lote ATB-1 (itens #1 e #2). Decisão do Marco |
| 2026-10-17 | **Rivais recusam o desafio por falta de fama e de destaque**; **nota de "destaque" calculada pelas peças**; **loja em duas abas: Decoração e Mecânica** | Lote ATB-2 (a implementar depois do lote ATB-1 testado). Decisão do Marco |
| 2026-10-17 | **Primeira pessoa: descartada** (só câmera externa) | Decisão do Marco, confirma a recusa anotada na análise de referência |
| 2026-10-17 | **Decoração Dekotora no caminhão base** (todas as cabines e baús): fileiras de luzes de marcação (laterais, traseira, "sobrancelha" da cabine), andon na frente do teto (銀河丸, "Ginga-maru", nome provisório do caminhão) e na traseira (街道爆走, nome do jogo), mural geométrico (sol poente, Fuji, ondas seigaiha, raio dourado) que substitui as tábuas e a faixa rosa das laterais. O mural é um PNG trocável; rivais tingem o mural com a cor deles | V7 do plano visual. Figuras (dragão, carpa) ficam para arte feita por pessoa/IA de imagem: basta trocar `murals/mural_side.png` |
| 2026-10-17 | **Cromo por matcap** (`ChromeMatcap`, texturas `matcap_chrome_night/day.png` geradas por `build_matcaps.py`): o ambiente pintado é SOMADO ao cromo PBR (nunca fica mais escuro), modo pela hora do dia; vale para caminhão e acessórios (cromo e dourado). Garagem usa o modo noite | V6. Antes o cromo ficava quase invisível à noite (sem reflexo de tela no Compatibility); comparação em docs/direcao_arte/cromo_*.png e na ferramenta scenes/tools/chrome_compare.tscn |
| 2026-10-17 | **Texturas CC0 do Poly Haven** (asfalto Asphalt 02, concreto Concrete Wall 008, 1k, registradas em assets/LICENCAS.md); mureta e boca de túnel com chuva escorrida (`concrete_streaks.png`); asfalto com trilhas de roda escuras, remendos e recapeamento por trecho (cor por vértice, sem custo); sujeira dos caminhões mais forte embaixo. **Efeitos de velocidade com chave em Opções > Gráficos:** linhas nas bordas (>110 km/h), tremor (>100 km/h), FOV maior, atraso da câmera na curva, clarão no Passing, faíscas ao raspar a mureta, reflexo falso das luzes no asfalto molhado, rastro das lanternas e chuva (desligada por padrão) | V4/V5 do plano visual. Metal pintado/escovado não foi baixado: o cromo será resolvido pelo matcap (V6). Custo: modo médio ~335–350 chamadas (antes ~330) |
| 2026-10-17 | **Estrada de via expressa japonesa (só visual, a simulação não mudou):** sem zebra; faixa amarela contínua nas curvas fortes (|curva| ≥ 0,9); 速度落とせ e "80" pintados antes delas; delineadores e olhos de gato que brilham à noite; pórticos verdes com kanji + romaji a cada 650 m; **a rota da cidade virou viaduto** (tabuleiro a 9 m, pilares, barreiras de som em trechos alternados, só no modo médio/alto); **túneis por rota** (`RouteDef.tunnels`: Tóquio 980–1280 m, Hakone 2080–2380 m) com luz de sódio pintada e luz laranja piscando sobre o caminhão | V3 do plano visual. Custo medido: ~315–345 chamadas no modo médio (antes ~330) |
| 2026-10-17 | **Hora do dia por rota** (`TimeOfDay`, presets night/dusk/day em `data/time/`; campo `time_of_day` no RouteDef). Proposta inicial: Tóquio = noite (A), Litoral = fim de tarde (B), Hakone = dia de verão com Fuji (C); `night` da rota acompanha (música e faróis). Substitui o protótipo do patch 02. Sombra continua só no modo alto | V1/V2 do plano visual. Marco escolhe a identidade principal em docs/DIRECAO_ARTE.md; trocar a hora de uma rota é uma linha no .tres |
| 2026-10-17 | **Plano visual (docs/PLANO_VISUAL.md) adotado.** O ambiente noturno do patch 02 (ceu com estrelas e lua, sem zebra rosa, asfalto umido, pocas de luz de sodio) e PROTOTIPO: sera refeito pelo sistema de hora do dia (V2). Efeitos novos so como truques baratos (sem SSR/GI no Compatibility), cada um com chave de qualidade | Analise visual do Marco em docs/dekotora_analise_visual/ (cara de IA: tudo no mesmo tom, sem luz que conta historia) |
| 2026-10-16 | **Salto de qualidade visual: apresentação em 3D real (plano B) com modelos PBR (.glb)**, mantendo a simulação igual. O plano A (sprites pixel art, `scenes/race/race.tscn`) continua no repositório como alternativa | Marco: "quero muito mais qualidade nas imagens finais" + pediu biblioteca de acessórios 3D PBR para Godot. A simulação é separada do visual, então trocar a apresentação não refaz a lógica. Decisão inferida dos pedidos: Marco confirma ou volta ao plano A |
| 2026-10-16 | Suposições de pagamento (docs/GDD não define): 1 Fama = 50 ¥ de bônus; cada ultrapassagem = 2 Fama; vácuo = +20% tração e +2 m/s; barra de Passing enche 4%/s acima de 70% da velocidade máxima e gasta 35%/s | Preencher lacunas do GDD para poder testar; ajustar jogando |
| 2026-10-16 | P40 (peças) segue `docs/PROMPT_ACESSORIOS_3D.md`: biblioteca de 32 acessórios 3D modulares (.glb + .blend + catálogo) em vez das 16 peças só em sprite. **Os sprites 2D continuam saindo desses mesmos modelos** (render ortográfico do pipeline atual), então plano A e plano B usam a mesma arte | Pedido do Marco. O texto de BALANCEAMENTO (16 peças com preço/peso) fica como base de dados; os 32 acessórios novos precisam de linhas de balanceamento (Claude propõe, Marco aprova) |
| 2026-10-15 | Nome do jogo: **Kaidō Bakusō — Chrome Legends** (tela: "KAIDO BAKUSO"). Pasta/repositório continuam `dekotora-legends`; "Dekotora" continua como nome do gênero | Pedido do Marco: nome novo com homenagem discreta ao original. "Bakusō" (爆走) vem de *Bakusō Dekotora Densetsu*; "Kaidō" = estrada; "Legends" = Densetsu. Provisório até o Marco aprovar |
| 2026-10-15 | Perfis do servidor em JSON (um por jogador), não SQLite | O Godot não traz SQLite embutido; para poucos amigos JSON basta; addon godot-sqlite se crescer |
| 2026-10-15 | Skills do projeto: blender-pixelart (com pxlib testado no Blender 5.2), godot-dekotora (comandos testados no Godot 4.7.1), arte-dekotora | Menos tentativa e erro; armadilhas já descobertas ficam registradas |
| 2026-10-15 | Time de agentes: coordenador (Sonnet), ajudante-rapido (Haiku), especialista (Opus), supervisor (Sonnet), com quadro e log compartilhados | Usar o modelo certo para cada esforço e dar visão total ao Marco |
| 2026-10-15 | Arte toda feita no Blender por scripts Python do Claude, renderizada como pixel art | Sem créditos no PixelLab; modelos 3D garantem ângulos e peças consistentes; teste de como o Claude se sai |
| 2026-10-15 | Multiplayer online 2–4 jogadores, servidor dedicado autoritativo em Godot headless | Jogar contra os amigos, com batidas e dano iguais para todos |
| 2026-10-15 | PC Windows além de Android, com jogo cruzado; foco continua no Android | Amigos podem jogar de qualquer lugar |
| 2026-10-15 | Peças têm peso, durabilidade e Fama; dano por zona; reparo custa dinheiro | Equilíbrio entre caminhão pesado/resistente e leve/frágil |
| 2026-10-15 | Peças de motor: 3 motores, 3 turbos, escape, freio-motor; som em camadas no ElevenLabs | Variedade de desempenho e de som |
| 2026-10-15 | Projeto pessoal, sem prazo | Fazer bem feito e aprender |
| 2026-10-14 | Godot 4 em vez de Unity; estrada pseudo-3D como plano A | Mais leve, grátis, melhor para 2D no celular |

## 2026-10-16 — Mercado de fretes com contratos (etapa G da UI premium; Marco: "pode seguir e fazer todos")

- Contrato = trecho + origem/destino (cidades do trecho, campo `places` do RouteDef) + tipo de carga (`data/cargo/*.tres`) + peso + valor.
- Capacidade do baú: leve 6 t, médio 12 t, longo 16 t (`Contracts.CAPACITY_T`). Contrato mais pesado que o baú aparece como "BAÚ PEQUENO".
- Valor = frete do trecho × multiplicador da carga × (0,8 + 0,6 × peso relativo na faixa da carga), de 50 em 50.
- O peso da carga entra na massa do caminhão do jogador (mais pesado = mais lento); a fragilidade multiplica o dano na carga
  (eletrônicos 1,8; louça 2,2; aço 0,5). Bots e multiplayer continuam com a carga padrão (4 t).
- O quadro é sorteado com semente salva no perfil: muda ao concluir um frete e ao tocar ATUALIZAR (sem custo).
  "Continuar" pega o contrato de maior valor do próximo trecho que caiba no baú.
- Suposições a revisar com o Marco: pesos, multiplicadores e se ATUALIZAR deve custar algo.

## 2026-10-18 — Placas de veículo e sinalização japonesa (T-130; Marco: "coloquei modelos de placa e sinalização, verificar e aplicar")

- Inventário em `docs/INVENTARIO_MODELOS.md`: nenhum modelo trazia placa de trânsito ou letreiro aproveitável; as placas de carro
  que existiam eram **fotos de placas reais** (Austrália no Fumi, Nova York no Camry) e não foram usadas. `Downloads\Tunnel.obj` e
  `Downloads\van.abc` (licença desconhecida, caminhos de outro PC) ficaram **fora do projeto** até o Marco mandar o link/licença.
- Placas **fictícias** feitas por código: atlas de 64 placas (`PlateCatalog`, 4 estilos reais: branca particular, amarela kei, verde
  comercial, preta kei comercial), cidades reais de Kanto/Tokai com números inventados. Caminhões = placa verde comercial 40 x 20 cm;
  carros = 33 x 16,5 cm; ônibus = verde grande; carros pequenos (hatch, kei) = amarela (1 em 5 preta).
- Todas as placas da corrida num **MultiMesh único** (1 chamada de desenho); a sinalização inteira em **2 chamadas** (faces com atlas +
  postes/costas). Materiais **sem luz por pixel** (claridade pela hora do dia), para não pagar passada extra de farol no Compatibility.
- Sinalização à **esquerda** (mão inglesa), em cima da mureta: limite 80 (litoral), 60 (cidade e montanha), 60/50 antes das curvas fortes;
  losango amarelo de curva/túnel/queda de pedras, chevrons por fora das curvas fortes (|curva| ≥ 0,9), painéis de km a cada 1,3 km,
  出口 perto do fim, placa com nome e "延長 300m" na boca do túnel (nomes inventados: 臨海トンネル, 仙石原トンネル) e 止まれ pintado
  no **acostamento** do pedágio (as faixas da corrida seguem livres). Losango de aviso no padrão japonês (não triângulo).
- Gancho barato para a placa do jogador: `profile.plate_cell` (célula do atlas) e `TruckNode.plate_cell`; ainda sem tela para escolher.
- Suposições a revisar com o Marco: limites por rota, densidade de placas, "止まれ" no pedágio, nomes dos túneis.


## 2026-10-18 — Telas com acabamento final (T-138, E1)

- **Telas presas às bordas**: `window/stretch/aspect = "expand"` (antes "keep", que punha faixas pretas nas laterais em celular
  20:9). A base continua 960x540; numa tela 2400x1080 o jogo enxerga 1200x540 e o espaço a mais vai para os lados. Menu,
  garagem, lobby, opções, pausa e resultado agora são montados com containers (margem + colunas), sem posições fixas em pixels.
  HUD da corrida e botões de toque acompanham a largura (botões da direita presos na borda direita).
- **Fundo do menu em 2 opções** (`MenuBackdrop`): **A = posto de estrada à noite com neon (padrão)** e B = rodovia à noite.
  O Marco troca em Opções > Gráficos > "Fundo da tela inicial" (`Settings.menu_bg`, troca na hora). O galpão antigo fica só por
  argumento (`--menu-bg=hall`) para comparar. Escolha do padrão é provisória: o Marco decide olhando `docs/capturas_t138/`.
- **Garagem**: câmera mais perto (caminhão ~60% da largura), cromo **neutro de estúdio** (`matcap_chrome_studio.png`, cinza com
  softbox, sem o azul da noite) e luz de preenchimento branca quente (antes ciano). A prévia de dia usa o cromo "day".
- **Rodas na garagem**: ficam paradas até o jogador tocar **VER EM MOVIMENTO** (barra de vistas), tocar numa roda ou instalar
  uma roda/calota nova. Trocar de vista desliga o giro. (Antes giravam sozinhas só na vista RODAS, T-133.)
- **Resultado**: tela nova por containers, centralizada. Título por desfecho (**"1º LUGAR"**, **"DERROTA"**, **"TEMPO ESGOTADO"**)
  e frases simples (`ResultText`): por que ganhou/perdeu, quanto da carga estragou e por quê (batidas, encostadas, dano no baú),
  peças quebradas/amassadas e a Fama. Na derrota e no tempo esgotado diz que o frete não é pago. A simulação passou a contar
  `cargo_hits`/`cargo_touches` (só contadores, sem mudar a física).
- **Textos**: todos os textos fixos das telas viraram chaves em `pt-BR.json` (lobby, opções, garagem, motivos de bloqueio);
  `tests/test_i18n_keys.gd` garante que toda chave usada existe e não está vazia. Nomes dos rivais ganharam acento
  (Trovão Rosa, Dragão de Aço).
- **Capturas**: `bash tools/ui_shots.sh 960x540 PASTA` (todas as telas). Para 2400x1080 use `1200x540`: a janela não passa do
  tamanho do monitor e, com essa configuração de stretch, o layout é idêntico (só muda a nitidez).
  `docs/capturas_t138/antes_960x540` (commit dc7c539) e `depois_960x540` / `depois_1200x540`. Não há "antes" em 20:9: o jogo
  antigo desenhava sempre 960x540 e o resto da tela do celular ficava com faixas pretas nas laterais.
## 2026-10-18 — Eventos de pista (T-139, pedido do Marco "C4: acidente, obras, estreitamento 3 para 2 faixas")

- **Três tipos**, sempre fechando faixas **vizinhas** e **nunca as 3**: acidente (1 ou 2 faixas, inclusive só a do meio), obras
  (1 ou 2 faixas) e estreitamento (só uma faixa **de fora** acaba). Formato de dado: `{kind, z, length, lanes:[1..3]}`
  (`RouteDef.events`), z = início do afunilamento; `length` inclui o afunilamento.
- **Mesma geometria para tudo**: a área fechada em cada z é um intervalo em x (`TrackEvents.interval`), que cresce suave no
  afunilamento (acidente 45 m, obras 60 m, estreitamento 120 m + 80 m de reabertura). Simulação, bots, trânsito, visual e HUD
  leem o MESMO intervalo (os cones ficam exatamente onde o caminhão bate).
- **Regras físicas** (`sim/event_contact.gd`): cone = −0,7 m/s e toque na carga a cada 5 m dentro do afunilamento; veículo
  parado/barreira = batida de frente com a massa de um carro parado (1.500 kg, `DamageModel`), o caminhão não atravessa, cai
  para 6 m/s e passa a mirar a faixa aberta mais perto; fim de faixa (estreitamento) = parede que empurra para dentro, raspando
  (perde velocidade e carga) e obriga a entrar na faixa vizinha (quem está ao lado disputa a vez pela colisão normal).
  **Faixa aberta só encostando na beirada** (escorregada na curva, empurrão) apenas raspa (sem batida). Trocar de faixa para
  uma faixa que fecha logo à frente é **recusado** (a seta continua piscando, HUD mostra "FAIXA FECHADA").
- **Obras com limite de 60 km/h** (pedido "limite de velocidade"): a regra escolhida foi **chapas de aço na faixa ao lado da
  obra**: acima de 65 km/h, a cada 0,5 s a carga sacode (`cargo_hit` pelo excesso × 0,25; sem dano no caminhão). É uma
  escolha do jogador: passar devagar (perde ~5 s) ou passar rápido e perder prêmio (a 100 km/h, ~8% numa obra curta).
  Bots e trânsito respeitam o limite. **Confirmar com o Marco** (alternativas: multa fixa em ¥, ou limite só visual).
- **Determinismo e rede**: eventos fixos da rota + até `random_events` (1) sorteados com `random_chance` (45%) pela semente
  da corrida (`RouteDef.build_events`; sem sorteio nos 650 m iniciais, nos 350 m finais, em túneis e nas curvas mais
  fechadas; 200 m livres entre eventos). Online o **servidor sorteia** e manda a lista no `race_setup` (campo `events`,
  protocolo versão 2); a regra da sala `events: false` desliga. O dano dos eventos vai pela atualização de dano normal.
- **Prazo estica** com os eventos (o cliente do frete "sabe" do acidente): acidente de 1 faixa +3 s, obras +7 s,
  estreitamento +3 s, 2 faixas fechadas +8 s (média medida da perda dos bots difíceis, `tools_dev/measure_event_times.gd`).
  O HUD mostra "PRAZO +N s" quando o aviso aparece.
- **Eventos fixos por rota** (propostas): litoral = estreitamento da faixa da direita em 1.650 m; viaduto = acidente nas faixas
  do meio e da direita em 2.000 m; montanha = obras na faixa da direita em 2.450 m.
- **Visual** (`road3d/track_events_3d.gd` + `event_props.gd`, atlas `assets/textures/event_atlas.png` feito por
  `tools_dev/make_event_atlas.gd`): 3 chamadas de desenho por evento (malha única com cones/barreiras/caminhão de obra/
  pintura, faces com atlas, luzes piscando por shader) + 2 carros batidos do trânsito no acidente (+8). Placas do evento do
  lado **direito** (canteiro), por dentro da mureta, para não brigar com a sinalização da esquerda nem com a barreira de som.
- **Som**: usa o que existe (cone = batida leve, raspada = batida leve 2, chapa = batida leve, aviso = bip da contagem);
  nomes pedidos ao ElevenLabs em `docs/AUDIO_ELEVENLABS.md` (`cone_hit`, `barrier_scrape`, `steel_plate_clank`,
  `event_alert_chime`, `roadworks_loop`), que entram sozinhos quando o arquivo existir.
- Suposições a revisar com o Marco: frequência do sorteio (45%), posição dos eventos fixos, a regra das chapas, os valores de folga
  do prazo, textos do HUD e se o acidente deveria ter viatura de polícia.

## 2026-10-19 · T-143: viatura e carro batido no acidente, jipe no trânsito

- **Licença**: Camry (viatura), jipe Suzuki e o carro batido são "Royalty Free License (no AI)", confirmado pelo Marco
  (`game/assets/LICENCAS.md`). Os originais continuam fora do Git; só os `.glb` reduzidos entram.
- **Viatura** (`car_police.glb`, 7,3 mil triângulos, 4 chamadas): pintura **japonesa genérica** (metade de baixo preta, de
  cima branca, divisa reta logo abaixo das maçanetas) no lugar do NYPD; sem textos, brasão, números, emblemas Toyota, grade
  com logotipo, placas e interior. **Giroflex só vermelho** (padrão do Japão; as lentes azuis do original viraram
  vermelhas), esquerda e direita piscando alternadas por shader (`road3d/police_beacon.gd`) + 2 brilhos no lote de luzes
  do evento (sem chamada a mais). A viatura **não anda no trânsito**: só aparece parada no acidente.
- **Acidente**: a viatura fica primeiro (a que o motorista encontra), um pouco atravessada na faixa ao lado da pista
  livre; o carro batido (picape amassada, `car_wreck.glb`, 6 mil triângulos, 2 chamadas) fica ~7 m depois, virado para o
  outro lado, com pisca-alerta só atrás (a frente está amassada). Cor do batido: azul, vermelho ou cinza escuro
  (contrasta com o preto/branco). Antes eram 2 carros comuns do trânsito.
- **Jipe** (`car_jeep.glb`, 5,1 mil triângulos, pintura trocável, letras "SUZUKI" apagadas) entrou no tipo CARRO do
  trânsito (9 modelos agora); comprimento 4,0 m para caber no hitbox de 4,5 m do tipo.
- **Carro batido sem materiais**: o arquivo só tem geometria (sem UV nem cores); a malha é refeita em voxels de 3 cm e
  alisada antes da redução (a original virava espinhos), e as cores saem da posição (rodas, interior, lanternas, fundo).
- Custo medido (viaduto à noite, modo médio, `--fps-log --quality=1`, parado no acidente): superfícies do evento 11 → 9,
  chamadas de desenho iguais (357/335/352 → 358/330/354), textura +0,4 MB, vídeo +1 MB, FPS igual (~74, limitado pelo monitor).
- Depuração nova: `--traffic-model=car_jeep` (todo carro comum do trânsito vira esse modelo, para capturas).

## 2026-10-19 — T-141 + T-144: força das batidas, arremesso do trânsito, freada forte e buzina

- **Força "igual ao original"** (referência `docs/REFERENCIA_ART_TRUCK_BATTLE.md` §2: no ATB quase não há batida dura;
  quem leva a batida lateral é **empurrado para a faixa vizinha**, com fumaça nos pneus). Regras (`sim/collision.gd`):
  - **Caminhão × caminhão de lado**: batida lateral acima de 2,5 m/s → quem entrava na faixa do outro (mais momento lateral)
    **empurra o outro uma faixa** para o lado (a faixa alvo dele muda; ele vai sozinho, com fumaça nos pneus por 0,9 s).
    Quem empurra precisa de **75% da massa** do outro; senão **quica de volta** para a própria faixa (Canter contra caminhão
    pesado). Encostado na mureta (acostamento) ou com a faixa vizinha fechada por evento → não sai do lugar e o outro quica.
    **Pode ser empurrado para o acostamento** (lento): é o "empurrão para fora" do GDD. **Confirmar com o Marco.**
  - **Caminhão × carro do trânsito**: troca de momento com restituição 0,45. Acima de 3 m/s de diferença o carro é
    **arremessado** (estado na simulação: `TrafficSim.Car.out_t/vx/yaw/yaw_rate/y/vy`, física em `sim/thrown_car.gd`): sai da
    linha do caminhão escorregando de lado, gira, quica nas batidas acima de 9 m/s (até ~0,7 m), bate na mureta e, quando
    para, o motorista endireita o carro e volta a andar. O caminhão de 12 t perde só a parte do momento que o carro leva
    (~1,5 m/s numa batida de 10 m/s). **Ônibus (12 t) não voa**: é empurrado e segura muito mais o caminhão.
  - Tudo determinístico (roda igual no servidor); online o snapshot leva giro e altura de cada carro (protocolo 3).
- **Freada forte** (`sim/hard_brake.gd`, já do WIP): freio ≥ 70% acima de 60 km/h perdendo ≥ 9 km/h por segundo. Só estado
  (não muda a física): chiado do freio, "pssh" do freio a ar ao soltar (se perdeu ≥ 4 m/s), fumaça branca nas rodas
  de trás, marcas pretas no asfalto (um MultiMesh), tremor leve e vibração no começo. Ícone vermelho no HUD.
- **Buzina**: tecla **H**, botão **X** do controle, botão **BUZINA** dourado na tela (entre as setas, do lado do polegar
  esquerdo). Segurar = som contínuo (a buzina básica) ou a melodia da peça instalada (buzina musical). O carro do trânsito
  **até 55 m à frente na mesma faixa sai da frente** se tiver faixa livre (efeito na simulação; os bots não buzinam).
  Vai pela rede (comando + bit no snapshot); os outros caminhões tocam com volume pela distância. Ícone dourado no HUD
  (seta · buzina · seta, como no original).
- **Visual das batidas** (`road3d/impact_fx.gd`): faíscas em risco presas ao caminhão (de frente saem pelos dois cantos,
  porque a câmera atrás do baú não vê o nariz), clarão rápido no ponto do impacto, até 64 pedaços (cromo, aço, lanterna
  vermelha/âmbar, vidro) num MultiMesh só (1 chamada), saindo com o embalo do caminhão por cima/do lado do baú,
  chacoalhada do caminhão atingido e tremor da câmera. Shaders aquecidos na largada (sem soluço na 1ª batida).
- **Chave nova em Opções > Gráficos: "Faíscas, pedaços e fumaça dos pneus"** (`Settings.fx_impact`): desliga faíscas,
  pedaços, peças caindo, chacoalhada/tremor das batidas e freadas, fumaça e marcas. A qualidade gráfica corta a
  quantidade (pedaços/faíscas ×0,4 / ×0,7 / ×1; fumaça 14 / 24 / 34 puffs).
- **Sons em camadas** (`audio/race_audio.gd`): pancada leve/pesada + estrondo de lataria (≥ 7 m/s) + lata com lata na lateral
  + pedaços espalhando (≥ 5 m/s) + peça quebrando; carro arremessado = lata fina + capotando (≥ 9 m/s) + vidro (≥ 12 m/s).
  Batidas dos outros caminhões agora se ouvem, mais baixo com a distância (até 150 m). 4 sons novos gerados no ElevenLabs
  (`truck_body_slam`, `truck_side_bang`, `chrome_debris_scatter`, `car_tumble`).
- Números em `docs/BALANCEAMENTO.md` (seção "Batidas: força e arremesso").

## 2026-10-19 — T-146: barreiras, placas e "Placão" de `docs/Novas Melhorias` (Royalty Free, no AI)

- **O pacote "Metais" não é guard-rail**: são barreiras de OBRA listradas e cavaletes. Por isso a **mureta contínua** e o
  guard-rail do litoral continuam os feitos por código (seguem as curvas sem emenda e custam 0 chamada a mais); as barreiras do
  pacote entram onde fazem sentido: obras (fileira contínua no lugar dos cones espaçados, depois do afunilamento), acidente
  (cavaletes + destroços), estreitamento (muro onde a faixa acaba) e bocas dos túneis (muro listrado na ponta da mureta, como
  nas vias expressas japonesas). A simulação não muda: as peças ficam no intervalo fechado que ela já usa.
- **Placas**: só a geometria do pacote (chapas com borda e poste); as faces continuam as japonesas fictícias da T-130 (a
  textura do pacote é uma captura de tela de propaganda com placas ocidentais). Octógono, braçadeiras e cintas ficaram de fora
  (o Japão não usa octógono na via expressa; braçadeiras ficam atrás da placa e eram 70% dos triângulos).
- **Placão** = pórtico de treliça americano: a treliça substitui as vigas de caixa dos pórticos e vira as pernas dos
  **outdoors** novos; as placas americanas (I-96, Detroit) não entram. **Outdoors** com arte trocável em PNG (4 artes fictícias
  nossas: 銀河運輸, 街道ラーメン, 安全運転, デコトラ祭), ~1 a cada 1,15 km, acesos à noite (sem luz por pixel). Proposta: o Marco
  pode trocar as artes (`game/assets/scenery/billboards/` ou `user://billboards/`).
- O vidro com moldura do `Grade1.png` (mesmo `.rar`) passou para a barreira de som do viaduto.
- Materiais feitos no código pelo NOME do material do .glb (`RoadsideKit`); peças pequenas de modelos diferentes juntadas por
  bloco de pista e por material (`MeshBatch`): 1 chamada por bloco visível. `--no-kit` volta ao visual antigo (comparar/medir).
- A barreira listrada tem um pouco de brilho próprio (tinta refletiva), mais à noite; a textura original é muito escura no
  renderizador Compatibility, então a cor foi clareada (×1,3).

## 2026-10-19 — T-152: batida no trânsito custa velocidade (pedido do Marco, F1)

- **Penalidade arcade na simulação** (`sim/collision.gd`, vale offline, bots e online): além da troca de momento da T-141,
  o caminhão fica com no máximo `velocidade_antes × (1 − penalidade)`. De frente na traseira do carro **25–40%** (cresce
  com a força entre 2 e 12 m/s de diferença), **raspão lateral 8–15%** (entre 1,5 e 6 m/s), veículo de mais de 3 t
  (**ônibus**; vale para futuros caminhões do trânsito) **× 1,35**. Não existe caminhão/van grande no trânsito hoje (a "van"
  é do tipo carro, 1,5 t). Números em `docs/BALANCEAMENTO.md`.
- **Tranco de 0,6 s** (`TruckSim.jolt_t`): acelerador sem efeito (o motor não puxa; o freio funciona; o freio-motor entra
  como ao soltar o pé), o caminhão **balança** (arfagem na batida de frente, rolagem no raspão; `road3d/impact_fx.gd`, no
  relógio da tela, não depende da chave de efeitos) e a câmera acompanha um pouco (depende da chave). **Velocímetro
  vermelho** enquanto dura (`ui/race_hud.gd`). O tranco também é a recarga: **uma penalidade por batida**, mesmo com
  contatos em ticks seguidos (ou outro carro dentro dos 0,6 s).
- **Online**: o tranco vai no snapshot em ticks (+1 byte e 2 bits por caminhão) → **protocolo 4** (gere o APK de novo).
  O cliente suaviza o recuo do 1º snapshot com a batida (até 6 m) em vez de teleportar.
- Só batida com o **trânsito**. Batida caminhão × caminhão e veículos parados dos eventos continuam como antes
  (**confirmar com o Marco** se quer o tranco também nelas).
- **Efeito colateral a decidir**: o câmbio automático não reduz marcha depois da batida (fica na 6ª a ~60 km/h e
  recupera devagar), então uma batida de frente de 40% a 100 km/h custa ~10 s numa reta (raspão ~2–3 s). Com redução
  automática ("kickdown") custaria ~7,5 s. Não mexi no câmbio sem o Marco decidir.

## 2026-10-19 — T-154: ferrovia ao lado da rodovia, trens e viadutos de trem (pedido do Marco, F3)

- **Origem dos modelos**: a busca não achou nenhum pacote de ferrovia (nem em `docs/`, nem em Downloads, que agora está
  vazia: `Tunnel.obj`, `van.abc` e os zips sumiram). Tudo da ferrovia é **feito por código** em
  `blender/scripts/build_railway_kit.py` (determinístico), menos o **bonde**: o CAF Urbos 3 de `docs/Modelos Melhorados/`
  (SKETCHFAB Standard, royalty free, crédito não obrigatório), sem o interior, 71 mil → 6,9 mil triângulos, **verde de
  Kaohsiung trocado por amarelo** (a ideia do "trem amarelo em paralelo" do Art Truck Battle, sem copiar) e logotipos apagados.
  O trem de carga (locomotiva vermelha com faixa creme e frente amarela, contêineres de cores lisas) é fictício.
- **Onde** (tabela em `docs/INVENTARIO_MODELOS.md`): sempre do lado da terra (esquerda; no litoral o mar fica à direita), longe
  da mureta, das árvores (até ~23 m) e dos outdoors (26 m): 36–40 m do centro da pista. Fica fora dos trechos de 2 faixas que a
  T-153 está fazendo (litoral 2.270–2.890 m com a ponte; montanha 650–1.190 m com o túnel antigo) e entra/sai do morro do túnel
  da montanha por uma boca própria. Na cidade a linha é elevada na altura da via expressa e passa ao lado da caixa do túnel.
  **Viaduto de trem por cima da pista** na cidade (1.500 m) e na montanha (240 m, logo depois do pedágio), 8,5 m acima do
  asfalto; os prédios da cidade que cairiam em cima dele são retirados (`CityBuilder.keep_out`; o sorteio dos outros não muda).
- **Quando passa o trem** (`road3d/rail_traffic.gd`): só visual, sem colisão nem efeito na corrida, relógio próprio (não vai
  pela rede: cada jogador vê os seus trens). O 1º trem passa ~10 s depois da largada; depois um a cada 22–40 s, marcado para
  cruzar com o jogador 7 s depois, no mesmo sentido (o caminhão ultrapassa o trem, ou o trem ultrapassa quem está parado) ou no
  contrário; cada sentido anda na via da esquerda (mão inglesa, como no Japão). No viaduto que cruza a pista, um trem de carga
  é marcado uma vez por corrida para estar em cima da pista quando o jogador passar embaixo. Trem principal: carga no litoral e
  na montanha, bonde amarelo na cidade (o outro aparece em ~30% das passagens).
- **À noite**: janelas do bonde acesas, faróis e lanternas da locomotiva, brilho do farol (quadrado aditivo, sem luz real).
- **Celular**: via, trilhos, muro, fios, tabuleiro, pórticos, pilares e bocas usam UMA textura (`rail_bed.png`, 1024 px) e
  ficam juntos num bloco de 300 m = 1 chamada de desenho por bloco visível, corte a 560 m (400 m no modo baixo); fios só a
  partir do modo médio; pórticos a cada 100 m no modo baixo; trens num MultiMesh por modelo (no máximo 5 chamadas com trem
  à vista, nada sem trem), vagão a mais de 700 m não é desenhado. `--no-rail` desliga tudo (comparar/medir).
- **Pendências do Marco**: confirmar o uso do bonde (licença Sketchfab Standard) e a pintura amarela; aprovar onde ficam as
  linhas e os viadutos, a frequência dos trens e a pintura do trem de carga; **som** do trem (não existe; proposta de 2 sons
  no ElevenLabs: passagem de trem de carga e apito japonês curto — não gerados).

## 2026-10-20 — T-156: abertura "frente a frente", campanha 1 contra 1 e comboio (pedido do Marco, G1)

- **Decisão do Marco**: campanha sempre 1 contra 1; amigos 2 a 4, com 3–4 no modo **comboio** (trânsito mais leve).
  Corrida rápida ficou com 4 caminhões (não citada; confirmar).
- **Onde é a cena**: um cenário pequeno montado 400 m abaixo do mundo da corrida (`DuelStage.ORIGIN`), com o céu, a
  névoa e o sol da rota; os 2 caminhões DE VERDADE (mesmos nós da corrida) são levados para lá e voltam para a pista no
  fim. Noite e fim de tarde (`TimeOfDay.headlights`) = área de descanso; dia = praça de pedágio. Nada de modelo novo:
  caixas juntas por material (MeshBatch), `toll_gate.glb`, pinheiros, barreiras e outdoor do kit da T-146.
- **Tempos** (`DuelPlan`): frente a frente 1,4 s · jogador 1,8 s (para-choque, viseira/andon, mural) · rival 2,0 s
  (viseira/andon, para-choque, mural; buzina de provocação) · VS 1,2 s (tambor) · contagem 3 s (alinhamento 1,4 s +
  corte lateral de sempre). Total 9,4 s. Pular = vai direto para a contagem.
- **Revanche** = mesma rota e mesmo rival da última abertura mostrada (guardado só na memória: fechar o jogo zera).
  Online a sala não volta ao lobby depois da corrida, então a regra "mesma dupla e mesma rota" do servidor fica pronta
  mas ainda não acontece.
- **Grid**: largada lado a lado a 30 m do começo da pista. 1 contra 1 com a faixa do meio livre (jogador à direita,
  rival à esquerda); 3–4 = três lado a lado + 1 atrás. Antes os caminhões de trás (−14, −28, −42 m) eram desenhados todos
  em z = 0, um em cima do outro, e a câmera da contagem ficava em cima do baú do jogador.
- **Rival**: 8 s sem duelo depois da largada, não fecha quem está no acostamento e não anda abaixo de 80% do ritmo
  dele para ficar ao lado (antes, lado a lado, os dois estouravam o prazo em todas as rotas). Ver `BALANCEAMENTO.md`.
- **Faixa**: brasão com 1 kanji na cor do caminhão no lugar do retrato (não há retratos); nome do motorista (Opções >
  nome do jogador; online o nome da sala), nome do caminhão (jogador: Ginga-maru 銀河丸, o andon dele; rivais: nomes
  novos), destaque calculado das peças e uma fala curta original em pt-BR.


## 2026-10-20 — T-166: licenças dos modelos de terceiros liberadas pelo Marco

- **Decisão do Marco (2026-10-20):** "todas [as licenças dos modelos de terceiros] podemos usar, pode usar sem preocupação".
- Vale para: `Tunnel.obj` (T-130), `van.abc` (T-130), o túnel de `docs/Modelos/Road_pontes` (T-159), o bonde
  `kaohsiung_circular_light_rail_caf_urbos_3` (T-154) e os demais modelos de terceiros.
- Consequência: a parte de **licença** deixa de ser pendência. Continua valendo o que já está em `game/assets/LICENCAS.md`
  (crédito do autor onde o arquivo indica) e a escolha de uso de cada item, que segue como pendência de design.
- `Tunnel.obj` e `van.abc` não estão mais no PC (pasta Downloads vazia): para usá-los, o Marco precisa recolocá-los em `docs/Modelos/`.


## 2026-10-20 — T-165: listas do menu/garagem rolam arrastando o dedo sobre os cartões

- **Problema (Marco, APK no celular):** escolher cabine/modelo/peças arrastando o dedo "às vezes não vai".
- **Causa:** no Godot 4.7 o `ScrollContainer` só rola pelo toque se receber o evento; botões, cartões e painéis vêm com
  `mouse_filter = STOP` e seguram o toque. O arraste só funcionava começando nos vãos entre os cartões.
- **Regra nova:** toda lista com rolagem usa `TouchScroll` (`game/scripts/ui/components/touch_scroll.gd`) no lugar de
  `ScrollContainer`. Ele troca STOP por PASS em tudo que estiver dentro (inclusive o que for criado depois), menos
  controles com arraste próprio (slider, barra, campo de texto, outra lista), e fica ele mesmo STOP (o toque não vaza
  para o palco 3D atrás).
- **Zona morta de 10 unidades** (tela base 960×540, ≈ 20 px no celular): toque com o dedo tremendo continua sendo toque;
  passou disso vira rolagem e o cartão **não** é selecionado ao soltar.
- No PC: clicar e arrastar com o mouse sobre um cartão também rola a lista (já rolava nos vãos); clique simples,
  roda do mouse, teclado e controle continuam iguais. Teste: `game/tests/test_touch_scroll.gd`.


## 2026-10-21 — T-169: modelos de docs/Modelos aplicados (com T-163 e T-164)

- **Pedido do Marco:** usar o que fizer sentido de todos os arquivos de `docs/Modelos` (novos: `Agua`, `Arvore`,
  `Fundo Montanha Gelo`, `poste`; e os antigos). Licença liberada para todos. Créditos em `game/assets/LICENCAS.md`.
- **Montanhas do horizonte** (`blender/scripts/build_backdrop_kit.py`, `road3d/backdrop_kit.gd`, `CityBuilder._massifs`):
  o relevo de 6,3 milhões de triângulos virou um mapa de altura 512 x 512; os 4 maiores maciços foram refeitos como malha
  de 899 triângulos com a neve marcada na cor por vértice. No jogo: montanha 16, litoral 10 (só do lado da terra), cidade
  6; 750–1.250 m de largura, pé a 260–560 m da pista (empurrado para fora onde a pista faz curva). Neve: cheia na
  montanha, só nos picos no litoral e na cidade; à noite azulada. 4 chamadas (antes 1).
- **Mar:** o mapa de normais das ondas vem da placa "Water Pack Ozero" (alturas → normal 512 px repetível), no mesmo
  shader de antes.
- **Árvore de folhas** (`blender/scripts/build_tree_kit.py`): Gleditsia de 436 mil → 279 triângulos (tronco reduzido +
  20 tufos em cartões cruzados; textura 512 px com 4 tufos renderizados da copa original), 6,5 m. Cidade: no lugar da
  redonda; montanha: 25% (entre os pinheiros); litoral: 20% do lado da terra (as palmeiras continuam).
- **Poste:** o poste de energia da T-163 ganhou a coluna de concreto (raio 0,18 → 0,10 m), a caixa e o suporte em U do
  poste novo (222/256 triângulos). Os cabos e as placas de ponto de ônibus de Helsinque do arquivo não entram.
- **T-163 (trazido do worktree parado):** pilar em T da Ponte A nas pontes/viadutos, guard-rail em W varrido na curva do
  litoral, postes de energia com fios na montanha e no litoral (lado da terra, a 17 m, a cada 35 m).
- **T-164 viaduto rodoviário por cima** (`road3d/overpass_layout.gd`, `overpass_3d.gd`): módulos de 10 m da seção da
  crista da Ponte A (482 triângulos perto da pista, 68 longe), reto e plano até 320 m de cada lado (para antes se for
  passar baixo sobre outro trecho da rota), pilares em T a cada 40 m perto e colunas longe; vão livre ≥ 7,6 m medido no
  ponto mais alto da pista embaixo (cidade fica com ~9,3 m por causa da rampa). Cidade 2.050 m (antes do trecho antigo
  de 2 faixas), montanha 2.580 m (passa sobre a pista e a ferrovia). Postes, árvores, placas e prédios saem de baixo; os
  fios de energia são cortados ali. 1 chamada por viaduto à vista.
- **T-164 semáforos de faixa** (`road3d/tunnel_signals_3d.gd`): pórtico na boca e a cada 200 m de cada túnel, um sinal
  por faixa (2 no túnel antigo); X vermelho se um evento de faixa fechada (acidente, obra, estreitamento) começa até
  600 m depois do pórtico ou já fecha a faixa ali; senão seta verde. Usa a mesma lista de eventos da simulação (online
  também). 2 chamadas por túnel à vista.
- **Ficou de fora:** pórtico "Outdor" (placas reais da Califórnia, já temos pórticos), ponte pênsil (estreita, europeia),
  ponte A inteira como pista, túnel do arquivo inteiro (reto; virou referência), Canter `canter.obj` (extraído de outro
  jogo e o Canter do JAC já existe), carreta do Kenworth (2 milhões de triângulos; proposta para outra tarefa),
  `Tunnel.obj`/`van.abc` de Downloads (não estão no PC; o túnel de `Road_pontes` é o mesmo arquivo).
- **Custo medido** (modo médio, noite, sem vsync, 6 pontos; `bash tools/measure_t169.sh`): chamadas +6 a +11,
  triângulos +0 a +19 mil (máximo na cidade perto do viaduto), textura +0,6 a +0,8 MB, FPS igual dentro do ruído do PC.
- **Confirmar com o Marco:** quantidade/altura das montanhas e a neve no litoral/cidade; mistura das árvores; lugar dos
  2 viadutos; se o semáforo deve mostrar também a seta amarela (troca de faixa) além do X.
## 2026-10-20 — T-170: som da seta (pisca) ao tocar em < ou > (pedido do Marco)

- **O que "seta" é no jogo**: o pisca de troca de faixa que JÁ existia (ATB-1): 1º toque em < / > (A/D ou setas do
  teclado) liga a seta (`TruckSim.signal_dir`, 4 lâmpadas âmbar no `TruckNode`, setas no HUD); 2º toque no mesmo lado
  dentro de 1,5 s troca de faixa. O pedido "quero som de seta, quando eu clico nele" foi atendido nesse pisca, **sem
  botões nem teclas novas** (Q/E e botões de pisca separados ficaram de fora: seriam um segundo pisca na tela, confuso).
  Se o Marco quiser um pisca manual que fica ligado até desligar, é outra tarefa (ver STATUS, pendências).
- **Ritmo**: o pisca passou de ~3 Hz (relógio global) para **~1,5 Hz** (0,33 s aceso / 0,33 s apagado, como um
  caminhão de verdade) e **começa aceso no toque** (antes podia demorar até 0,16 s; as setas curtas dos bots às vezes
  nem acendiam). Lâmpadas, HUD e som usam o mesmo `SignalBlink` (`scripts/truck/signal_blink.gd`). Na janela de 1,5 s
  a lâmpada acende 3 vezes.
- **Som** (`scripts/audio/turn_signal_audio.gd`, só do jogador): `turn_signal_tick` (relé) a cada acender (tom normal)
  e apagar (tom 0,86, mais grave), em sincronia com a lâmpada — por isso NÃO é um arquivo em loop (o ritmo de um loop
  gerado não bateria com a lâmpada); `turn_signal_switch` (alavanca) a cada toque em < ou > (borda de
  `TruckSim.tap_prev`; não usa `lane_changes`, que online pode contar o mesmo toque duas vezes na reconciliação).
  Barramento SFX: volume de efeitos e mudo das Opções valem. Gerados no ElevenLabs (~0 créditos visíveis; conta em
  61.234 de 131.000).
- **Só apresentação**: nada mudou em `sim/` nem na rede. Online os piscas dos outros já apareciam (o `signal_dir` vai no
  snapshot); o som é só da sua seta. Ideia anotada: ouvir baixinho a seta do rival ao lado.

## 2026-10-21 — T-171: prévia de peças na garagem e pneus sobre a plataforma (pedido do Marco)

- **Pneu "enterrado"**: os .glb estão certos (pneu em y = 0 nos 18 modelos, medido por
  `tools_dev/measure_wheel_ground.gd`), mas a plataforma giratória do galpão (`garage_hall.glb`, malha `turntable`) tem
  10 cm de altura e o caminhão nascia no piso (y = 0): o pneu afundava 10 cm dentro do disco. Agora o `GarageStage`
  mede o topo da plataforma e o ponto mais baixo dos pneus (`TruckGround`) e sobe o caminhão (`floor_y`, ~0,10 m).
  Vale para garagem, lobby e o fundo antigo do menu (todos usam o `GarageStage`). **A corrida não muda** (o
  `TruckNode` continua com o pneu em y = 0 na pista).
- **Prévia** (`ui/garage_preview.gd` = estado, `ui/garage_preview_ui.gd` = tela): tocar/clicar num cartão de peça não
  instalada (ou chegar nele com setas/Tab/controle) monta a peça no caminhão no lugar da do mesmo encaixe, leva a câmera
  para a vista dela (calotas: vista da roda, girando) e mostra a faixa **PRÉVIA** no topo do painel direito (fora da
  rolagem, para não cobrir a peça) e a etiqueta "◉ PRÉVIA · nome" no alto da tela. Botões: **COMPRAR E EQUIPAR**
  (compra e já instala; desligado com o motivo se faltar Fama/dinheiro), **EQUIPAR** (já é sua) e **VOLTAR AO ATUAL**
  (ou Esc / B). Trocar de encaixe, de aba ou sair da garagem volta ao equipado. Nada entra no perfil até comprar.
- Arrastar a lista sobre um cartão continua rolando (T-165): só conta como toque se o dedo soltar a até 12 unidades de
  onde apertou; toque nos botões do cartão fica com o botão.
- **Cores travadas por Fama** agora podem ser tocadas para ver no caminhão (antes ficavam desligadas); continuam sem poder
  aplicar. Cores liberadas, luzes e adesivos já aplicavam na hora (grátis), então não precisam de prévia.
- **Mecânica** (motor, turbo, escape, freio-motor, pneus esportivos) não tem peça visível no caminhão: a prévia continua
  sendo o efeito em texto (peso, 0–100, destaque). Os escapamentos altos são peça de encaixe e têm prévia 3D.
- Decisão do Claude (confirmar com o Marco): o botão da faixa compra **e instala** de uma vez; o cartão continua com
  COMPRAR (só comprar) como antes.
## 2026-10-21 — T-172: peças "deluxe" (amostras de acabamento fino) — PROPOSTAS, Marco valida

- **Pedido**: "muito detalhe para as peças como neon, pisca, [estura], baú em cima da cabine igual ao Bakusou Dekotora
  Densetsu". **"estura"** foi lido como **estrutura lateral** (a サイドバンパー, armação cromada com luzes embaixo do baú)
  **e estribo** (degrau da cabine): saíram as duas peças. Se era "escapamento", os escapamentos altos cromados já existem
  (`kw_exhaust_stacks`, T-126). **"baú em cima da cabine"** = a caixa de luz alta (andon "Ichibanboshi" 一番星) sobre o
  teto da cabine, virada para a frente.
- **6 amostras** (`blender/scripts/accessories/deluxe.py`, até 6.000 triângulos cada, marcadas `tier: "deluxe"` no
  catálogo): andon de cabine 一番星, coroa de lanternas de ônibus, neon de chão, estrutura lateral cromada, estribo
  iluminado, barra de 16 lanternas. Entram como **opções a mais** nos encaixes que já existem (andon, luzes de teto, saias,
  degraus, lanternas traseiras); as 42 peças antigas continuam iguais.
- **Encaixe novo `underglow` ("Neon de chão")**: o neon de chão fica embaixo do chassi e pode ser usado junto com as saias.
- **Luz que acompanha dia/noite**: o brilho no asfalto (neon de chão e luz de cortesia do estribo) e a face de acrílico do
  andon seguem a mesma força das luzinhas (`TruckNode.set_lights_on`): de dia o chão quase não brilha (0,04) e o acrílico
  fica em 1/4; de noite e nos túneis acendem. As lentes âmbar piscam com o padrão de luzes escolhido na garagem.
- **Preço/peso/Destaque**: propostas em `docs/BALANCEAMENTO.md` (seção T-172).
- **Pendente do Marco**: olhar `docs/capturas_t172/` e dizer se o nível de acabamento está bom e se seguimos para mais
  peças (frente: para-choque/viseira/grade; traseira: andon traseiro; laterais: painéis "uroko" no baú).

## 2026-10-21 — T-177: rolagem das listas refeita (PC e celular) e DECORAÇÃO com seções

- **Causa** (relato do Marco: "no PC a lista segue a seta do mouse e não o scroll"; "no celular não chego nas peças"): o
  arraste nativo do `ScrollContainer` ficava preso em "arrastando" quando o botão clicado redesenhava a lista (a garagem
  redesenha em todo clique; o "soltar" sumia junto com o botão). Depois disso a lista seguia o mouse sem botão e desfazia a
  roda. No celular, os 28 encaixes de PEÇAS ficavam no fim de uma lista de ~2.700 unidades, depois de pintura, luzes e adesivos.
- **Rolagem** (`TouchScroll`, vale para garagem, Mercado, Opções e lobby): o arraste agora é do próprio `TouchScroll`.
  Só rola com botão esquerdo/dedo apertado; roda do mouse rola 1/8 da altura visível por clique e não mexe mais na câmera
  da garagem quando o mouse está sobre a lista; arrastar com o mouse também rola no PC; soltar com o dedo correndo dá
  embalo; tocar durante o embalo só para a lista. Toque parado (até 10 unidades) continua selecionando.
- **Prévia (T-171)**: arrastar sobre um cartão de peça não abre mais a prévia (antes abria se o dedo andasse até 12 unidades).
- **DECORAÇÃO** (mudança de tela, sem mudar regras do jogo): barra fixa **PEÇAS / PINTURA / LUZES / ADESIVOS** logo abaixo
  das abas, fora da rolagem; abre em PEÇAS. Os encaixes vêm primeiro, em 2 colunas, agrupados por lugar (FRENTE, TETO,
  LATERAIS, TRASEIRA), com ✔ e cor dourada quando há peça instalada (o nome da peça instalada aparece no painel da direita).
  O resumo (destaque, massa, proteção) foi para o fim da seção PEÇAS. Decisão do Claude; o Marco confirma no aparelho.

## 2026-10-21 — T-178: turbina sem "som de música", motores mais caminhão, V8 de monster truck (pedido do Marco)

- **Turbina**: o assobio é sopro de ar com um assobio metálico fraco por cima (não uma nota). O tom sobe só ~6 semitons
  com o boost (0,85→1,2; antes 0,8→1,5). O "pssh" é um sopro pneumático, sem a vibração "stu-tu-tu".
- **Motores**: 6 cilindros e perfis de escape = diesel de caminhão pesado (semi truck). **V8 = monster truck de corrida**
  (marcha lenta picada, estalos e rasgado nos escapes abertos). Prompts em `docs/AUDIO_ELEVENLABS.md`.
- **Regra para prompts de som**: não usar palavras que puxam tom ou ritmo (whine, constant pitch, siren, chirp, flutter,
  rhythmic, drone). Gerar 2 a 3 versões em `--out-dir` e escolher por análise antes de pôr no jogo.
- **Pendente do Marco**: ouvir (garagem > MECÂNICA > OUVIR, ou `audio_backup/t178_previas_ouvir/antes|depois`) e dizer
  qual som ainda não está bom.

## 2026-10-21 — T-179: montanhas nevadas e árvores da T-169 não apareciam na corrida — CORRIGIDO

- **Pergunta do Marco**: "os itens que coloquei (montanha, árvores...) não foram implementados?". Estavam no jogo e no APK
  (conferido dentro do `kaido-bakuso-debug.apk` de 2026-10-21 e num `.pck` exportado), mas **não se viam**:
  1. **Bug**: os 4 maciços (`mountain_a..d.glb`) saíram **do avesso** do Blender (`recalc_face_normals` numa casca aberta
     escolheu "para baixo"; 899 de 899 triângulos virados para baixo). O jogo mostrava o lado de dentro da encosta de trás:
     escuro, sem neve, parecendo "lâminas rasgadas". Corrigido em `build_backdrop_kit.py` e regerado.
  2. **Bug**: a câmera da corrida via só até **900 m** e os maciços ficavam a 0,6–1,2 km: o fundo deles era cortado.
     Agora `_cam.far = BackdropKit.CAMERA_FAR` (8 km). Custo medido no PC (modo médio, 6 pontos, noite): chamadas e
     triângulos iguais, FPS no ruído (com near de 0,2 m a precisão de profundidade quase não depende do "far").
     Depuração: `--view-far=900` volta ao antigo.
  3. **Visual (ajustado)**: a neblina do jogo (feita para 300–600 m) apagava as montanhas na tarde (litoral) e na noite
     (cidade). O shader da montanha tem neblina própria leve (`fog_disabled`; no máximo 35% de dia/noite e 50% na tarde) e
     a neve brilha um pouco à noite (luar).
  4. **Visual (ajustado)**: eram poucos maciços, pequenos e perto (6 na cidade, escondidos atrás dos prédios). Agora é
     uma cordilheira: 18 (montanha), 12 (litoral, lado da terra), 12 (cidade e corrida rápida); 1,6–3 km de largura, pé
     a 0,9–2 km da pista; modo baixo = metade. Neve: montanha cheia; litoral/cidade nas encostas altas (0,8; antes 0,45 =
     só as pontas). Continuam 4 chamadas de desenho no total.
  5. **Árvore de folhas**: já aparecia no litoral e na montanha, mas era minoria; agora 35% (antes 20% no litoral e 25%
     na montanha). Na cidade a pista é elevada e as árvores ficam lá embaixo (de noite quase não se veem): sem mudança.
- Viaduto por cima (2.050 m da cidade, 2.580 m da montanha), semáforos de faixa (túneis), postes com fios (litoral e
  montanha), guard-rail em W e mar com ondas **já apareciam**; viaduto e semáforos só existem nesses pontos/rotas.
- **Para o Marco confirmar**: quantidade, tamanho e neve das montanhas (`docs/capturas_t179/`).

## 2026-10-21 — T-181: câmera livre de exploração (pedido do Marco)

- **Online: desligada** (F1, `--freecam` e o botão da pausa não existem na corrida em rede). A outra opção era só congelar
  o visual local, mas o caminhão do jogador continuaria correndo no servidor sem comando (bateria/perderia a corrida) e a
  predição do cliente acumularia erro. Como a ferramenta é para achar defeitos do mapa, a corrida offline basta.
- **Congelar** = a cena da corrida pula o `_process` inteiro (simulação, bots, câmera, HUD, som do motor); o som geral fica
  mudo enquanto explora e volta como estava. Nada em `scripts/sim/` sabe da câmera livre.
- **Quem pode**: build de debug sempre (inclui o APK de teste: botão CÂMERA LIVRE na pausa); versão final só com Opções >
  Avançado > Modo explorador ou `--freecam`. No PC os sticks aparecem só com `--touch` ou com "botões na tela" (o projeto
  emula toque pelo mouse, então o Godot diz que o PC tem tela de toque).
- **Mira** sem física: o raio é testado contra os triângulos visíveis (o cenário não tem colisão). Para mostrar o `.glb`,
  as malhas copiadas dos kits guardam o caminho no `resource_name` e os lotes `MeshBatch` guardam a lista de peças (meta
  `pieces`); custo zero quando a câmera está desligada (só memória das listas, pequena).
- Teclas extras não pedidas: Esc também sai; T aceita metros (`800 m`); o nome do print também leva a rota.

## 2026-10-21 — T-183: carro do trânsito batido vira carro ACIDENTADO (pedido do Marco)

- **Antes**: o carro arremessado girava ~2 s e depois o motorista endireitava (0,9 rad/s) e voltava à velocidade de
  cruzeiro. **Agora** ele nunca volta a andar: desliza e gira até parar (6,5 m/s² enquanto está fora de controle,
  depois **9 m/s²** arrastando de lado; escolha do Claude para não deslizar ~90 m), fica no ângulo em que parou (não
  endireita), atravessado na faixa ou jogado no acostamento.
- Só vira acidentado quem é **arremessado** (batida a partir de 3 m/s, carro até 3 t). Encostão fraco só empurra e o
  ônibus nunca vira acidentado (regras da T-141, iguais).
- **Obstáculo na simulação** (`sim/wreck.gd`): o carro ocupa a pista pelo corpo **girado** (retângulo em volta do carro,
  pivô no eixo traseiro, igual ao desenho), não pela faixa. Caminhões batem nele com a mesma física de antes (de novo
  arremessa/empurra, ele para de novo e continua acidentado). Carros do trânsito atrás trocam de faixa ou freiam e esperam
  a vez; se não conseguirem frear, encostam, ficam atrás e o empurram um pouco (não atravessam). Carro parado não dá vácuo.
- **Bots**: enxergam o acidentado 1,2 s mais longe que um carro normal e desviam **na hora** (sem a demora de "preso no
  trânsito"). Sem faixa de rolagem livre, usam o acostamento vizinho para passar (escolha do Claude: antes ficavam presos
  para sempre atrás de um acidentado entre duas faixas). Ajuste junto: a freada planejada do bot para o limite das obras
  passou de 1,8 para 1,5 m/s² (o freio proporcional atrasava ~1,44 m/s, mais que a tolerância de 5 km/h; apareceu com o
  trânsito novo no teste das obras).
- **Some** quando está a **300 m** atrás do último caminhão (carro normal: 150 m) e volta como carro novo à frente do líder.
- **Visual** (`road3d/wreck_fx.gd`, só lê o estado): pisca-alerta nas 4 pontas (os modelos não têm seta separada: são 4
  lâmpadas âmbar feitas por código, com brilho), todas juntas no ritmo da seta (`SignalBlink`, ~1,5 Hz) pelo relógio
  visual; fumaça cinza leve saindo do capô por 12 s depois da batida (chave "Faíscas, pedaços e fumaça"); triângulo
  vermelho no chão **9 m atrás** do carro, colocado 3 s depois da batida e só quando o carro parou. Custo: 2 chamadas de
  desenho por acidentado + 1 do triângulo + fumaça nos primeiros 12 s.
- **Rede**: protocolo 8 (1 byte por carro no snapshot). Para o Marco confirmar: duração da fumaça, distância do triângulo,
  9 m/s² de arrasto, 300 m para sumir, bots usarem o acostamento.

### T-183 — números do carro acidentado confirmados pelo Marco (2026-10-21)
Marco aprovou: fumaça por 12 s, triângulo 9 m atrás (após 3 s), freada de 9 m/s² enquanto arrasta, sumir a 300 m atrás do último caminhão, bots usam o acostamento quando não há faixa livre.

## 2026-10-21 — T-186: todas as árvores, os 2 postes e personagens no cenário (pedido do Marco)

- **O que havia de verdade em docs/Modelos** (inventário por script, 821 arquivos): 1 espécie de árvore com 6 variações
  (Gleditsia), 1 poste de luz (os 14 postes iguais da Ponte A; o `poste/Utility_pole` é poste de ENERGIA, já usado na
  T-163) e 1 personagem (homem em pé escaneado, sem textura e sem esqueleto, que vinha como boneco de escala no pacote ROAD
  SIGNS). Nenhuma outra pasta com árvores, postes ou personagens foi achada no disco. **Se o Marco tinha outros arquivos,
  eles não chegaram em docs/Modelos.**
- **Árvores**: `RoadsideTrees` (road3d) planta bosques de 1 a 7 árvores (30% de outra espécie no meio), 15–34 m da pista,
  escala 0,8–1,3, giro aleatório, semente pela rota. Mistura por bioma em `RoadsideTrees.MIX`. ~1,9x mais árvores que antes
  (314–361 por rota). As árvores antigas da lista da pista (`Track.objects` "tree", em fila a cada 16 m) não são mais
  desenhadas (a simulação não usa); `--old-trees` volta a elas.
- **LOD**: 2 níveis por árvore (Gleditsia: 279–655 tri perto, 36 longe; por código: LOD1 com menos lados). Troca por bloco
  de 150 m a 140 m da câmera. Prédios não têm LOD (caixas de 12 triângulos).
- **Postes**: antigo (`lamp_post`) na praça do pedágio (0–420 m) e no litoral no nível do chão; da Ponte A (`lamp_bridge`)
  no viaduto da cidade, na serra e nas pontes (`Roadside3D.lamp_model`).
- **Pessoas** (`PeopleKit`): pedágio (4 funcionários + 1 trabalhador), viaduto que cruza por cima (5 em cada), abertura do
  duelo (2 motoristas + 5 clientes ou 3 funcionários). Sem esqueleto: o "parado" é balanço/respiração no shader. Estação de
  trem: **não** (a estação da cidade é um prédio fechado, ninguém apareceria). Passarela: o jogo não tem; o viaduto faz esse papel.
- **Retrato no duelo (G1)**: busto renderizado do mesmo boneco, camisa pintada com a cor do caminhão, nos DOIS lados
  (jogador espelhado), kanji do brasão num selo no canto. O Marco pediu para os rivais; o jogador ganhou o mesmo para a
  faixa não ficar desigual (**confirmar**).
- **Custo** (modo médio, dia, 6 pontos, sem vsync, `tools/measure_t186.sh`): chamadas +1 a +22 (≤ 6,5%), triângulos −0,7 a
  +15 mil, textura +0,7 a +1,0 MB, FPS 220–254 contra 229–271 (−1% a −10%, perto do ruído).

## 2026-10-21 — T-188 (etapa 1): cenário novo num trecho de cada rota — PRECISA APROVAÇÃO DO MARCO

- **Verificação das reclamações** (capturas `docs/capturas_t188/antes/`): montanhas "cones" já tinham virado maciços
  nevados na T-169/T-179, mas facetados, iguais de dia e sem vegetação (verdade em parte); grama plana e lisa até o
  horizonte (verdade); prédios flutuando sem base, mesma janela, alguns a 95 m do eixo e sobre o mar no litoral
  (verdade); árvores: bosques mistos com 2 LODs já vinham da T-186, mas o "brinquedo" (pinheiro/arbusto por código)
  continua (em parte); pedras = bloco cinza (verdade); estrelas = quadrados de ~7 px (verdade); noite preta (verdade);
  placas do pórtico: tinham texto (Label3D), mas fino, apagado à noite e sumindo além de 380 m (em parte); sem
  perspectiva aérea (verdade).
- **Trecho-piloto** (`road3d/scenic_zone.gd`): litoral 600–1.600 m, cidade 1.300–2.050 m, montanha 1.100–2.050 m;
  o relevo some suavemente em 140 m nas pontas. `--t188=off` volta tudo ao visual antigo (capturas/medidas);
  `--t188=all` liga na rota inteira (só para teste; **não aprovado**).
- **Terreno** (`terrain_field.gd` + `terrain_patch.gd`): grade alinhada à pista até 345 m; plano até 46 m (mureta,
  árvores, postes, ferrovia a 36–40 m), depois morros (montanha até ~110 m, litoral ~50 m). Outra parte da rota ou
  corredor de ferrovia/viaduto perto achata o chão (o morro nunca cobre pista). Textura: `terrain_detail.png` (512 px,
  4 canais em tons de cinza) × cores no shader. À noite um "luar" de preenchimento (o céu escuro quase não ilumina).
- **Montanhas em camadas**: morros (terreno) → cordilheira do meio por código a 0,6–1,3 km (`mountain_ridges.gd`,
  1 chamada) → maciços do horizonte (`massif_look.gd`: normais e cor suavizadas, rocha com estratos, floresta embaixo,
  neblina até a cor do horizonte). Floresta das encostas = cartões cruzados (4 triângulos) por MultiMesh.
- **Cidade** (`city_blocks.gd`, `city_look.gd`, `neon_signs.gd`): quarteirões com calçada (base), ruas com faixa
  tracejada, 1–4 prédios por quarteirão com recuo, parques, alturas crescendo para trás, 8 fachadas
  (`facade_atlas.png`, janelas por andar de 3,5 m e vão de 3 m, térreo com lojas perto da pista), telhados com
  platibanda, escalonados, caixa d'água, ar-condicionado, casa de máquinas, outdoor no telhado; letreiros de neon com
  kanji (nomes fictícios, `tools_dev/make_neon_atlas.gd`). Primeira fileira a 44 m (direita) / 62 m (esquerda) do eixo.
  Litoral: casas nos morros do lado da terra, com base de concreto que acompanha a encosta; skyline da baía agora
  sobre uma margem de terra.
- **Céu e noite** (`sky_dome.gd`, `atmos_tune.gd`, numa CÓPIA do `.tres`): estrelas de 1–2 px com brilho e cor
  variados, via láctea fraca, lua com mares, nuvens com lado iluminado e barriga escura; dia com zênite mais azul e
  horizonte enevoado; noite com luar azulado (0,85), horizonte azul com brilho de sódio da cidade, neblina na cor do
  horizonte. `fog_sky_affect` 0,35 → 0,12 (o céu já tem a bruma).
- **Escolhas do Claude a confirmar**: lugar e tamanho dos trechos; altura dos morros; neve dos maciços no
  litoral/cidade 0,8 → 0,5; recuo dos prédios; quantidade de janelas acesas; nomes dos letreiros.
- **Custo** (`tools/measure_t188.sh`, `docs/capturas_t188/custo.txt`): chamadas −1 a +10, triângulos +10 a +14 mil
  (+5%), textura +0,5 a +1,4 MB, FPS −3% a +3% no PC. Celular não medido.

## 2026-10-22 — Respostas do Marco (T-188 etapa 1, T-186, T-190)
- **T-188 etapa 1 aprovada**: prints, tamanho dos morros (montanha ~110 m, litoral ~50 m), neve dos maciços 0,8→0,5, prédios (44/62 m, janelas, letreiros) e refazer árvores/palmeiras de código + corrigir a pintura sobreposta no asfalto na etapa 2 (T-192).
- **Gleditsias adultas ralas / boneco com cara de manequim**: melhorar, mas NÃO agora (pendência anotada; ver ROADMAP).
- **Retrato do duelo**: mantido nos dois lados da faixa (jogador espelhado), decisão do coordenador por simetria e leitura do "frente a frente".
- **Personalização (T-190, docs/REFERENCIA_PERSONALIZACAO.md)**: cada lado do baú pode ter mural diferente; a loja terá **temas prontos** (Retrô, Kansai, Kanto, Gundam) além das peças soltas; **mestre da oficina** que conversa e dá dicas (texto); origem dos murais figurativos **em aberto** (IA, código/Blender ou arte livre); peças ficam para depois (algumas serão trocadas, outras acrescentadas).
- **Ideia de câmera/retrovisor (Marco)**: retrovisor para ver o rival atrás e câmeras de corrida estilo cinema (longe, média, com zoom). Registrada para o futuro; ainda não é tarefa.
- **Andon (texto)**: pendente de explicação ao Marco (é a placa luminosa do teto da cabine com texto, ex.: 一番星).

## 2026-10-22 — T-189: PC com Forward+ e qualidade Ultra; celular continua Compatibility; vida do cenário
- **Renderizador por plataforma**: PC = **Forward+** (`renderer/rendering_method`; é o padrão do Godot 4.7, por isso o
  editor apaga a linha do `project.godot` ao salvar: sem a linha = Forward+); celular = **Compatibility**
  (`rendering_method.mobile`, inalterado). O export Windows usa o do PC, o Android o `.mobile`. PC sem Vulkan cai sozinho
  para Compatibility e o Ultra some das Opções.
- **Qualidade Ultra** (`Settings.quality = 3`, `road3d/ultra_look.gd`): só existe com Forward+ (`UltraLook.available()`);
  no celular a qualidade é limitada a Alta e nada do Ultra roda. Liga: SDFGI (luz rebatida; VoxelGI não serve porque o
  cenário é gerado na hora), SSAO + SSIL, SSR, sombra suave do sol em 4 cortes (atlas 8192, 260 m), **FSR2 na
  resolução nativa** como antisserrilhado temporal (escolhido no lugar do TAA puro: mais nítido), glow mais forte,
  névoa volumétrica por hora (raios de sol no amanhecer/entardecer, halo nos postes à noite), profundidade de campo
  leve só na abertura do duelo, borrão de velocidade opcional (`fx_motion_blur`, desligado; o Godot 4 não tem motion
  blur de verdade: é um borrão radial nas bordas acima de ~80 km/h).
- **Cor por hora do dia** (`road3d/color_grade.gd`): LUT 3D (33³) em `adjustment_color_correction`, só no Ultra:
  amanhecer dourado, dia vívido/saturado, entardecer laranja/rosa, noite azul com neon. **Não existe amanhecer em
  nenhuma rota**: criei `data/time/dawn.tres` só para `--time=dawn` (decisão do Marco: usar em alguma rota?).
- **PC começa no Ultra**: instalação nova com Forward+ abre em Ultra; quem tinha Alta salvo sobe UMA vez para Ultra
  (chave `graphics/version = 2` no `settings.cfg`). Pode voltar em Opções.
- **Vida do cenário** (`Settings.fx_life`, "Vida do cenário" nas Opções; **desligada por padrão no celular**, ligada no
  PC), tudo só visual, determinístico por rota, fora da simulação e da rede, nunca obstáculo (`road3d/race_life.gd`):
  vento nas árvores/palmeiras/arbustos (cópia da malha com balanço no shader, sem mexer nos construtores), folhas
  caindo, bandos de pássaros de dia (gaivotas no litoral), chaminés de fábrica vermelho/branco com fumaça (litoral e
  cidade) e fumaça de vila (montanha), vapor de bueiro no acostamento, insetos nos postes à noite, sombras de nuvem
  (Decal; só Forward+), carros nos dois sentidos e pessoas nas calçadas das ruas da cidade ao lado do viaduto (trecho
  da T-188), buzina distante e ronco dos trens da T-154, som ambiente por bioma (cigarras, mar, cidade, sapos/grilos,
  pássaros; arquivo ausente = pulado; prompts em `docs/AUDIO_ELEVENLABS.md` seção 8).
- **Trânsito "do outro lado do canteiro"**: a rodovia do jogo **não tem pista contrária** (só 3 faixas num sentido,
  com mureta dos dois lados; postes e árvores ficam onde ela estaria). Não inventei a pista contrária: o trânsito
  contrário entrou onde já existe rua (cidade). **Decisão pendente do Marco** (ver resposta da T-189).
- **Chuva** (`fx_rain`, opcional, já existia): agora com céu cinza, pista mais molhada (no Ultra reflete as luzes),
  spray atrás de cada caminhão pela velocidade e respingos na pista (`road3d/rain_fx.gd`), som `amb_rain_loop` quando
  existir. Vale também no celular (só se o jogador ligar, como antes).
- **Custo medido** (RX 580, 1920×1080, sem vsync; `tools/measure_t189.sh`): ver `docs/capturas_t189/custo.txt`.
  Celular **não medido** (sem aparelho).

## 2026-10-22 — T-192 (T-188 etapa 2): cenário novo nas 3 rotas inteiras, árvores refeitas, pintura do asfalto
- **Rota inteira** (`ScenicZone`): `--t188=all` virou o padrão; `--t188=segment` (só o antigo trecho-piloto,
  `ScenicZone.pilot`) e `--t188=off` (visual antigo) ficam para comparar. Terreno com morros, cordilheira do meio,
  floresta das encostas, quarteirões/ruas/fachadas/neon, casas do litoral, pedras e placas com texto agora vão do km 0
  ao fim; o relevo nasce e morre suave nos 140 m da largada e da chegada (as emendas do meio sumiram). O morro continua
  achatado perto de qualquer parte da pista e dos corredores de ferrovia/viaduto (teste da T-188 roda agora na rota
  inteira); túneis, ponte e viaduto antigo intactos (a "caixa" de morro em cima da boca do túnel já existia e não foi mexida).
- **Vida da T-189 na rota inteira**: as ruas da cidade (carros/pessoas) seguem a zona; a quantidade de carros por faixa
  cresce com o comprimento (mesma densidade do trecho-piloto, no máximo 4x). Nomes `CityBlocks.START_L/START_R/STREET_M`,
  `AtmosTune`/"dawn" e `UltraLook.tune_tod` mantidos.
- **Árvores por código refeitas** (`build_foliage_t192.py`): pinheiro, cedro, árvore redonda, arbusto e os 3 coqueiros
  trocaram cones/esferas por galhos e tufos em cartões com textura (agulhas, folhas, folíolos) em volta de um miolo
  escuro, silhueta irregular, cor por galho e um tom por árvore (cor por cópia do MultiMesh). Continuam com 2 LODs e
  MultiMesh; mesmas alturas e mesma distribuição dos bosques da T-186. As 6 Gleditsias não mudaram (só ganharam o tom
  por árvore). **Pendências anotadas (não feitas):** copas ralas das Gleditsias adultas e o boneco-manequim do retrato.
- **Pintura "速度落とせ"**: era uma linha deitada de ~6,4 m numa faixa de 3,6 m (invadia as vizinhas). Agora as letras
  vão empilhadas no sentido da pista, 1a letra mais perto do motorista (como no Japão), fonte 80, dentro da faixa.
  Asfalto e "80"/setas inalterados. Observação: curvas de 0,9 exatos (cidade, km 0,4 e 0,7) não ganham a pintura nem a
  faixa amarela (float32 < 0,9); não mexi (muda o visual da faixa).

## 2026-10-22 · T-193 · Modelos novos (Vagoes, train, CARS, Cidade, Letras Japones e neon, Unico)

- **Trens**: a locomotiva americana (`train/`) vira a 2ª locomotiva de carga (azul, faixa creme; pintura nossa, o
  arquivo não tem cor). Os 4 vagões (`Vagoes/`, escala ~1:1,87 corrigida, rodas puxadas para os nossos trilhos) entram
  com 5 variações (toras feitas por código, contêineres de 3 cores). Todos usam o MESMO material/atlas da T-154
  (`rail_train`): nada de material novo. Cada trem de carga sorteia a locomotiva e 6–9 vagões (grupos de 1–3 iguais)
  pela semente da corrida (`RailTraffic.make_train(tipo, rng)`); sem rng = composição antiga (testes antigos). Som igual.
- **CARS**: 2 dos 3 carros entram no **trânsito** (e, por tabela, nos acidentados da T-183 e nas ruas da cidade da
  T-189); cabem no comprimento de 4,5 m da sim (4,45 e 4,15 m), a sim não muda. Escolha: trânsito e ruas, não carros
  estacionados (as ruas da cidade já são o "cenário" com carros). O SUV não entra (rasga ao reduzir). Os 3 vêm de um
  arquivo com nome "desirefx.me" e um logotipo Land Rover solto; usamos só a forma, pintura lisa, emblemas apagados.
- **Prédios (Cidade)**: os 8 prédios são milhares de painéis soltos (vidro em planos com alfa): nenhuma redução os
  mantém inteiros. Solução: casca leve (voxel remesh ou caixa) com a textura original ASSADA (Cycles) num atlas único.
  Entram em 30/40/45% dos lotes (fileiras 0/1/2+; metade em qualidade ≤ média), sempre dentro do lote com o recuo da
  T-188 (START_L/START_R/STREET_M iguais); o gerador próprio deixa ruas/lotes iguais, mas os lotes que viram modelo
  pulam os enfeites de telhado, então os prédios-caixa seguintes mudam um pouco (e mudam entre PC e celular). Longe
  (420 m) o trecho troca para caixas com o shader de fachada. Janelas escuras acendem à noite.
  "The City" (city.fbx, com textura) vira um bloco de torres ao longe (3 cópias a 820 m) só na rota da cidade.
  Não usados: The+City.obj (repete sem textura) e CIT.fbx (cidade OSM pesada que não casa com a pista).
- **Neon**: o pacote C4D não abre (formato Cinema 4D/Octane). Do `NeonText.blend` entram só os letreiros japoneses
  (o "Text messege"/"TEXT" do pacote ficam de fora), renderizados com os materiais neon do próprio arquivo num 2º atlas
  do `NeonSigns`: 1 em 3 letreiros usa o atlas novo (escolha sem número aleatório extra). Acendem à noite como os da
  T-188. **Placas de estrada não mudaram** (o pacote é de letreiros de loja).
- **Carro único** (`UniqueCar`): o Skyline aparece **uma vez por corrida, em cada rota**, estacionado num pátio de
  asfalto fora da mureta, com uma mancha de luz quente no chão (mais forte à noite), pintura azul brilhante e lanternas
  acesas. Só cenário (sem sim, sem rede, sem colisão): todo jogador vê no mesmo lugar porque depende só da rota.
  Lugar: primeiro ponto depois de 45% (litoral, lado do mar, 17,5 m), 22% (cidade, chão ao lado do viaduto onde não há
  muro de som, 26 m) e 45% (montanha, lado do morro, 17 m) da rota, com curva ≤ 1,0 e longe de túnel/ponte/viaduto;
  árvores e prédios ficam fora do pátio. Hoje: km 1,35 / 0,645 / 1,26.

## 2026-10-22 — Pedidos do Marco após a T-193
- **Todos os arquivos de docs/Modelos são royalty free** (inclui CARS); só é vetado o extraído de outro jogo.
- **Carro único (3 lugares)**: o Marco aprova DEPOIS do ajuste do mapa (T-195).
- **Fim da pista**: não pode acabar no "borrão preto"; deve parecer que chegou à cidade destino (cenário contínuo/"infinito"). Tarefa T-195.
- **Som dos caminhões**: mais próximo do real (T-197). **Bonde** com som diferente do trem (T-197).
- **Retrovisor + câmeras** (perto, longe, cinema, orbitando o caminhão): T-198.

## 2026-10-22 — T-197: motor diesel sintetizado e bonde com som próprio (pedido do Marco)

- **Bonde ≠ trem**: o bonde amarelo (`RailTraffic.Type.LRT`) toca o sino "chin-chin" (`tram_bell`) ao chegar perto
  (170 m) e um loop leve que acompanha o bonde com Doppler (`tram_run_loop`: zumbido elétrico, rodas no trilho, juntas,
  rangido fraco; toca até 260 m). O trem de carga continua com a buzina grave e o ronco (`train_horn`/`train_pass`).
- **Motor**: os loops do ElevenLabs (tom e ritmo mudando dentro do arquivo, esticados 0,78–1,40×) viraram **diesel
  sintetizado** (`tools/synth_truck_audio.py`): cada explosão de cada cilindro no tempo certo (6 em linha, V8 com o
  ronco irregular das bancadas, 4 cilindros no Canter), batida irregular da marcha lenta, estalido de diesel,
  ressonâncias do escapamento. Loops em 5 RPM fixos × acelerando/sem acelerar; o jogo mistura os 2 vizinhos e muda o
  tom no máximo ~±20% (o ritmo segue o RPM real do motor da sim).
- Troca de marcha: o ronco cai e volta (o motor perde a carga durante a troca) + "pfft" do câmbio a ar. Freio-motor
  (só com a peça) tem loops próprios por RPM. Escapes: reto/chaminés/cromado ganham o ronco rasgado; o cromado
  cortado estala ao tirar o pé. Ao parar: "tssss" do freio a ar. Pneus: rodagem que sobe com a velocidade; o vento
  muda de tom com a velocidade. Rivais: Doppler (±6%, feito à mão para ignorar cortes de câmera) e distância.
- **Cabine**: há o barramento `EngineCab` (abafado e grave) e a opção na cena de teste, mas **o jogo não tem câmera
  de cabine** (só atrás do caminhão). Se a T-198 criar uma câmera de dentro, é só ligar `EngineAudio.interior`.
- **Sem custo de ElevenLabs.** Prompts opcionais em `docs/AUDIO_ELEVENLABS.md` seção 9 (um `.mp3` com o mesmo nome
  substitui o sintetizado). Som antigo para comparar: `-- --engine-sound=old` ou "Som antigo" na cena de teste.
- Nada mudou na simulação nem na rede (o áudio só lê `rpm`, `throttle_now`, `shifting`, `boost`, `speed`).
- **Para o Marco ouvir e decidir**: `docs/audio_t197/` (antes × depois, mesmo roteiro de direção).
  Volume médio igualado ao antigo (acelerando −21,5 dBFS × −22,2 antes; lenta −30 × −28; o V8 com freio-motor fica
  ~2 dB mais alto que antes ao soltar, de propósito). `espectrogramas.png`: uma linha por arquivo, na ordem de
  `espectrogramas.txt` (antes primeiro); no novo dá para ver as harmônicas seguindo o giro e a queda em cada troca.

## 2026-10-22 · T-195 · Trem do Marco, serrilhado, fim da pista "infinito" e polimento

- **Trem do Marco** (`docs/Modelos/train/3d-model.fbx`, locomotiva diesel americana): já estava no jogo desde a T-193
  (`train_loco_b`), mas a redução para 5,2 mil triângulos tinha **derretido** o capô e a cabine (virou uma cunha azul
  irreconhecível) e ela só puxava metade dos trens. Refeita: corpo com a forma exata do arquivo (só truques/rodas
  reduzidos, 6 mil tri), pintura azul com faixa creme e filete vermelho seguindo a altura (antes manchas diagonais).
  Agora **lidera o 1º trem de cada rota** (inclusive na cidade, onde o trem principal é o bonde), o trem do viaduto que
  cruza a pista e 75% dos outros trens de carga; 35% vêm com 2 locomotivas dela. Intervalo entre trens 22–40 s → 18–32 s.
  Na cidade o 1º trem passa a ser de carga (o bonde vem depois, 40%). Como reconhecer: a locomotiva AZUL com faixa
  creme na frente do trem (a vermelha é a da T-154). Os vagões das pastas `Vagoes` continuam como na T-193.
  `Rail+Track` continua sem uso (a via do jogo é contínua e texturizada).
- **"Serragem"** = interpretado como (1) o chuvisco de pontinhos brilhantes no asfalto molhado à noite (aliasing
  especular: rugosidade baixa × textura de rugosidade com grão) e (2) bordas serrilhadas (sem antisserrilhado na média,
  que é a do celular). Correções: sem Ultra o asfalto molhado não usa a textura de rugosidade (cor do asfalto aprovado
  igual; o Ultra já tinha o limitador do Forward+); MSAA na média 2x e na alta 4x (antes só a alta, 2x); folhas,
  cartões da floresta e treliça com alpha-to-coverage (bordas suaves com MSAA). `--msaa=0|2|4` para comparar.
  **Celular não medido**: MSAA 2x é o nível que a documentação do Godot considera usável em celular; se pesar, a
  qualidade baixa continua sem MSAA.
- **Fim da pista**: a estrada **continua ~1 km depois da chegada** (só desenho: a corrida termina igual, a simulação e a
  rede não mudaram) e entra na **cidade destino**: pórtico de chegada com faixa xadrez e "ゴール CHEGADA" (aceso à noite),
  avenida com postes e poças de luz, quarteirões dos dois lados (os mesmos prédios/neon da rota da cidade; no litoral só
  do lado da terra, o mar fica à direita), a avenida faz uma curva e passa por baixo de um prédio-portal, com o skyline
  da cidade atrás e chão largo até a neblina (sem borda do mundo nem vazio preto). O caminhão segue andando na avenida
  depois de cruzar a linha. Curva: litoral para a esquerda (terra), cidade e montanha para a direita. `--no-arrival` =
  fim antigo.
- **Bugs visuais corrigidos**: morro da boca do túnel da ferrovia (montanha km 1,24, ao lado do carro único) aparecia
  como um triângulo preto à noite (sem o luar do terreno); disco de chão provisório da chegada que cortava morros
  (substituído por faixas que seguem a estrada, antes de ir para o Git).
- **Polimento** (sem mexer no asfalto aprovado): sujeira acumulada no pé da mureta e desgaste leve na faixa entre o
  acostamento e a mureta (cor por vértice, sem custo).
- **Carro único**: os 3 lugares não mudaram (litoral km 1,35, cidade 0,645, montanha 1,26); conferidos nos prints.
- **Custo** (RX 580, 1920×1080, sem vsync, noite, 6 pontos = meio da rota e chegada; `tools/measure_t195.sh`; antes =
  `--msaa=0 --no-arrival`): média/Compatibility FPS 195–223 → 177–221 (−0 a −9%), chamadas +11 a +57 (o máximo na
  chegada, com a cidade destino à vista), triângulos +6 a +30%, memória de vídeo +23 a +33 MB (buffers do MSAA 2x +
  prédios da chegada); Ultra 57–72 → 54–73 FPS (no ruído). A cidade destino só é desenhada a menos de 1,7 km
  (skyline 3,2 km). Arquivos: `docs/capturas_t195/custo_antes.txt`, `custo_depois.txt` (Ultra) e `custo_depois_media.txt`.

## 2026-10-22 · T-198 · Câmeras da corrida e retrovisor (pedido do Marco)

- **Retrovisor** (escolhas do Claude, A CONFIRMAR): espelho largo no topo, no meio, logo abaixo do painel do prazo
  (144×42 no HUD de 480×270; imagem 288×84, espelhada). A câmera fica 0,4 m atrás das portas do baú, a 3 m de altura,
  olhando 35 m para trás (FOV 24° vertical ≈ 70° de largura); vê só até 260 m. **Borda acende** quando um caminhão
  chega a menos de 45 m atrás: dourada se for o rival da rota, laranja para os outros, rosa piscando a menos de ~14 m.
  Some na abertura, na contagem, nos cortes de largada/chegada e na câmera cinema. **Automático**: ligado no PC
  (média para cima) e no celular só na qualidade Alta; desligado no celular em média/baixa e em qualquer qualidade
  baixa. R / tocar no espelho grava a escolha (Ligado/Desligado) nas opções. Celular com o espelho desligado: aba
  pequena no topo (tocar liga).
- **Câmeras** (C, ícone de câmera abaixo da POSIÇÃO, botão Y do controle), na ordem do ciclo: padrão → longe → cinema
  → órbita → perto. **Padrão** = a de sempre (mesmos números). **Perto**: 7 m atrás, logo acima do baú, efeitos de
  velocidade ×1,35. **Longe**: 30 m atrás e 11,5 m de altura (vê a pista e o rival), efeitos ×0,6. **Cinema**: corta
  sozinha a cada 4,5–7 s entre tomada baixa lateral (o caminhão passa pela câmera), baixa na frente (cara do
  caminhão), teleobjetiva de longe atrás, grua subindo e tomada do rival por cima do ombro (35% das vezes quando o
  rival está a menos de 90 m); **corte automático na ultrapassagem** (câmera do lado de fora da dupla); sem tremor;
  faixas pretas (Opções > Gráficos, ligadas por padrão). **Órbita**: uma volta de 14 s com início/fim suaves, para 4 s
  atrás do caminhão (o "retorno automático") e repete. Troca de câmera com mistura de 0,8 s.
- **Sem atravessar cenário** (sem física): toda câmera nova fica entre as muretas (os trechos de 2 faixas contam),
  abaixo de 5,6 m dentro dos túneis com descida/subida suave perto das bocas e fora do baú do jogador. Não checa
  viaduto por cima nem prédio (ficam do lado de fora da mureta).
- **Memória**: a câmera usada por último em cada rota volta na próxima corrida dela; sem histórico, a última escolhida.
  Opções > Gráficos > Câmera da corrida vale para todas as rotas (zera a memória por rota).
- **Câmera de cabine: NÃO incluída.** O Marco decidiu em 2026-10-17 "primeira pessoa: descartada". Se ele quiser rever,
  é barato (mais um modo no rig + `EngineAudio.interior` já existe da T-197).
- Nada em `scripts/sim/` nem na rede: é tudo local (online também funciona, cada um com a sua câmera).
- **Custo medido** (RX 580, 1920×1080, sem vsync, noite, `tools/measure_t198.sh`, médias de 5 s; arquivo
  `docs/capturas_t198/custo.txt`). Retrovisor ligado × desligado na câmera padrão: média/Compatibility (o que o
  celular usa) litoral 197 → 191 FPS (−3%), cidade 172 → 163 (−5%, com ruído); Ultra litoral 61,5 → 59,6 (−3%),
  cidade 54,0 → 50,3 (−7%); memória de vídeo +4 a +6 MB. Câmeras (com retrovisor): perto ≈ padrão; longe −1 a −7%
  (vê mais cenário); cinema (sem retrovisor) igual ou mais rápida; órbita igual na média e −5 a −16% no Ultra (de lado
  vê muito mais cenário). **Celular não medido**: por isso o retrovisor automático fica desligado no celular em
  média/baixa.

## 2026-10-22 · T-199 · Polimento do cenário: mais detalhe, desgaste e bugs da noite (pedido do Marco)

- **Bugs da noite**: (a) placas verdes dos pórticos viravam mancha branca/ciano de perto à noite (o farol do caminhão
  + glow no Forward+/Ultra): as placas quase não recebem mais o farol (são "refletivas": brilho próprio pequeno),
  limiar do glow da noite 0,9 → 1,1, Ultra com menos bloom. (b) halos grandes das luzes: farol 3,0 → 1,6 com borda
  suave e menos reflexo especular; nível largo do glow (5) 1,0 → 0,55 na média; no Ultra nível 6 1,0 → 0,25.
  (c) **grão do asfalto à noite fora do Ultra**: a causa era a textura do asfalto importada **sem mipmap** (o
  `detect_3d` do Godot só converte no editor); mipmaps ligados em asfalto, grama, areia, concreto e folhas. A cor do
  asfalto aprovado não mudou (só some o chuvisco à distância; o Ultra escondia com o FSR2). (d) CHEGADA: letras 43%
  maiores numa placa escura em cima da viga (de dia o neon amarelo sumia no céu). (e) placa verde antiga
  (`sign_green.glb`) com "東京 TOKYO / 12 km" minúsculo: texto refeito ~2,4× maior (Blender `--only sign_green`);
  erro "det == 0" repetido no console da câmera livre (cópias escondidas com escala 0) corrigido.
- **Geometria** (só cenário, sem sim/rede): prédios com beiral, rodapé, antenas, ar-condicionado na fachada,
  varandas com guarda-corpo, escadas de incêndio, marquises das lojas e letreiros verticais; casas do litoral com
  rodapé, cobertura da porta, ar-condicionado, varanda/chaminé; Gleditsias com a copa mais cheia (cartões de folha
  duplicados, girados e mais escuros por dentro, mesma chamada de desenho); mureta com juntas e chapas a cada 9 m,
  refletores âmbar no guard-rail do litoral, marcos de km (キロポスト) a cada 100 m, telefone de emergência (非常電話)
  a cada ~1 km; pontes com viga de borda e pingadeira e tubo de drenagem nos pilares; pórticos com suportes das placas.
  Os lotes e prédios da cidade **não mudaram de lugar** (RNG próprio para os detalhes).
- **Textura/variação sem memória nova**: fachadas com escorrido de chuva a partir do topo, sujeira no pé e manchas
  (shader), cor variando por cópia nos detalhes, sombra de contato nos objetos de caixa, pichações discretas na
  mureta (夜露死苦, 爆走, BAKUSO... Label3D só até 140 m, poucas por rota).
- **Retrato do duelo**: o boneco-manequim ganhou rosto (óculos escuros, sobrancelha, nariz, boca, orelha), hachimaki
  (faixa na cabeça) e gola/mangas na camisa, desenhados em 2D por cima da arte (sem textura nova). Escolha do Claude:
  óculos escuros + hachimaki (visual de motorista de dekotora); trocar é fácil (`ui/duel_bust.gd`).
- **Custo** (RX 580, 1920×1080, noite, 6 pontos, `tools/measure_t195.sh`; `docs/capturas_t199/custo_antes.txt` e
  `custo_depois.txt`): média/Compatibility (a do celular) FPS 199–255 → 229–278 (igual ou melhor, ruído), chamadas
  +2 a +12, triângulos +1 a +5%, textura +1 MB (mipmaps), vídeo −3 a +1 MB. Ultra FPS 54–75 → 54–78 (ruído); no ponto
  da cidade (km 1,4) o Ultra contou +600 chamadas e +60% triângulos (passadas extras do Forward+), sem perder FPS.
  **Celular não medido.**
- **Não resolvido**: a poça de luz do poste da praça do pedágio (km 0) ainda estoura branca no asfalto molhado à
  noite (é luz do poste, não do caminhão); detalhes ficam pequenos na câmera da corrida porque os prédios estão a
  46 m+ da pista (regra da T-188).

## 2026-10-22 · T-202 · HUD da corrida estilo Art Truck Battle (pedido do Marco)

- **Só apresentação**: nada em `scripts/sim/` nem na rede. O HUD lê `TruckSim`/`RaceSim` (igual online e offline).
  Código em `game/scripts/ui/hud/`: contas puras (`GaugeNeedle`, `HudStatus`, `RadarModel`, `HudLayout`) e
  componentes que só desenham (`SpeedGauge`, `IndicatorStrip`, `DamageSegments`, `RouteClocks`, `RadarStrip`).
  `RaceHud` (`ui/race_hud.gd`) monta tudo e posiciona também o ícone de câmera (T-198), o retrovisor e os avisos de
  evento (`EventHud.alert_cx/alert_top/refused_at`).
- **Lugar das peças (PC 16:9)**: POSIÇÃO + ícone de câmera em cima à esquerda; retrovisor no meio em cima (subiu: os
  relógios foram para a direita); relógios + barra de progresso + destino/rival em cima à direita; radar na borda
  esquerda; velocímetro embaixo à direita com setas/lâmpadas acima e os 5 segmentos abaixo (como no original).
  **Celular**: as mesmas peças, maiores pelo DPI (`HudLayout.scale_for`: 3,4 pol / altura física, entre 1 e 1,25),
  dentro da área segura (`DisplayServer.get_display_safe_area`, só em `mobile`), e o conjunto do velocímetro fica
  entre os polegares, à esquerda do FREIO, sem cobrir nenhum botão (círculo de toque × 1,25) nem o caminhão; se não
  couber, encolhe até 0,55. Coberto por `tests/test_hud_t202.gd`.
- **Velocímetro**: escala 0–140 (= `EngineModel.MAX_SPEED`), 240° no sentido horário a partir de baixo à esquerda;
  a agulha pode passar do 140 até o pino de 150 (o vácuo dá 38,9 + 2,0 m/s ≈ 147 km/h). Agulha com mola/amortecedor
  (ω 13 rad/s, amortecimento 0,62: passa um pouco do alvo), sub-passos de 8 ms (mesmo movimento a 20 ou 240 FPS),
  tremor pequeno que cresce com o RPM e um tranco para baixo na batida (`TruckSim.jolted`). Velocidade digital
  pequena embaixo (fica vermelha no tranco, T-152), marcha no centro ("N" parado), turbo (T, ciano) e Passing (P)
  como arcos no aro, "VÁCUO" acende no mostrador, cunha âmbar = velocidade segura da curva à frente (com o aviso),
  traço vermelho = limite das obras. Luz de fundo: branca fria de dia → âmbar à noite e dentro do túnel
  (`max(1 - day_amount, túnel)`); vidro/reflexo só quando `fancy` (PC sempre; celular só na qualidade Alta).
- **Setas verdes** (como no original) no ritmo do `SignalBlink` (T-170). Lâmpadas: farol (noite/túnel), pisca-alerta,
  buzina, freio (forte = vermelho vivo; pedal = vermelho fraco). Pontos das 5 faixas embaixo (faixa fechada à frente
  = vermelho).
- **Pisca-alerta (regra nova, só visual)**: acende no HUD e no caminhão (`TruckNode.set_signal(2)`) quando o
  caminhão derrapa para fora da faixa, fica parado/abaixo de 4 m/s depois de 6 s de corrida, ou o prazo acabou.
  Não liga na contagem nem depois da chegada. A seta normal tem prioridade.
- **5 segmentos = por ÁREA** (interpretação de "5 segmentos de status por peça"): frente, lateral esquerda, lateral
  direita, traseira, carga/baú. Valor = `DamageModel.zone_health` (o mesmo da garagem: média das peças da área ou o
  sistema da área se não há peça) e `cargo_integrity` para a carga. Verde ≥ 66%, amarelo ≥ 33%, vermelho, escuro =
  destruído (0). O segmento que piora pisca 1,2 s. Mouse em cima (PC) ou toque (celular, 3 s) abre o detalhe: estado
  e %, peças inteiras X de Y, sistema por trás (motor/direção/carga) ou perda no prêmio. **Confirmar com o Marco** se
  queria uma barra por peça instalada.
- **Relógios**: 走行時間 / TEMPO DE PERCURSO (sobe) e 残り時間 / TEMPO RESTANTE (prazo; amarelo < 30 s, vermelho
  piscando < 15 s); sem prazo, só o 1º. Barra de progresso com um marcador numerado por caminhão (número = posição de
  largada): você em cima (rosa), os outros embaixo (rival dourado), para o rival colado em você não sumir.
- **Radar vertical** (esquerda, translúcido): 360 m à frente (raiz quadrada: perto ocupa mais espaço) e 60 m atrás;
  você rosa, rival dourado, outros caminhões azul-claro, carros do trânsito ciano até 220 m, acidentado vermelho
  piscando; eventos até 900 m (acima de 360 m ficam presos na borda de cima): acidente vermelho, obras laranja,
  estreitamento amarelo, trecho de 2 faixas cinza. Âmbar dentro do túnel.
- **Contador de FPS** saiu do meio (ficava atrás do aviso de evento): agora à direita do painel POSIÇÃO.
- **Capturas**: `--window=WxH` (janela sem borda maior que o monitor), `--no-touch`, `--hud-scale=`, `--safe-area=L,T,R,B`
  (unidades do HUD) e `--hud-demo` (caminhão batido + seta esquerda presa + detalhe da FRENTE aberto; só offline).
- **Não validado**: celular de verdade (DPI, área segura com entalhe real, toque no segmento com dois dedos) e custo
  no celular (o HUD é todo `_draw()`; ~6 nós novos).


## 2026-10-23 · T-204 · Abertura do duelo no ritmo do original (pedido do Marco)

- **Pedido**: tela preta com nuvens roxas no chão; os dois caminhões reais entram de cada lado e param lado a lado de frente;
  um guardião sobre cada um (Raijin e Fujin, desenho nosso); 対決 com taiko e o nome de cada piloto embaixo; um raio entre os
  dois com clarão branco curto e seguro e trovão; corte para a contagem no grid. ~8 s, pular continua, online no relógio do servidor.
- **Linha do tempo** (`DuelPlan.PHASES`, 8,0 s com a contagem): entrada 0–2,1 s (andam em velocidade constante e freiam até parar
  em 1,85 s; ar do freio) · guardiões 2,1–2,8 s (sobem de trás dos caminhões, aura girando; trovão distante) · título 2,8–3,7 s
  (対決 entra grande e assenta com o `vs_taiko_hit`; faixas entram) · raio 3,7–4,2 s (cai em 3,78 s) · arrancada 4,2–5,0 s (lente
  baixa entre os dois, eles aceleram 22 m/s² para a câmera; escurece 0,1 s e corta) · contagem 5,0–8,0 s (tomada do alinhamento
  e o corte lateral de sempre; depois da cena cheia os caminhões já estão no grid, sem a manobra de entrar na faixa).
- **Fotossensibilidade**: um único clarão branco, 0,15 s, pico 85% (não 100%), queda quadrática; o raio aparece uma vez (sem
  re-piscar); o farol não pisca mais na abertura (antes piscava a 4,5 Hz). Com **Opções > Gráficos > Reduzir clarões**
  (`Settings.fx_reduce_flash`, `[graphics] fx_reduce_flash`; depuração `--reduce-flash`): nada de tela branca, brilho violeta de
  22% que sobe e desce em 0,7 s, raio mais fraco, sem tremor de câmera e sem o chacoalhão do título; o clarão da saída do
  túnel (`RaceCinema.tunnel_flash`) cai para 25%. Testado em `test_single_short_flash_and_reduced_mode` (amostragem a 240 Hz).
- **Arte nossa** (`game/tools_dev/make_duel_art.gd` + `duel_art_kit.gd`, `duel_art_raijin.gd`, `duel_art_fujin.gd`; precisa de
  janela): figuras montadas com círculos/elipses unidos (Geometry2D), contorno de tinta, meia-lua de sombra e de luz, pinceladas
  afinando, padrões tradicionais desenhados por nós (mitsudomoe nos tambores, seigaiha na tanga do Fujin, nuvens em espiral).
  Raijin: pele vermelha, cabelo branco em chamas, chifres, anel de 8 taikos, tanga de tigre, colar com magatama. Fujin: pele
  verde, cabelo azul-escuro soprado, saco de vento creme com espirais índigo, tanga azul de ondas. Título: Noto Sans JP Black
  (OFL) com degradê amarelo→laranja→vermelho, contorno tinta + dourado e brilho escuro. Nada copiado nem traçado de obra
  existente (o biombo famoso de Sōtatsu não foi usado como base). Cores fora da paleta de pixel art (são ilustração, não sprite).
- **Estúdio** (`DuelStage`, 400 m abaixo do mundo, como antes): chão preto brilhante, luz principal de cima e de frente,
  2 luzes violeta atrás, luz do raio; o céu do estúdio é quase preto com uma faixa violeta no horizonte (o renderizador do
  celular desenha o céu mesmo com fundo de cor; por isso o céu É o fundo). A câmera recebe o Environment do estúdio
  (tonemap linear, glow) e `far` 160 m; o sol/lua da rota apaga; tudo volta no fim ou ao pular. Sem profundidade de campo.
- **Neblina** (`DuelFog`): 42 nuvens num MultiMesh (1 chamada) rentes ao chão + brilho violeta no chão; no Ultra também um
  `FogVolume` baixo (topo a 1,5 m, termina antes da lente da arrancada; com a câmera dentro dele a tela inteira ficava roxa).
- **Som**: ar do freio (`air_brake_park`), trovão distante na subida dos guardiões, `vs_taiko_hit` no título, trovão no raio
  (`duel_thunder.wav`, NOVO, sintetizado por `tools/synth_duel_audio.py`, sem créditos), motores roncando na entrada e no talo
  na arrancada. Dá para trocar o trovão pelo ElevenLabs (linha nova na seção 5 de `docs/AUDIO_ELEVENLABS.md`).
- **Online**: protocolo **9** (o `countdown_total` da cena cheia passou de 9,4 s para 8 s). Todos os movimentos são função do
  relógio da abertura (`DuelShots.truck_pose`, `studio_view`), então quem entra atrasado vê o mesmo instante; sons já passados
  não tocam (janela de 0,3 s). `net_test`: largada prevista com 40 ms de diferença (igual antes).
- **Custo** (1280x720, sem vsync, viaduto): média/Compatibility 227–322 chamadas, 183 mil triângulos, 330–377 FPS na cena
  (corrida 202 FPS); Ultra/Forward+ 214–309 chamadas, 206–220 FPS (corrida 97–116). Texturas novas: Raijin e Fujin
  1024x1280 comprimidas com mipmaps, título 1024x560 sem perda, aura 512 e névoa 256.
- **A confirmar pelo Marco**: (1) o desenho dos guardiões e qual fica com quem (Raijin = jogador); (2) 8 s contando a contagem
  (se quiser 8 s só de cena, é mudar `DuelPlan.PHASES`; o servidor acompanha); (3) as falas de provocação saíram da cena;
  (4) o pisca-pisca de farol de provocação saiu (fotossensibilidade); (5) trovão sintetizado (trocar pelo ElevenLabs?).

## 2026-10-23 — T-204: respostas do Marco sobre a abertura
- Raijin/Fujin aprovados por ora (a arte será trocada mais tarde); Raijin com o jogador, Fujin com o rival.
- 8 s contam a contagem 3-2-1. Itens da abertura antiga (área de descanso, pedágio, tomadas de detalhe, banner VS, falas, pisca de farol) **não voltam**.
- Trovão: aprovado gerar no ElevenLabs (T-206).
- Novo pedido: pedágio da pista mais real, com física e a rua se dividindo em duas (T-207).

## 2026-10-23 · T-208 · Abertura demorando para abrir e rápida demais (relato do Marco no celular)

**Causa da demora** (medida no PC imitando o celular; celular não medido): depois do clique a tela ficava parada no escuro enquanto o
jogo (1) lia a cena da corrida e todos os scripts (2,3–2,6 s), (2) montava o mundo inteiro da rota (2,2–3,0 s; a estrada sozinha 0,8 s) e
(3) compilava os shaders no 1º quadro (0,7–0,9 s com o cache; **8,6–10 s sem cache**, que é a 1ª corrida depois de instalar um APK novo).
A abertura não é a culpada (o 1º quadro custa o mesmo sem ela); ela só ficou na frente. No celular tudo isso é várias vezes mais lento.
Além disso os 3 primeiros quadros e a subida dos guardiões davam trancos de 120–150 ms (shaders do estúdio compilando no meio da cena).

**O que mudou**
- `SceneFader`: a cena nova é lida numa thread (`ResourceLoader.load_threaded_request`); para a corrida o fundo é preto com a neblina roxa
  (`ui/loading_fog.gd`) desde o clique. O menu principal pede a leitura da corrida 1 s depois de abrir (`SceneFader.prefetch`;
  `--no-prefetch` desliga): Continuar encontra a cena lida (2,3 s → 0,09 s).
- `DuelIntro`: **preparo** antes do relógio: quadro 1 = pista sob o sol (shaders do mundo), quadro 2 = estúdio com guardiões, auras, luz do
  raio, título, faixas e raio desenhados uma vez atrás do preto, depois espera 2 quadros abaixo de 70 ms (máximo 6 s). O relógio começa
  do 0 só então (`ABERTURA: preparada em N quadros` no log). Tocar durante o preparo offline pula direto para a contagem.
- Linha do tempo (`DuelPlan.PHASES`): entrada 2,6 / guardiões 1,3 / título 1,2 / **faixas 1,9 (nova)** / raio 0,9 / arrancada 1,0 = 8,9 s;
  `BOLT_AT` 7,12 s; os caminhões param em 80% da entrada (`STOP_AT`), arrancada a 16 m/s² (o nariz não passa da lente em 1 s); fade do
  preto 0,6 s; guardiões sobem em 1 s; segundo taiko mais baixo quando as faixas entram.
- Online: `Room.loading` segura a contagem até todos mandarem `c_race_loaded` (ou `Protocol.LOAD_WAIT_MAX` = 30 s; desconectado não
  conta); então o servidor manda `s_state(COUNTDOWN)` e o cliente passa a contar daquele instante (`Net.race_clock_started`). Quem já
  preparou vê "Aguardando o outro piloto...". **Protocolo 11** (10 era da T-207).
- Diagnóstico: `debug/load_clock.gd` imprime `LOAD_T208` (cada etapa do clique ao 1º quadro e picos > 50 ms dos primeiros quadros).

**Medidas** (quente/frio): relógio da cena começa 3,3 s / 7,5 s depois do clique (antes a 1ª imagem vinha em 6,4 s / 14 s, mais trancos
dentro da cena); nenhum quadro acima de 50 ms durante a cena. Arquivo: `docs/capturas_t208/medidas.txt`.

**Fica para depois**: a estrada (`RoadMesh.build`, 0,8 s) usa SurfaceTool em GDScript na rota inteira; dá para cortar bem montando os
arrays direto (estava sendo editada pela T-207, não mexi). No celular a 1ª corrida após instalar ainda vai demorar (shaders sem cache).

## 2026-10-23 · T-207 · Pedágio mais real, com física e a rua se dividindo em duas

**Simulação** (`sim/toll_plaza.gd` geometria pura, `sim/toll_contact.gd` física; igual no servidor e na predição do cliente):
- Parte da PISTA, como os trechos de 2 faixas: `RouteDef.build_track` põe a praça em `TollPlaza.DEFAULT_Z` (150 m) em toda rota;
  `Track.toll` → `TrackEvents.toll` (o setter de `Track.events` liga sempre, então `--no-events` e `events: false` mantêm a ilha).
  Nada novo no setup da rede (a rota define tudo); **protocolo 10** porque a simulação mudou (cliente antigo preveria errado).
- Fora de `TrackEvents.list`: os índices dos eventos, o HUD de avisos e o sorteio não mudam. `lane_blocked_between`, `next_block`,
  `nearest_open_lane` e `is_empty` enxergam a praça → bots, rival, trânsito, recusa de troca de faixa e empurrão lateral já desviam.
- Ao longo da pista (c = 150): funil das barreiras de c−78 a c−18 (13 m → 5,6 m, suave), zebra pintada de c−73 a c−18 (sem física),
  ilha de c−18 a c+14 (dura), funil abre de c+14 a c+74. Contato: `event` = −1 e `"event": "toll"` no evento da `RaceSim`.
- Bot (`bot_driver.gd`): `_leaving` (não avança no bloqueio enquanto o corpo ainda está na faixa fechada, mínimo 2 m/s para conseguir
  virar) e "zíper" (`ZIPPER_M` 120 m, cai 2 m/s abaixo de quem está ao lado). Vale também para acidentes/obras (antes podia encostar no
  bloqueio a 4 m/s quando ficava preso ao lado de outro caminhão até o fim). Medido: 30 sementes × 3 rotas × 2 e 4 caminhões = 0 batidas,
  0 raspadas, ninguém dentro da ilha (`tools_dev/trace_toll.gd --sweep`); tempo até passar 14,7 s (duelo, igual sem a praça) e 20,0 s
  (4 caminhões, era 15,9 s).
- Radar: ilha e ilhas de fora em verde (`RadarModel.Kind.TOLL`).

**Visual** (só apresentação, `road3d/toll_*.gd`): tudo por código a partir do MESMO `TollPlaza` (a ilha desenhada é a ilha da física).
Cobertura 18,8 × 16 m a 7 m (fachada 料金所 TOLL GATE, verso "ご利用ありがとうございました", LEDs embaixo), 6 pilares nas ilhas, 3 cabines
(a central com janela para as duas passagens; o motorista japonês senta à direita), amortecedor amarelo e preto com 2 pisca-alertas e
placa azul "passe dos dois lados", pórtico das antenas ETC, placas ETC/一般 e ETC専用 com seta verde, barreiras de concreto do funil com
refletores, cancelas que abrem quando alguém vem na passagem, pintura (zebra em V invertido, linhas contínuas, faixa verde 一般 e roxa ETC,
marcas de redução). Noite: janelas acesas com o atendente, LEDs, fachada iluminada, poças de luz branca nas passagens e UMA luz real que
acompanha o jogador embaixo da cobertura (só qualidade ≥ média). Atlas próprio `assets/textures/toll/toll_atlas.png` (arte nossa,
`tools_dev/make_toll_atlas.gd`). A câmera da corrida (todos os modos) fica abaixo de 5,6 m perto da cobertura e do pórtico
(`RaceCamRig.toll_h_max`). `--no-toll` = sem a praça (pedágio antigo, sem física); `--old-toll` = só o visual antigo.
- Armadilha: no Compatibility a `emission_texture` do StandardMaterial é ignorada (a faixa roxa ficava branca à noite): pintura
  branca e faixas coloridas em materiais separados.

**Custo** (`tools/measure_t207.sh`, noite, 1920×1080, passando pela praça): média Compatibility +4 chamadas, −600 triângulos (o .glb
antigo era mais pesado), +0,7 MB de textura, FPS 147–161 contra 159–172 sem a praça (ruído alto); Ultra igual (55–57 FPS). Arquivo
`docs/capturas_t207/custo_noite.txt`. **Celular não medido.**

**A confirmar pelo Marco**: largura da passagem (3,8 m), ilha começando 120 m depois da largada, a corrida rápida largar o jogador no meio
(ele precisa escolher um lado ou bate), cores das faixas pintadas, sem limite de velocidade.


## 2026-10-24 · T-210, passo 1 · Respostas do Marco ao catálogo de peças (seção 17 de `docs/REFERENCIA_PECAS.md`)

1. As 53 peças atuais **ficam** no save de quem comprou e saem da loja aos poucos como **"Clássicas"**; quem tem continua
   equipando. (T-211: o cartão da loja mostra "Clássica" nas peças sem raridade.)
2. Rodas, escapamento, grade, buzina, interior e adesivos: o Claude **propõe** um design novo no estilo do documento
   (cromo, neon, LED, dia/noite) e mostra em folha **antes** de modelar (T-211: `docs/capturas_t211/proposta_lacunas.png`).
3. "Caçamba" = carroceria de caminhão **basculante** (caixa aberta), design nosso. Carreta e caçamba ficam para um lote
   posterior com o modelo que o Marco trouxer (cabine e caçamba novas); **não refinar a carreta atual**.
4. Raridade: só o campo `raridade` e um campo opcional `fama mínima` nos dados, **sem travar nada** (regra fica para a fase
   de regras).
5. Troca de cor (L/R) **tem preço**: proposta de cores e preços na seção 18 do catálogo (para aprovar).
6. Murais: dragão, tigre, ondas/Fuji, guerreiro-kabuki, mulher de quimono, fênix/aves + **máscaras japonesas** (hannya,
   oni, kitsune, tengu, Noh) + carpas de reserva. Pode usar obra de domínio público **repintada**, com fonte e licença em
   `docs/CREDITOS_MURAIS.md`. **Um mural por lado** (esquerdo e direito diferentes; kanji/texto nunca espelhado).
7. Pode usar a fonte de pincel **Yuji** (OFL; registrada em `game/assets/LICENCAS.md`); usar as 9 frases sugeridas.
8. Pintura da traseira = **arte separada** (não recorte do mural).
9. Letreiro do deque = **lista de nomes prontos** (sem texto livre).
10. Ordem proposta, parando a cada lote para aprovar a folha de contato. **Primeiro lote: só deque e viseira.**
11. Carreta pode entrar agora mas vai mudar: não gastar tempo nela.
12. **Sem conflito entre peças**: todas podem ser instaladas juntas e nenhuma oculta farol, lanterna dianteira/traseira,
    placa, para-brisa, porta ou roda. Zonas protegidas em cada cabine e baú, no teste automático; peça que invade
    reprova e é corrigida no Blender. Sem aviso/bloqueio na instalação.
- Modelos de terceiros em `docs/Modelos` ("Homem machucado", "Homem", "Caminhão antigo", "Caminhão novo", "Caminhão
  vasculante", "Carreta"): **Royalty Free License (no AI)** — não alimentar esses modelos em ferramentas de IA generativa;
  só ferramentas determinísticas (Blender, scripts). Registrado em `game/assets/LICENCAS.md` e `docs/INVENTARIO_MODELOS.md`.

## 2026-10-24 · T-211 · Lote 1 da oficina (deque e viseira) e base de encaixe

- **Encaixe medido, não chutado**: `blender/scripts/build_sockets.py` mede os 18 `.glb` (cabine, teto, para-brisa, faróis,
  lanternas, portas, rodas, baú) e grava `truck/sockets/<modelo>.json` com a caixa-limite de TODOS os encaixes do catálogo
  novo e as zonas protegidas (para-brisa, faróis, lanternas da quina, setas do `TruckNode`, placas, portas, rodas, portas
  de trás do baú). O próprio script para com ERRO se duas caixas se cruzarem ou uma caixa entrar numa zona. Os `.glb` dos
  caminhões **não** foram regerados (os nós `SOCKET_*` são criados no jogo, como os `MOUNT_STACK_*`).
- Isenções declaradas (decididas pelo Claude, conferir): a placa da frente fica **em cima** do para-choque e as setas da
  frente ficam na quina dele → o para-choque novo é isento dessas 2 zonas e terá de levar a seta junto (lote da frente);
  placa de trás isenta para o para-choque de trás; rodas isentas para as calotas. A caixa do para-choque de trás ficou
  entre as lanternas de fábrica (para não cobri-las): o lote da traseira decide se as lanternas de fábrica viram nós
  `STOCK_*` trocáveis.
- **Deque**: a frente do deque fica na borda do teto plano (como nas capturas) e ele cresce para trás até 1,05 m, sem passar
  da cabine; na americana (teto de 0,4 m) ele avança sobre a testa. Altura até 0,88 m (rodada 2 da comparação: os deques
  das capturas são altos).
- **Viseira**: a altura máxima é a "testa" do Canter (0,17 m entre o vidro e o teto). A aba em V das capturas desce no meio,
  mas aqui o meio não pode descer (cobriria o para-brisa): as **pontas sobem** (rodada 3). A moldura neon (042) desce só até
  a borda do vidro (não pelas colunas, que estão na zona do para-brisa).
- **Escala** uniforme pela largura: deques 0,90–1,10, viseiras 0,90–1,06 nos 17 caminhões jogáveis (limite 0,85–1,15).
- **Cor L/R** = 4 papéis de material por peça (estrutura, painel, LED, neon) + letreiro; troca custa o preço da cor (seção 18
  do catálogo), a de fábrica é grátis; letreiro (12 nomes prontos) grátis. Perfil: `part_style` (campo novo, sem migração);
  descritor da rede leva `style` por peça; ações `set_part_color`/`set_part_sign`; **protocolo 12**.
- Letreiro aceso = material sem luz (unshaded) com o atlas; nada de emissão (no Compatibility a `emission_texture` é
  ignorada e branquearia as cores).
- **Dano sem buraco** (peças da oficina): quebrada fica no lugar, torta 7°, cromo vira aço e as luzes apagam.
- **Conflito com as Clássicas** (PRECISA DECISÃO): a coroa de faróis `roof_lights_crown` e outras peças antigas de teto
  ficam na frente do deque novo (`docs/capturas_t211/exagerado_*`). O teste só garante o catálogo novo.

## 2026-10-24 · T-214 / T-215 · Refino do deque e da viseira, peças antigas de teto, deque de 2 níveis

- **Encaixe pela lataria real, não por caixa**: o Blender mede por raios o teto e a testa de cada `.glb` (grade de 5 cm,
  `truck/sockets/<modelo>.surf.json`) e o jogo assenta cada peça (`game/scripts/truck/socket_seat.gd`): o deque inclina com
  o topo do teto (até 20°; só a parte de cima do teto conta, a testa que cai na frente não), desce até encostar no ponto
  mais alto embaixo dele e ganha um **assento** (saia fina na cor do painel) que fecha a folga do teto abaulado; a
  viseira inclina as costas junto com o para-brisa e ganha um **enchimento** na cor da peça até a testa (ou até a frente do
  deque). Os **canhões não têm mais base**: cada um desce sozinho até o teto (face chata embaixo).
- **Teste por raios** (`PartFitSeat`): a peça encosta (folga ≤ 1,5 cm), não entra mais que 3 cm, e vista de lado não
  sobra vão entre a peça e o teto (o assento cobre). Exceção declarada: na **cabine americana** (teto em cúpula, 0,4 m
  plano) a quina da frente do deque fica sobre a descida da cúpula (mais de 30 cm de queda) e conta como **beiral**,
  não como vão; lá o deque também fica menor (escala pelo fundo, ~0,70).
- **Cor das luzes separada da cor da peça** (pedido do Marco): a cor L/R continua escolhendo estrutura + painel (e a luz
  de fábrica); LEDs e neon têm grade própria de 11 cores, 3.000 ¥ por troca (proposta), voltar à de fábrica é grátis.
  Perfil `part_style` ganha `led`/`neon` (campos novos; perfil antigo sem eles = luz de fábrica, nada a migrar).
- **Peças antigas de teto saem do jogo** (pedido do Marco). Opção escolhida: **reembolso do preço cheio em ¥** e a peça
  sai do perfil (o encaixe fica vazio). Motivo: é a mais segura — ninguém perde dinheiro (nem o que pagou), o save antigo
  abre normalmente (a migração roda ao carregar e quando o servidor adota o perfil; é idempotente: rodar de novo não paga
  de novo), e não sobra peça "fantasma" que ninguém mais vê na loja. A alternativa "slot vazio sem reembolso" faria o
  jogador perder dinheiro; "manter a peça" contraria o pedido. Saíram: `roof_lights_row`, `roof_lights_crown`,
  `roof_marker_small_lamps`, `marker_crown_dx`, `antenna_decor_mount`, `roof_light_frame_halo`, `fumi_wing`,
  `andon_kanji`, `andon_ichiban_dx` (lista em `game/scripts/data/retired_parts.gd`; os `.tres` e modelos ficam no projeto
  só para o preço do reembolso e para descritores antigos). Somem também os encaixes `roof_lights`, `roof_frame`,
  `roof_ornament` e `roof_wing` da garagem. A garagem avisa uma vez quanto foi devolvido. Rivais trocaram as peças
  antigas por deques novos (chefe: `deck_led_box`; Dragão de Aço: `deck_cap_trio`). Ficam: as viseiras antigas
  (`visor_basic`, `visor_gold_lights`, `kw_visor`, não são de teto) e `andon_big_panel` (fica atrás, no painel do baú).
  A coroa de faróis levava a buzina musical 1: ela continua escolhível na seção BUZINA (grátis).
- **Deque de 2 níveis**: caixa em cima de canhões ou canhões em cima de caixa (nunca caixa+caixa ou canhão+canhão; a capa
  baixa e o deque de sobrancelhas não aguentam peça em cima, mas podem ir em cima dos canhões). A peça de cima fica no
  encaixe extra `andon_top` do perfil e é filha da de baixo (apoia no canhão mais alto ou no tampo da caixa). "Cabe" =
  conta geométrica de verdade (`StackFit`: dentro da caixa do encaixe, até a altura máxima `stack_max_y` = teto + 1,45 m e
  no máximo 4,55 m do chão, fora das zonas protegidas, apoiada), feita para todas as duplas × caminhões e guardada em
  `game/assets/vehicles/dekotora/truck/stack_fit.json` (gerar com `tools_dev/gen_stack_fit.gd`; o teste confere que está
  em dia). A garagem só lista as peças que cabem; trocar de cabine para uma onde não cabe deixa a de cima guardada, mas
  sem aparecer nem contar. **Protocolo 13** (estilo leva `led`/`neon`/`top`; ações `set_part_light`, `install_top`).
- **Para-choque traseiro**: não foi mexido na T-214/T-215 (nem no lote 1 da T-211, que só criou a caixa do encaixe dele).

## 2026-10-24 · T-216 · Canhões embaixo da caixa: à frente, com apoio visível

- Pedido do Marco: canhões direto embaixo da caixa pareciam falsos. Agora, quando os **canhões ficam embaixo e a caixa
  em cima** (`StackArrange`, `game/scripts/truck/stack_arrange.gd`), os canhões ficam **0,24 m (na escala da peça) à
  frente da caixa** — a lente aparece na frente do deque, como os canhões de luz sob a aba de um deque de verdade — e a
  caixa se apoia em dois lugares visíveis: **na frente, em cima dos canhões**; **atrás, em dois pés cromados com sapata**
  que descem até o teto (medidos na grade do teto de cada cabine). Cada canhão desce de novo até o teto no lugar novo.
- Onde a viseira fica logo embaixo da frente do teto (cabines **curta** e **JAC**: teto colado no vidro), os canhões
  avançam só o que dá sem entrar no lugar da viseira e **a caixa recua** o resto (até o fim do teto). Se a soma ficar
  abaixo de 0,10 m, a dupla "não cabe" e não aparece na garagem.
- Conta de "cabe" (`StackFit`): no arranjo, os canhões podem passar até 0,32 m da frente da caixa do encaixe do deque,
  mas nunca entrar no lugar da viseira nem nas zonas protegidas; os pés precisam chegar no teto (raio na malha real).
  Tabela refeita: **1.500 de 1.728** duplas × caminhões cabem (chata, curta, JAC, Canter: 96/96; americana: 39/96 — lá
  a caixa em cima dos canhões passou a caber e os canhões em cima de caixa continuam não cabendo).
- Canhões **em cima** de caixa não mudaram (ficam no tampo, alinhados pelas costas).

## 2026-10-26 · T-217 · Ambientação das 3 rotas na linha do original, moderna (pedido do Marco, item 10)

- **Pista contrária (decisão do Marco, pendente desde a T-189)**: fica à DIREITA (mão inglesa), nas 3 rotas inteiras, só
  visual. Corte: nossa mureta (13–13,6 m), canteiro de 2,8 m com cerca viva (tsutsuji florida em ~18% dos trechos) e
  guard-rail em W virado para a outra pista, 2 faixas de 3,5 m (16,6–27 m), mureta externa (litoral: guard-rail). Cidade:
  viaduto gêmeo com 1 m de vão entre os tabuleiros, pilares em T próprios e a barreira de som da direita passa para a
  borda de fora da outra pista. Ponte do litoral: tabuleiro gêmeo. Túneis: boca própria (túnel gêmeo). O chão afunda 0,3 m
  embaixo da faixa (sem briga com o terreno); a praia do litoral, as árvores, os postes de energia (32,4 m), os outdoors e
  os pilares do viaduto/ferrovia da direita foram empurrados para fora. As placas verdes da beira passam para a esquerda
  (onde não há placa do RoadSigns nem muro). **Carro único**: litoral e cidade foram para o lado esquerdo (a direita agora
  é a outra pista).
- **Trânsito da contrária**: posição = função do relógio da cena (para na câmera livre; online cada um vê quase o mesmo),
  uma velocidade por faixa (27 e 21,5 m/s: ninguém atravessa ninguém), ~95 veículos por rota. Até 130 m o modelo .glb; longe
  uma caixa por classe (carro, ônibus, caminhão, carreta: 1 chamada cada). Faróis e luzes âmbar dos caminhões à noite.
  Celular (média): só modelos de 2–4 superfícies; os carros por código (6–7 superfícies) e o caminhão militar só na alta/Ultra.
  **Armadilha medida**: `visible_instance_count = 0` ainda desenha UMA cópia no Compatibility (+84 mil triângulos com os 14
  modelos vazios): o nó é escondido quando não há cópia.
- **Muros de pedra 谷積み**: montanha 370–804 e 1.042–1.215 (esquerda, encostam nas bocas do túnel antigo), 1.290–1.760 e
  2.385–2.560 (direita, além da outra pista); litoral 2.175–2.390 (lado da terra). Nunca do lado da ferrovia, em túnel ou
  ponte (teste). Altura 6,5–9,5 m, inclinação 0,35, calha, drenos com cano, coroamento de concreto, grama no topo, tela verde
  nos altos; atrás o chão vira um terraço (o terreno sobe com ele).
- **Túneis**: boca gêmea, portal de concreto claro só em volta dos arcos com "capuz" de 1,8 m, muros de ala de pedra, morro
  inclinado com o shader do terreno (antes uma parede reta), ventiladores de jato a cada 110 m, caixas vermelhas (extintor) e
  verdes (telefone), lâmpadas laranja na boca gêmea, brilho branco na saída visto de dentro. **Adaptação de exposição só no
  PC (Forward+)**: entrando de dia a imagem escurece e abre em ~1,3 s; saindo estoura e volta em ~0,5 s; de noite o efeito é
  ao contrário e fraco; "Reduzir clarões" limita o pico. Celular: continua o clarão antigo.
- **Postes**: o de braço curvo longo (`lamp_arc`) vira o padrão no chão do litoral e da montanha, atrás da mureta; no
  canteiro, o duplo (um braço para cada pista). Viaduto e pontes seguem com o da Ponte A; o pedágio com o antigo.
- **Danchi**: 18 blocos de 5 andares (varandas com roupa no varal, ar-condicionado, janelas que acendem à noite, antenas,
  "N号棟" na empena) e 13 prediozinhos com loja, entre o viaduto e a ferrovia, na cidade.
- **Floresta e neblina**: floresta das encostas 2–4× mais densa conforme a qualidade, 3 cartões por árvore, tom por árvore,
  mais escura embaixo e longe; ~44 lençóis de neblina nos vales da montanha (média para cima).
- **Identidade**: litoral = farol de 30 m numa ilhota (facho girando à noite), porto com contêineres, armazém, carretas e
  trabalhadores, banhistas de dia; montanha = cachoeira de ~30 m descendo um paredão de rocha ao lado do muro (poço, respingo
  e um filete que cai pelo muro até a calha), obra com basculantes, ponte pênsil vermelha num vale ao longe; cidade = danchi
  + neon (já existia).
- **Placas**: azuis com texto real (国道1号 com as cidades da rota e setas, 非常駐車帯, ハイウェイラジオ 1620kHz) e as costas
  cinza dos pórticos da outra pista.
- **Modelos de docs/Modelos usados agora**: Caminhão novo, Caminhão vasculante (logotipo apagado), Carreta, Caminhão antigo
  (Tatra), Homem (pose parada), Homem machucado (braços abaixados por script), Outra ponte. Não usados: ver
  `docs/BIBLIOTECA_CENARIO.md` seção 6.
- **Escolhas do Claude a confirmar**: lugar de cada muro, do farol, do porto, da cachoeira, da obra; 2 faixas na contrária
  (a nossa tem 3); tsutsuji florida; densidade do trânsito contrário; lâmpada de sódio (laranja) nos postes novos.
- **Custo** (freecam, Compatibility/média, 1280x720, mesma pose): litoral reta +31 chamadas e +36 mil triângulos
  (173→204, 128→164 mil); montanha +27 chamadas e +23 mil. Medida completa (`tools/measure_t217.sh 3000 day`, 6 pontos,
  média de 2 amostras, 1280x720, PC): FPS 196 → 180, chamadas 522 → 572, triângulos 286 → 340 mil
  (`docs/capturas_t217/custo_antes.txt` e `custo_depois.txt`). Celular não medido.

## 2026-10-26 · T-218 · Caminhões de homenagem ao Art Truck Battle (pedido do Marco, item 11) — PROPOSTA, Marco confere

- **5 modelos novos, feitos do zero por código** (`blender/scripts/build_t218_trucks.py`, `truck3d/t218_cab.py`,
  `truck3d/t218_bodies.py`); os prints do Marco serviram só de referência de silhueta, nada foi extraído do jogo original.
  | id | Nome na garagem | Cabine (fixa) | Carroceria |
  | --- | --- | --- | --- |
  | `alubox` | Baú de alumínio | `flat_wide` "Plana larga": grade preta larga com faixa cromada, 4 faróis retangulares embutidos, para-choque cromado largo, cinza-claro | baú de alumínio liso 8,2 m, teto 3,45 m (mais alto que a cabine, como no print), porta lateral, traseira de 2 folhas com 4 barras de trava; sem mural, sem escapamentos altos |
  | `tarp` | Lona verde | `flat_quad` "Plana de 4 faróis": grade cromada grande, 4 faróis redondos, azul-marinho | plataforma com guardas de alumínio, faixa branca com o nome da empresa **銀河運輸** (fictícia, "Ginga Unyu"), cabeceira cromada perfurada, lona verde-azulada esticada sobre 6 arcos com cordas cruzadas |
  | `pinkbox` | Baú rosa da gueixa | `flat_wide`, rosa | baú rosa com o **mural grande nosso** (gueixa, grande onda, Fuji, sol nascente, sakura) e neons com mapa de emissão próprio; decoração V7 completa (andons, fileiras de luzes) |
  | `tanker` | Tanque cromado | `flat_wide`, branca | tanque elíptico cromado (tampos abaulados, 5 cintas), passarela, corrimão, 3 bocas de visita, escada traseira, caixa de válvulas, porta-mangueiras |
  | `dump` | Caçamba | `flat_quad`, vermelha | caçamba basculante de inox com nervuras, parede da frente alta + protetor de cabine cromado, tampa traseira com moldura e frisos polidos, braços da tampa, estrutura traseira polida, cilindro hidráulico; **protetores perfurados cromados** nos 2 escapamentos verticais |
- **Marcas e textos fictícios**: marca da cabine **HAYATE** (emblema em relevo na grade), empresa **銀河運輸**; nenhum nome de
  marca real em modelo, textura, catálogo, i18n ou arquivo (teste `test_homage_t218.gd` confere os nós). Kanji nunca espelhado
  (texto 3D girado por lado). Mural sem texto.
- **Mesmas regras do jogo**: chassi, rodas (rodado duplo, 2 eixos), pontos de montagem, encaixes medidos (deque, viseira,
  retrovisor, para-choques...), dano das peças, pintura tingível da cabine (`paint_white_panel`), mural (o do baú rosa é do
  modelo: `BodyDef.mural`, sem tingir pela cor do rival). Encaixe: **713/713** peças do lote 1 cabem (`docs/REPORT_ENCAIXE.md`);
  deque de 2 níveis: **62 de 96 duplas** (como a americana: as duplas "caixa embaixo + canhões em cima" não cabem porque os
  canhões avançariam para o lugar da viseira; a garagem só oferece as que cabem).
- **Teto da cabine nova a 3,10 m** (a chata tem 3,175): com 3,32 m o deque de 2 níveis passava do limite de 4,55 m. A
  cabine ficou um pouco mais baixa que a do jogo original; em troca o baú de alumínio fica mais alto que ela, como no print.
- **3 LODs** (só nos modelos novos): LOD0 = o .glb de sempre até 45 m da câmera; LOD1 (~22%) até 120 m; LOD2 (~5%) dali em
  diante (`TruckNode.LOD_RANGES`, arquivos em `truck/lod/`). Peças compradas ficam sempre visíveis.
- **Compra na garagem (proposta)**: os modelos antigos continuam de graça; os novos têm preço e Fama (`BodyDef.price`,
  `fame_required`) e, ao comprar, o caminhão é pintado na cor de fábrica (`default_paint`). Ação de rede `buy_body`.
- **Carga**: baús = fechados; lona e caçamba = abertas (granel); **tanque = tipo novo `tank`** e carga nova **Combustível
  (diesel)** que só ele leva (8–14 t, pagamento ×1,2, pesada). O tanque também leva carga comum.
- **Rivais**: Trovão Rosa (litoral) = baú rosa, Lua Cromada (montanha) = tanque, Dragão de Aço (cidade) = caçamba; o chefe e
  os bots da corrida rápida sorteiam a cada corrida entre todos os modelos (`BodyDef.BOT_POOL`); online, os bots recebem um
  modelo sorteado pela semente da sala. **Protocolo 14.**
- Números de preço/massa/agilidade em `docs/BALANCEAMENTO.md` (seção T-218) — **proposta para o Marco testar**.
- **Medição do rival novo (T-224, 2026-10-26, PC, janela 1280x720, Compatibility, `--quality=1 --time=night`, litoral `kanto_1_coast`,
  3000 quadros, `--fps-log`)**. Rival = Trovão Rosa (`pinkbox`) × rival antigo (`base`). Ruído alto: a janela ficou entre 7 e 75 FPS
  (aquecimento de shaders, e o monitor limita a ~75). Chamadas de desenho são o número firme:
  | Rival | Chamadas (mediana de todos os períodos de 5 s) | Chamadas (últimos 5 períodos) | FPS médio, últimos 5 períodos | FPS médio, todos |
  | --- | --- | --- | --- | --- |
  | `pinkbox` | 641 (mín. 424, máx. 665) | 640 | 58,7 | 30,6 (mediana 15,3) |
  | `base` | 673 (mín. 663, máx. 682) | 673 | 55,5 | 20,5 (mediana 12,5) |
  Leitura: o baú rosa (rival novo) deu ~30 chamadas a menos que o rival antigo; FPS igual dentro do ruído. A medida no
  celular continua pendente (o APK de teste é do protocolo 14).

## 2026-10-26 · T-219 · Sentir o peso do caminhão (pedido do Marco, item 15) — PROPOSTA, Marco testa e ajusta

- **Um arquivo só para ajustar**: `game/data/feel/truck_feel.tres` (classe `TruckFeel`, `scripts/data/truck_feel.gd`; cada
  campo tem a explicação em português). Dois grupos: **simulação** (`sim_*`, vale para jogador, bots, servidor e predição;
  mudou = APK novo e protocolo) e **visual/som/vibração** (só o aparelho, pode mudar à vontade). Os números de antes ficam em
  `TruckFeel.legacy()` (comparação e testes).
- **Simulação (inércia)** — proposta, ver `BALANCEAMENTO.md` seção T-219: tração na arrancada 32 → 29 kN, corte na troca de
  marcha 0,35 → 0,45 s, inércia lateral 3,2 → 2,6/s, ganho da faixa 1,9 → 1,7/s (o fim da troca "arrasta" mais), a massa entra
  na troca de faixa (`(12 t / massa de inércia)^0,4`, teto 1,05 para os leves), **carga acima de 4 t pesa ×1,25** e **peças e
  motor pesam ×1,5** só na inércia (aceleração e troca de faixa). Colisão, aderência na curva e dano continuam com a massa real.
  Resultado: caminhão padrão 0–100 km/h 22,6 → 23,7 s e troca de faixa (90%) 1,00 → 1,13 s; baú cheio de 12 t 38,4 → 43,5 s
  e 1,17 → 1,67 s. Corridas dos bots +2 a +4 s no litoral/viaduto (prazos não mudaram; ver PRECISA DECISÃO na T-219).
- **Bot preso atrás de um lento (correção)**: com a aceleração mais lenta o bot difícil podia ficar 45 s seguindo um ônibus
  exatamente na borda do horizonte de visão (o obstáculo "piscava", o relógio de "preso" zerava e ele nunca ultrapassava).
  Agora o relógio continua com o lento até 25% mais longe (`BotDriver.blocked_hysteresis`); a velocidade segue a regra antiga.
- **Visual (só o aparelho)**: o baú balança como mola com amortecedor (`truck/truck_motion.gd`): **inclina para fora** na troca de
  faixa e nas curvas, com atraso e balanço de volta (antes: inclinava para DENTRO da troca, sem mola); **cabeceio** (acelerando
  o nariz sobe, freando afunda, batida de frente mergulha); **suspensão** comprime nas baixadas, estica nos topos e dá um tranco
  em cada **emenda de dilatação** (a cada 32 m no viaduto da cidade e nas pontes) com o "ta-dum" no som. As rodas ficam no chão
  (só a cabine, o baú e as peças inclinam).
- **Câmera**: segue com mais atraso (14 → 8/s), FOV abre 0,45°/m/s com teto de 20°, tremor leve a partir de 95 km/h (antes 100),
  tremor da batida 0,25 → 0,32 m, **congelamento de 75 ms** nas batidas do jogador a partir de 9 m/s: offline a corrida para;
  **online só a câmera para** (a simulação é do servidor).
- **Batidas**: além de faíscas, pedaços e fumaça (T-141), fumaça de pneu por 0,9 s depois da batida, poeira de terra no
  acostamento, pancada grave somada ao som da batida, vibração do celular centralizada (`input/haptics.gd`).
- **Som**: vento +2 dB, vibração da carroceria que cresce com a velocidade, rangido da estrutura ao frear forte (e no balanço
  grande). Sons **procedurais** (`python tools/synth_feel_audio.py`); versão ElevenLabs só se o Marco aprovar (lista em
  `docs/AUDIO_ELEVENLABS.md` seção 10). O motor (T-220) não foi mexido.
- **Opções novas**: Controles > "Vibração do celular" (liga/desliga) e Gráficos > "Reduzir tremor da câmera" (tremores ×0,25 e
  sem congelamento). `--reduce-shake` força sem gravar.
- **Protocolo 15** (a simulação mudou). Vídeos e tiras antes/depois em `docs/capturas_t219/`.

## 2026-10-26 · T-220 · Som do motor "de verdade" (pedido do Marco, item 16)

- **O que o jogo usava**: desde a T-197 o padrão já NÃO são os loops do ElevenLabs, e sim loops sintetizados
  (`syn_<voz>_<on|off>_<rpm>.wav`, `tools/synth_truck_audio.py`). Os do ElevenLabs só tocam com `--engine-sound=old`.
- **Análise objetiva** (`tools/audio_t220_analyze.py`, numpy; tabela em `docs/audio_t220/analise.txt`, gráficos
  `docs/audio_t220/espectro_*.png`). Diesel 6 cil. 4 tempos: ignição = rpm/20 Hz (lenta 35 Hz, 2400 rpm 120 Hz).
  - ElevenLabs (22 loops): **todos ERRADOS**. A fundamental que o jogador ouve fica entre 27 e 77 Hz em qualquer giro
    (6 cil. padrão: 27 → 37 → 43 → 50 Hz da lenta ao alto, deveria ser 35 → 61 → 88 → 116 Hz); vários mudam de tom
    dentro do arquivo (até 13 semitons) ou nem têm ritmo de ignição claro. Na rampa gravada, o som "segue o motor" em 0%.
  - T-197 (som atual): 6 cil. padrão **10 de 10 CERTOS** (fundamental exata). Preparado: 8 de 10 (as 2 lentas medem
    outra frequência). V8: o período mais forte é o do giro (metade/terço da ignição), por causa do ronco irregular
    das bancadas — de propósito, rever no passo 5. 4 cil.: 8 de 10 (lentas sem ritmo claro).
  - Por que o atual ainda soa sintético (hipótese medida, não ouvida): **toda explosão é igual** (periodicidade
    0,71 na faixa do celular; o sintetizador novo fica em 0,56), o arquivo repete a cada 1,6 s, o tom vem de esticar o
    loop (±20%, as ressonâncias andam junto) e 57% da energia está abaixo de 300 Hz (o celular quase não toca).
- **Sintetizador procedural** (reserva e para comparar): `game/scripts/audio/diesel_synth.gd` (excitação em GDScript:
  pulso de cada explosão no tempo real do cilindro, estalo da válvula, rajada de gás, batida do injetor, ruído do
  fluxo, diferença fixa entre cilindros + variação a cada explosão + atraso aleatório, oscilação lenta do governador,
  falhas com o motor danificado) e `engine_synth_voice.gd` (AudioStreamGenerator + barramento `EngineSynth`: passa-alta,
  EQ do escapamento (21 bandas no PC, 10 no leve), abafador que abre com o giro, aspereza, eco do cano (só PC)).
  Números da voz em `game/data/audio/voice_i6.tres` (`EngineVoiceDef`: cilindros, tempos, ordem de ignição,
  irregularidade, ressonâncias). **Só o 6 cil. padrão**; preparado/V8/Canter continuam nos loops até o Marco aprovar
  (é só criar `voice_i6t.tres`, `voice_v8.tres`, `voice_i4.tres`).
- **Modos** (`EngineSoundMode`): `loops` (T-197; gravações reais `rec_*` entram sozinhas quando os 10 arquivos de uma
  voz existirem), `synth` (sintetizador no lugar dos loops ON/OFF; turbo, freio-motor, estalos e chacoalho continuam
  loops) e `mix` (sintetizador abaixo de 300 Hz + loops só nos médios/agudos, barramento `EngineLoopsHP`). Prioridade:
  `-- --engine-sound=loops|synth|mix` > Opções > Áudio > Som do motor > `game/data/audio/engine_audio.tres`
  (`mode` no PC, `mode_mobile` no celular). Rivais e outros caminhões ficam sempre nos loops (custo).
  **Padrão continua `loops`** (nada muda para quem não mexer na opção) até o Marco ouvir e escolher.
- **Custo medido** (RX 580/PC, corrida no litoral, `--synth-log`): 0,14–0,17 ms por quadro a 22 kHz; versão leve
  (11 kHz, 10 bandas, sem eco; automática no celular) 0,08–0,12 ms; picos até 1,8 ms quando o jogo trava e o buffer
  esvazia. Banco de ensaio sem tela: 11,4 ms por segundo de áudio (PC) e 5,1 ms (leve). **Celular não medido**
  (estimativa 4–6× o PC = 0,4–0,6 ms por quadro na versão leve); `--synth-log` imprime `SYNTH_CPU` no logcat.
- **Gravações reais** (passo 4): lista em `docs/AUDIO_FONTES.md` (só CC0 conferida na página). Ferramenta
  `tools/cut_loops.py` (mede o RPM pela fundamental, escolhe o trecho estável, ajusta ao ponto de RPM do jogo,
  emenda sem clique por correlação + cruzamento + passagem por zero, confere o resultado). Testada com os loops atuais.
- Nada mudou na simulação nem na rede (o áudio só lê o estado). O servidor sem tela não cria som.


## 2026-10-26 · Marco aprova T-214 a T-220 ("aprovo tudo, está tudo excelente")

- Tudo o que estava como **proposta** fica como está no código hoje:
  - T-214/T-215/T-216: deque, viseira, cores de LED/neon, empilhamento e canhões à frente.
  - T-217: lugares de muros, farol, porto, cachoeira e obra; 2 faixas na contrária; flores na cerca viva; densidade do trânsito contrário; lâmpada laranja nos postes novos; carros únicos do lado esquerdo.
  - T-218: preços/Fama dos 5 caminhões de homenagem; comprar repinta na cor de fábrica; rivais fixos por rota; cabines novas só no próprio caminhão; marca HAYATE e empresa 銀河運輸.
  - T-219: números do `truck_feel.tres`; prazos das rotas **mantidos** (sem os +3 s).
  - T-220: estrutura do som aprovada; o padrão continua `loops` até o Marco escolher outro na cena de teste/Opções.
- Próximo: continuar as peças pela ordem da seção 16.2 de `docs/REFERENCIA_PECAS.md`, um lote por vez (T-231 a T-234), sem esperar aprovação entre lotes, salvo decisão que mude o design.

## 2026-10-26 · T-231 · Oficina lote 2: traseira, foguete e contorno do baú (seção 16.2, etapa 3)

- **Lanternas de fábrica: NÃO viraram nós `STOCK_*`** (decisão do Claude, a opção mais limpa; Marco confere). O para-choque
  traseiro novo vai **atrás de tudo o que fica embaixo do baú** (medido nos `.glb`: z de trás do para-choque/lanternas de
  fábrica + 1 cm), na **largura do baú**, com topo a 0,93 m (as setas de trás começam em 0,95 m) e **traz lanternas
  próprias** (material `lamp_tail`: acendem à noite, vermelho-escuro de dia, não piscam com o padrão das luzinhas) e a
  **caixa da placa** (a placa de trás do caminhão vai para ela, `TruckPlateSpots._rear_holder`). Assim ele substitui o
  para-choque e as lanternas de fábrica de baixo **sem regerar os 23 `.glb`** e sem buraco quando a peça é retirada (a de
  fábrica continua lá atrás). Zona protegida `rear_lamp_*` passa a ser isenta para `rear_bumper` (como a seta da frente é
  isenta para o para-choque da frente). As lanternas verticais do baú (colunas âmbar/vermelha/branca) e as setas continuam
  livres. Antes a caixa do encaixe tinha 1,5 m (e só 8 cm no Canter e 3 cm no tanque: as lanternas de fábrica deles
  são uma barra larga) — agora 2,3–2,6 m em todos.
- **Foguete**: uma faixa por borda do teto do baú, medida por raios: por dentro do contorno de LED do teto e por fora do
  andon de fábrica do teto (0,13–0,34 m de largura, 4,5–10,5 m de comprimento). A peça vem em 3 grupos (ponta de trás,
  módulo de 1 m, ponta da frente) e o jogo repete o módulo até o comprimento (`StripFit`, fit "stretch"); a seção encolhe
  até 0,70 onde a faixa é estreita, nunca cresce. Um par por compra (lado esquerdo espelhado).
- **Contorno de LED**: 3 encaixes (direita, esquerda, teto). As faixas são **medidas por raios** em cada caminhão: da
  quina para dentro, a primeira linha onde a lataria está no plano da face, sem nada saliente nem lanterna de fábrica a
  menos de 1,2 cm (as fileiras de luzinhas de fábrica ficam livres). O jogo repete um módulo de 0,30 m (trilho + traço de
  LED) ao longo de cada trecho, numa malha por material.
- **Só baú fechado**: foguete e contorno não existem na graneleira, lona, tanque e caçamba; lá a peça comprada fica
  guardada (não aparece, não pesa, não conta destaque) e a garagem avisa ("Só para baú fechado").
- **Dano sem buraco**: quebrada fica no lugar; o foguete só tomba 5° de lado (sem levantar a ponta de 8 m), o contorno não
  inclina (o nó dele fica na origem do caminhão); luzes apagam (inclusive as lanternas `lamp_tail`) e cromo vira aço.
- **Escada (lote futuro)**: a caixa do encaixe `ladder_*` foi empurrada para fora do contorno de LED da lateral.
- **Bots e rivais**: bots sorteiam um para-choque traseiro novo (e, em 1 de 3, um foguete) pela semente — mesmo resultado
  no servidor e nos clientes; rivais com peças novas (tabela em `BALANCEAMENTO.md`). **Protocolo 16.**
- Preços, pesos e destaque: os do catálogo, como proposta (`BALANCEAMENTO.md`, seção T-231).
- **Custo medido no PC (T-235, 2026-10-26, noite, `kanto_3_mountain`, rival da rota `boss_kanto` com rb_grand_panel,
  rocket_frame e os 3 contornos; modo médio, 1280x720, sem vsync, `--fps-log --quality=1 --life=off`, autoplay,
  semente 7, 3000 quadros):** início km 330: FPS médio por trecho do log 114 → 127 → 125 → 124, chamadas de desenho
  556–637 (pico no período 588–678), 258–336 mil triângulos; 4 picos de 63 a 147 ms (t=14–23 s). Início km 1060: FPS
  121 → 129 → 134 → 136, chamadas 621–636 (pico 642–674), 345–364 mil triângulos, sem picos. **Comparação com o commit
  anterior à T-231 (e989260): NÃO medida.** O worktree dele caiu com falha de segmentação no `--import` (26 s);
  pendente, se o Marco quiser o número exato do custo só das peças novas.

## 2026-10-26 · T-232 · Oficina lote 3: murais, pintura da traseira e pintura do teto (seção 16.2, etapa 4)

- **33 pinturas**: 12 murais (cada um com **desenho diferente em cada lado**), 12 traseiras "focadas no rosto" (arte
  separada do mural, decisão 8) e 9 tetos com as frases da decisão 7. Lista, preços e destaque em `BALANCEAMENTO.md`
  (seção T-232, **proposta**); créditos em `docs/CREDITOS_MURAIS.md`.
- **Arte 100% por código, sem pixel de terceiros** (decisão do Claude, Marco confere): o Marco permitiu obra de domínio
  público repintada, mas nenhuma imagem foi usada — as obras (Hokusai JP1847, tigres de Ganku etc.) foram só referência de
  tipo/composição. Motivo: o estilo vetorial de aerógrafo do mural da gueixa (T-218, aprovado) fica coerente no jogo, tudo
  se regera do repositório (`blender -b --factory-startup -P blender/scripts/build_t232_paint.py`, bytes idênticos a cada
  rodada) e a licença fica a mais limpa possível. Biblioteca nova: `blender/scripts/lib/paint2d.py` (formas por distância,
  tubos de raio variável com coordenadas ao longo do corpo, degradês, contorno, neon, PNG sem Pillow) + `lib/t232_*.py`.
- **Kanji**: fonte de pincel Yuji Syuku (OFL, já registrada) em vetor (o Blender converte cada caractere em triângulos e o
  numpy desenha). Cada caractere é conferido na tabela `cmap` da fonte (`lib/font_cmap.py`): o Blender desenha um glifo
  reserva sem avisar quando falta o caractere, então a conferência pela fonte é que impede o tofu. 75 caracteres, todos ok.
- **Um mural por lado = uma compra traz os 2 lados** (no encaixe `mural` de sempre, junto dos murais Clássicos). Escolha
  do Claude: misturar murais diferentes em cada lado (ex.: dragão à direita, tigre à esquerda) ficou de fora — mudaria o
  perfil e a loja; dá para fazer depois se o Marco quiser.
- **Como a pintura entra no caminhão**: um quadrado com a arte num **retângulo medido por raios** no plano real de cada
  face (`blender/scripts/lib/paint_measure.py`, gravado em `truck/sockets/*.json` como `rect`), 5 mm para fora, por dentro
  do contorno de LED. O que sai da lataria (trilhos, montantes, luzinhas, ferragens e travas das portas, escada, contorno,
  foguete) fica NA FRENTE da pintura. Luzinha rente à face é evitada (a borda do retângulo recua). Os `.glb` não foram
  regerados. Retângulo com u × v = normal: **a arte nunca sai espelhada** (kanji legível nos dois lados, atrás e no teto).
- **Proporção**: cada baú tem a sua (lateral de 2,6:1 no Canter a 6,1:1 no longo curta). A arte estica no máximo
  0,8–1,25× e o resto é cortado nas bordas (que a arte deixa livres). Teto: 2 artes por frase (comprida 1:4 e curta 1:2).
- **Traseira** = tinta na própria porta: isenta só da zona `rear_doors` (nada mais); a fresta das portas é pintada na arte.
  Kanji no alto (embaixo, nas quinas, ficam as colunas de lanternas de fábrica). Nos baús médios a escada de fábrica da
  porta direita passa na frente do kanji da direita (é geometria do baú).
- **Teto**: frase na vertical ao longo do teto, com o alto das letras para a frente do caminhão (a câmera da corrida, atrás
  e acima, lê de pé).
- **Baú rosa (T-218)**: o mural comprado **substitui** o da gueixa (fica por cima); tirando a peça, a gueixa volta. O rival
  Trovão Rosa continua com a gueixa (ganhou só traseira e teto).
- **Carroceria aberta** (graneleira, lona, tanque, caçamba): as faces não existem; a pintura comprada fica guardada (não
  aparece nem conta) e a garagem avisa, como o foguete da T-231.
- **Noite**: mesma técnica do mural da gueixa (emissão pronta por arte + `MuralGlow`, força pela hora do dia/túnel).
  Conferido nos dois renderizadores: **Compatibility (celular) acende** igual ao Forward+ (`docs/capturas_t232/*_noite.png`).
- **Dano**: pintura não amassa, não entorta nem cai (o nó ignora `dent`/`broken`); continua a regra de riscar (perfil).
- **Custo**: +1 chamada de desenho por face pintada (até +4 por caminhão: medido 100 → 104 no Forward+ e no
  Compatibility), +8 triângulos; material compartilhado por arte. Memória/APK (ETC2): murais 1536×384 (+ emissão 384×96)
  **10,0 MB**, traseiras 640×512 **3,3 MB**, tetos 256×1024 e 256×512 **3,0 MB** = **~16 MB a mais no APK**. Em 2048×512
  os murais custavam 17,8 MB; ficou 1536×384 (a garagem de perto fica um pouco mais suave). Só as pinturas instaladas nos
  caminhões da corrida ficam na memória de vídeo.
- **Bots e rivais** com pinturas sorteadas pela semente (mesmo resultado no servidor e nos clientes); **protocolo 17**.
- **Observação (Clássicas)**: o ornamento lateral Clássico `side_ornament_wave` fica por cima do mural novo (já era um
  conflito Clássica × peça nova conhecido desde a T-211; não foi mexido).

## 2026-10-26 · Pedidos novos do Marco (T-239 a T-242)

- Muda a decisão 4 da T-218: as cabines dos 5 caminhões de homenagem **passam a ser trocáveis** pelo jogador (T-240).
- Muda a decisão 1 da T-231: as luzes da porta traseira do baú **saem**; ficam só as do para-choque (T-239).
- Ao frear, **todas** as luzes do caminhão ficam vermelhas; as setas acendem em cima da lanterna certa (T-239).
- Foguetes um pouco maiores em altura e largura (T-240).
- Botão para olhar para trás, esquerda e direita (T-241).
- Murais podem usar **imagens prontas sem direito autoral** (domínio público/CC0), baixadas pelo Marco ou pelo Claude (T-242).
- Ordem: terminar a T-233, depois T-239 → T-242, depois seguir com a T-234.

## 2026-10-26 · T-233 · Oficina lote 4: para-choque da frente, retrovisor, escada e saias (seção 16.2, etapa 6)

- **28 peças**: 11 para-choques da frente, 6 hastes de retrovisor, 3 escadas e 8 saias (catálogo da T-210, seções 3, 5,
  8 e 9). **Viseira: nada a fazer** — a T-211 já entregou as 14 viseiras do catálogo (as "4 bases" são só a forma; os
  desenhos de neon por cima são as 14 peças). Números = proposta do catálogo (`BALANCEAMENTO.md`, seção T-233).
- **Encaixe medido nos .glb** (`truck_measure.front_side`, `socket_rules`), sem regerar os caminhões:
  - **Para-choque da frente**: encosta na FRENTE do nariz de fábrica (raios de frente) e o cobre, entre 0,16 m do chão e
    3 cm abaixo do farol/lanterna mais baixo, até 0,62 m à frente e 0,15 m além da cabine de cada lado. A peça tem 3
    faixas; só a do meio (chapa e faixas) estica/encolhe (`FrameFit`, fit "bumper"): onde o farol é baixo (Canter,
    cabines HAYATE: 0,34–0,37 m livres) a peça encolhe sem deformar lâmpadas nem a caixa da placa; onde é alto (chata,
    0,89 m) ela cresce até 0,55 m para cobrir o para-choque de fábrica. **A seta da frente vai junto** (pontos
    SIGNAL_L/R da peça: a seta do caminhão pisca ali) e **a placa vai para a caixa da placa** da peça (como atrás, T-231).
  - **Retrovisor** (decisão do Claude, Marco confere): **no máximo 0,50 m para fora da lateral da cabine** (a largura
    total fica na ordem da dos espelhos de fábrica, até ~3,3 m; nada "de ônibus") e 0,60 m à frente da cabine, entre a
    borda de baixo do vidro − 0,25 m e a de cima + 0,20 m, sempre na frente da porta. A altura da haste segue o vidro de
    cada cabine. **O espelho de fábrica some** quando a haste está montada (o jogo esconde só os triângulos dentro da
    caixa medida do espelho, `hide`; tirando a peça ele volta); cada haste traz o espelho dela. Não atrapalha a câmera
    do retrovisor do jogo (T-198: fica atrás do baú) e não existe câmera de cabine (decisão de 2026-10-17).
  - **Escada**: na lateral do baú logo atrás da quina da frente e dos escapamentos altos, encostada por fora do
    contorno de LED (até 0,16 m), do fundo ao topo do baú; o degrau se repete pela altura. Só baú fechado.
  - **Saias**: embaixo do baú, entre a roda da frente e a primeira de trás, **só nos trechos livres** medidos por raios:
    o tanque de combustível e a bateria de fábrica saem 0,1 m para fora do baú, então a saia para antes deles e volta
    depois (2 pedaços na maioria; 1 no baú leve e no Canter). Assim saia, tanque, escapamento, rodas e contorno convivem.
    Passa no máximo 3 cm da lateral do baú. Servem em todos os caminhões (inclusive os abertos).
- **Dano sem buraco**: quebrada fica no lugar, torta (2–9° conforme a peça), luzes apagadas, cromo vira aço.
- **Luzes à noite**: lâmpadas âmbar (`lamp_amber`), LED e neon da cor L/R pela mesma técnica dos lotes anteriores
  (material de luz animado; funciona no Compatibility).
- **Bots e rivais**: bots sorteiam para-choque da frente (1 em 5 fica com o básico), saia em 1 de 2 e retrovisor em 1
  de 3, pela semente; rivais com peças novas. **Protocolo 18.**
- **Conflitos com Clássicas** (conhecidos, não mexidos): `fb_*` Clássicos, `front_lip`, `aux_lights`, `skirt_*` Clássicas
  e `side_box` ocupam lugares parecidos; o teste só garante o catálogo novo.
- Complemento do Marco para a T-242: as imagens prontas mantêm o **efeito de luz noturno** dos murais da T-232, mas só em **pontos escolhidos** (olho do animal, lua, sol, chamas…), não na imagem inteira. Fazemos à mão uma máscara de emissão para cada imagem.
- **Custo medido no PC (T-244, 2026-10-26, noite, `kanto_3_mountain`, rival chefe da rota `boss_kanto`; modo médio,
  1280x720, sem vsync, `--fps-log --quality=1 --life=off`, autoplay, semente 7, 3000 quadros: as mesmas flags da T-235;
  cópia limpa do commit 1276aa1, protocolo 18 = T-232 + T-233 + T-241; o APK de teste é desse commit):**
  início km 330: FPS médio por trecho do log 127 → 144 → 144 → 143 (primeira leitura 127); chamadas 622–675 (pico
  638–748), 297–341 mil triângulos; 5 picos de 67 a 137 ms (t=4–21 s). Início km 1060: FPS 140 → 150 → 137 → 152;
  chamadas 662–718 (pico 714–731), 361–429 mil triângulos, sem picos.
- **Comparação com a T-235 (estado da T-231, protocolo 16, mesmos parâmetros):** chamadas de desenho +40 a +80 por
  quadro (≈ +6 a +12%) e triângulos +16 a +65 mil no km 1060 (≈ +5 a +18%): é o que o T-232 (pinturas) e o T-233 (peças)
  somaram. Porém o FPS agora está **mais alto** que o da T-235 (114–136 lá; 127–152 aqui), o que não vem de mais peças:
  é ruído da medida (não sei se outro programa, como um Godot aberto por outro agente, rodava junto; um Godot de 131 MB
  estava aberto no começo). Conclusão: **não dá para afirmar queda de FPS**; o custo visível é pequeno e o PC segue
  acima de 120 FPS nesse trecho. Comparação A/B exata (mesmo PC, dois commits lado a lado) continua **não medida**.

## 2026-10-26 · T-241 · Olhar para trás, esquerda e direita na corrida (pedido do Marco)

- **Segurar = olhar, soltar = volta.** Só a câmera do aparelho: nada em `scripts/sim/`, nada na rede (protocolo não muda;
  o olhar nem entra no `Commands`). Funciona por cima de **todas** as câmeras da T-198 (perto, padrão, longe, cinema,
  órbita): a câmera da corrida continua rodando por baixo e o olhar só troca a pose final (`RaceLook`,
  `road3d/race_look.gd`; ligação em `RaceCamView.apply_look`). Online e offline iguais.
- **As 3 vistas** (escolha do Claude, Marco confere nas capturas):
  - **Trás**: câmera 11 m na frente da cabine, a 6 m de altura (a mesma "câmera de perseguição" virada ao contrário),
    olhando 40 m atrás do baú. Mostra a frente decorada do caminhão e quem vem atrás por cima do baú.
  - **Esquerda / Direita**: "grua" 8 m acima, 3,5 m para o lado OPOSTO, sobre a frente do baú, olhando por cima do
    teto do próprio caminhão para o lado escolhido e um pouco para trás (≈110° da frente): o teto do caminhão fica
    embaixo na tela (o jogador sabe onde está) e aparecem a faixa vizinha e quem vem ultrapassando. Alta o bastante
    para nunca entrar num caminhão da faixa ao lado. (A 1ª versão, ao lado da cabine, mostrava só o ônibus vizinho de
    perto, sem o próprio caminhão: descartada.)
  - Todas passam pelo mesmo limite das câmeras da T-198 (entre as muretas, embaixo do arco do túnel e da praça do
    pedágio, fora do baú).
- **Transição**: 0,24 s para entrar e 0,28 s para voltar, com início e fim suaves; quando a câmera passa de trás para a
  frente do caminhão (olhar para trás) leva 0,34 s e faz um arco **por cima** da cabine (+3,2 m), nunca atravessa o
  caminhão. Trocar de lado direto (esquerda → direita) vai de uma vista para a outra sem voltar.
- **RaceFeel (T-219)**: a vista do olhar segue o caminhão com o mesmo atraso da câmera (`cam_follow_rate`), recebe o tremor
  das batidas já multiplicado por "Reduzir tremor da câmera" e para junto no congelamento das batidas. FOV fixo (58° trás,
  60° lados): o "zoom" de velocidade só faz sentido olhando para a frente.
- **Retrovisor some enquanto olha** (qualquer direção): a tela já é a vista de trás/lado, e no lugar dele aparece o aviso
  "OLHANDO PARA TRÁS / À ESQUERDA / À DIREITA" com o ícone de olho (Lucide `eye`). Isso também economiza a segunda
  renderização enquanto olha. Soltou, ele volta como estava.
- **Cortes** (abertura, contagem, cortes de largada/chegada, demo, resultado): o olhar é largado na hora.
- **PC (teclado)**: segure **Q** = esquerda, **E** = direita, **X** = trás (Q+E juntos também = trás). Q/E/X não eram
  usados na corrida (a câmera livre F1 usa Q/E só com a corrida congelada).
- **Controle**: **analógico direito** para a esquerda/direita = olhar para o lado, **para baixo** = trás; **RB** ou
  **apertar o analógico direito (R3)** = trás. Botões já usados (A Passing, X buzina, Y câmera, Back retrovisor, Start
  pausa, gatilhos, analógico esquerdo) não mudaram. Ações `look_back`, `look_left`, `look_right` no `project.godot`.
- **Celular: UM botão de olho com deslize** (escolhido em vez de 3 botões pequenos). Fica acima e à direita da seta
  direita (no lugar espelhado da BUZINA), raio 20 (× tamanho dos botões). **Segurar = trás**; com o mesmo dedo,
  **deslizar para a esquerda/direita** = olhar para aquele lado (aparecem as 3 opções ESQ · TRÁS · DIR em volta do botão,
  a escolhida acesa); voltar ao centro = trás; soltar = volta. Por quê: o polegar esquerdo só toca nas setas de vez em
  quando (o direito fica no acelerador), então é ele que olha, e um botão ocupa menos tela que três; três alvos
  pequenos juntos geram toque errado. O dedo que começou no olho nunca vira seta (deslizar por cima da seta não troca de
  faixa) e um dedo que entra deslizando no olho não começa a olhar. O velocímetro/radar/retrovisor continuam livres do
  botão (o `HudLayout` já desvia de todos os botões; testado em 16:9 e 20:9, tamanhos 0,7–1,5).
- **Capturas**: `--look=back|left|right` força o olhar (e mostra o botão apertado no celular); `tools/capture_t241.sh`.

## 2026-10-26 · T-239 · Luzes: freio vermelho, setas em cima da lâmpada, porta do baú sem luzes

- **Freio = todas as luzes vermelhas** (pedido do Marco). Entram: luzinhas de marcação (fileiras, sobrancelha, teto),
  fundo luminoso do andon, LEDs e neons das peças da oficina e Clássicas, lanternas `lamp_tail` dos para-choques novos
  (brilham 1,5×), lanternas vermelhas de fábrica (brilham 2×) e a mancha de neon no chão. **Ficam como estão** (decisão
  do Claude, Marco confere): os **faróis brancos** e a luz de ré branca (mesmo material do farol), o **texto** do andon e
  o acrílico com arte (são letreiro, não lâmpada) e a **seta**, que continua âmbar piscando por cima do vermelho (como
  num caminhão de verdade). O padrão de pisca (sequencial etc.) para enquanto freia (tudo fixo). **De dia** as luzinhas
  estão apagadas: freando elas **acendem** em vermelho (75% do brilho da noite), para o freio aparecer. Transição de
  0,08 s para acender e 0,15 s para apagar (sem piscar). Só muda uniformes do material de luz de cada caminhão (nada
  recompila).
- **Quando acende**: freio a partir de 15% do pedal, apaga abaixo de 5% (histerese: o freio proporcional dos bots não faz a
  luz piscar). Vale para jogador, rivais, bots e online. **Protocolo 19**: 1 byte por caminhão no snapshot (`flags2`, bit 0).
- **Seta em cima da lâmpada**: a seta agora é uma **cópia acesa da própria lâmpada** (mesmos triângulos, 4 mm na frente,
  âmbar) + um **halo** redondo de 0,5 m no centro dela (sem o halo, uma lâmpada de 6–15 cm some na tela a 10 m). Onde:
  - frente com para-choque da oficina: pontos `SIGNAL_L/R` da peça (como na T-233);
  - frente sem: a lanterna âmbar da quina da cabine, a que fica na altura do farol (até 12 cm acima);
  - trás com para-choque da oficina: a **lanterna mais de fora** de cada lado da peça (empate: a de cima). As peças só
    têm lanternas vermelhas (`lamp_tail`); a de fora pisca âmbar por cima — **não** viraram lente âmbar no Blender;
  - trás sem: a lanterna âmbar do para-choque de fábrica (homenagens, Canter, graneleiras);
  - os **baús base/leve/longo/carreta** só tinham a faixa vermelha fina embaixo: ganharam uma **lanterna de fábrica do jogo**
    (`StockRearLamps`): chapa preta em cada lado com 4 lanternas redondas (de fora para dentro: âmbar = seta, vermelha,
    vermelha, branca), logo acima da faixa vermelha, atrás do encaixe do para-choque da oficina (some quando ele é montado).
  - A seta **continua piscando durante a troca de faixa** (antes apagava no 2º toque); o HUD e o tique-taque também.
- **Porta traseira do baú sem luzes** (muda a decisão 1 da T-231): saem as colunas de lanternas (branca/vermelha/âmbar com a
  chapa e os aros), as luzinhas dos lados da porta e a fileira de cima da porta, em todos os baús fechados (17 + homenagens
  de baú + Canter + carreta), inclusive nos LODs. Feito no jogo (`RearDoorLamps`, triângulos dentro da zona `rear_doors`),
  **sem regerar os .glb**. Ficam: andon traseiro, fileira do teto, luzinhas das laterais, refletores pintados da borda de
  baixo, escada e trilhos. Baús abertos (graneleira, lona, tanque, caçamba) não têm porta: nada muda.
