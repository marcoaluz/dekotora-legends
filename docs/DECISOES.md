# Registro de decisões

Mais recente no topo. Toda decisão que muda o design ou a stack entra aqui.

| Data | Decisão | Motivo |
| --- | --- | --- |
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

