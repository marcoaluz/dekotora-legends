# Balanceamento — valores iniciais

Tudo aqui é **ponto de partida para testar**, não verdade. Ajuste depois de jogar.
Quando um valor mudar, atualize este arquivo e o `.tres` correspondente em `game/data/`.

## Caminhão base

| Atributo | Valor |
| --- | --- |
| Massa vazia (com baú) | 8.000 kg |
| Carga padrão | 4.000 kg |
| Velocidade máxima de referência | 140 km/h (38,9 m/s) |
| Marchas (automático) | 6 |
| Largura na pista | 0,35 (em unidades de `x`, onde a pista vai de −1 a +1) |

## Fórmulas

```
massa_total     = massa_base + carga + Σ peso_das_peças
aceleração      = (torque(rpm) × relação_marcha × eficiência_motor_dano) / massa_total − arrasto(speed)
aderência_curva = aderência_pneu × (massa_ref / massa_total)^0.3
empurrão        = impulso × massa_outro / (massa_proprio + massa_outro)
dano_impacto    = k_dano × |Δvelocidade| × massa_outro / 1000
reparo          = preço_peça × (1 − durabilidade_atual / durabilidade_max) × 0.5
Fama_corrida    = Σ fama_peças_inteiras × fator_posição + bônus_ultrapassagens
```

Valores de partida: `k_dano = 4`, `fator_posição = 1.0 / 0.8 / 0.6 / 0.5` (1º a 4º).

## Distribuição do dano

1. Impacto acerta uma **zona** (frente, traseira, esquerda, direita).
2. Peças da zona absorvem até zerar a durabilidade (da mais externa para a mais interna).
3. Sobra de dano: 50% vai para o **sistema** da zona (frente → motor, laterais → direção, traseira → carga),
   50% para a **carga**.
4. Motor danificado: potência × (0,5 + 0,5 × saúde_motor). Direção danificada: puxa `0,1 × (1 − saúde)` para um lado.

## Peças decorativas (MVP)

| ID | Slot | Zona | Peso (kg) | Durab. | Fama | Preço (¥) |
| --- | --- | --- | --- | --- | --- | --- |
| `fb_basic` | Para-choque frontal | Frente | 120 | 80 | 5 | 8.000 |
| `fb_chrome_steps` | Para-choque frontal | Frente | 420 | 220 | 25 | 45.000 |
| `fb_gold_wing` | Para-choque frontal | Frente | 560 | 300 | 40 | 90.000 |
| `visor_basic` | Viseira | Frente | 40 | 40 | 5 | 5.000 |
| `visor_gold_lights` | Viseira | Frente | 110 | 70 | 20 | 30.000 |
| `roof_lights_row` | Luzes de teto | Teto | 30 | 20 | 15 | 12.000 |
| `roof_lights_crown` | Luzes de teto | Teto | 70 | 30 | 30 | 35.000 |
| `skirt_chrome` | Saias laterais | Esq./Dir. | 300 | 200 | 15 | 40.000 |
| `skirt_light_bar` | Saias laterais | Esq./Dir. | 180 | 90 | 25 | 38.000 |
| `andon_kanji` | Andon traseiro | Traseira | 60 | 30 | 15 | 15.000 |
| `andon_big_panel` | Andon traseiro | Traseira | 140 | 50 | 30 | 42.000 |
| `rb_basic` | Para-choque traseiro | Traseira | 100 | 80 | 3 | 6.000 |
| `rb_chrome` | Para-choque traseiro | Traseira | 260 | 180 | 12 | 28.000 |
| `mural_waves` | Mural | Laterais | 0 | — | 20 | 20.000 |
| `mural_lightning` | Mural | Laterais | 0 | — | 25 | 25.000 |
| `hub_chrome` | Calotas | Rodas | 40 | 60 | 8 | 10.000 |

Murais não têm durabilidade: cada batida lateral **risca** (−10% de Fama do mural até repintar, custo 30% do preço).

## Motor, turbo e escape

| ID | Tipo | Peso (kg) | Torque máx (N·m) | RPM corte | Preço (¥) |
| --- | --- | --- | --- | --- | --- |
| `eng_i6_std` | 6 cilindros padrão | 0 (incluso) | 1.400 | 2.400 | — |
| `eng_i6_tuned` | 6 cilindros preparado | +80 | 1.750 | 2.600 | 60.000 |
| `eng_v8` | V8 | +300 | 2.200 | 2.500 | 150.000 |

| ID | Turbo | Ganho de torque em alta | Atraso (s) | Preço (¥) |
| --- | --- | --- | --- | --- |
| `turbo_none` | Sem | 0% | — | — |
| `turbo_single` | Simples | +18% acima de 1.500 rpm | 0,8 | 40.000 |
| `turbo_twin` | Duplo | +30% acima de 1.300 rpm | 1,1 | 85.000 |

| ID | Escape | Efeito | Preço (¥) |
| --- | --- | --- | --- |
| `exh_std` | Padrão | — | — |
| `exh_straight` | Direto esportivo (som `exh_rasp`, rouco) | +3% torque, +10 Fama | 18.000 |
| `exh_stack` | Chaminés verticais (som `exh_stack`, grave) — **proposta T-173** | +2% torque, +16 Fama | 28.000 |
| `exh_chrome_cut` | Cromado cortado (som `exh_pop`, estalos) — **proposta T-173** | +2,5% torque, +12 Fama | 22.000 |

> T-173: os dois escapes novos são **propostas** (o Marco pediu 3 escapes com som próprio; os números ficam entre o
> padrão e o direto para nenhum virar a escolha óbvia: o direto continua o mais forte, as chaminés dão mais destaque).
> Buzinas: escolha **grátis** na aba MECÂNICA (só som). Rivais offline: motor/turbo/escape/buzina sorteados **só no som**
> (a simulação deles não muda).

| ID | Outro | Efeito | Preço (¥) |
| --- | --- | --- | --- |
| `jake_brake` | Freio-motor | +35% de frenagem ao soltar o acelerador acima de 1.500 rpm | 25.000 |
| `tires_sport` | Pneus esportivos | +12% aderência, +10% desgaste | 30.000 |

## Economia

| Item | Valor inicial |
| --- | --- |
| Dinheiro inicial | 50.000 ¥ |
| Frete Kanto trecho 1 / 2 / 3 | 20.000 / 30.000 / 45.000 ¥ |
| Bônus de posição | 1º +50%, 2º +20%, 3º +5%, 4º 0% |
| Corrida com amigos (Dano Real) | Frete fixo 25.000 ¥ × integridade da carga + bônus |

## Builds de referência (para testar o equilíbrio)

| Build | Peças | Esperado |
| --- | --- | --- |
| **Tanque** | `fb_gold_wing`, `skirt_chrome`, `rb_chrome`, `eng_v8` | Ganha nas batidas, perde na reta inicial |
| **Leve** | `roof_lights_crown`, `mural_lightning`, `turbo_twin`, `visor_gold_lights` | Mais rápido e mais Fama, quebra fácil |
| **Equilibrado** | `fb_chrome_steps`, `skirt_light_bar`, `andon_kanji`, `turbo_single` | Bom em tudo, ótimo em nada |

Meta: nenhum dos três vence mais de ~60% das corridas contra os outros dois.


## Notas da implementação (P44, 2026-10-16)

- Motor: 6 marchas, relações 6.4 / 4.1 / 2.75 / 1.9 / 1.35 / 1.0, diferencial 3.3, pneu 0,52 m. Curva de torque
  normalizada (700 rpm 55%, pico 100% em 1.600 rpm, 62% em 2.500 rpm). Aderência máx. na arrancada: 32 kN.
- Medido nos testes (0–100 km/h, caminhão 12 t + peças): padrão **22 s**, 6 cil. preparado + turbo simples + escape direto **16 s**,
  V8 + turbo duplo + escape direto **14 s**. Ajustar jogando (constantes em `game/scripts/sim/engine_model.gd`).
- Turbo: enche com o acelerador acima da rotação mínima, em `lag_s` segundos; esvazia em ~0,6 s; "pssh" (blow-off)
  ao soltar com boost > 60%.
- Freio-motor padrão: 4.500 N × (rpm/corte) com o acelerador solto acima de 1.500 rpm; `jake_brake` multiplica por 1,35.
- Suposições novas (não estavam no GDD): 1 Fama = 50 ¥ de bônus; ultrapassagem = 2 Fama; vácuo = +20% tração e +2 m/s;
  Passing enche 4%/s acima de 70% da velocidade máxima e gasta 35%/s; Fama mínima para liberar peças: <15k ¥ livre,
  <30k = 20, <50k = 60, acima = 120.

## Prazo de entrega e vitória (ATB-1, T-101)

- Prazo = comprimento do trecho ÷ 27 m/s (≈ 97 km/h) × 1,2, arredondado (kanto_1 = 133 s). Um trecho pode fixar `deadline_s` no `.tres`: kanto_2 = 130 s e kanto_3 = 150 s (um bot DIFÍCIL leva ~112 s e ~129 s); o contrato do Mercado leva o prazo em `deadline_s`.
- Vitória = chegar em 1º **e** dentro do prazo. Chegar depois do rival = derrota; prazo esgotado = derrota ("tempo esgotado").
- Derrota paga **0 ¥** e **0 Fama** (suposição a revisar: ver QUADRO T-101). O dano às peças continua, e o contrato volta a ficar disponível.
- Curvas (controle por faixas): velocidade segura `sqrt(0,5 × aderência ÷ (|curva| × 7,9e-4))` (curva 1,0 = 90 km/h; curva 0,6 = 117 km/h). Acima dela, ver "Curvas: segue a faixa (T-132)".

## Curvas: segue a faixa (T-132)

Constantes em `game/scripts/sim/curve_grip.gd` (razão r = velocidade ÷ velocidade segura; vale para jogador, bots, servidor e predição).

| r | O que acontece |
| --- | --- |
| ≤ 1,0 | nada: segue a faixa |
| 1,0 a 1,3 | pneu raspa: perde `8 × (r² − 1)` m/s² (r 1,1 = 1,7 m/s²; r 1,3 = 5,5 m/s²), pneu canta (`skid` 0→1), desliza até **0,5 m** para fora |
| > 1,3 | escapa: o controle de faixa perde a força, a curva joga para fora `0,6 + 4 × (r − 1,3)` faixas-x/s (1 x = 7,2 m) e o pneu deslizando freia só 1,5 m/s²; volta para a faixa quando r cai abaixo de 1,3 |

- Aviso no HUD ("CURVA! ALIVIE") quando a curva dos próximos ~2 s pede r > 1,12 (cheio em 1,3) + vibração curta; "DERRAPANDO!" + vibração ao escapar.
- Giro do corpo: só na troca de faixa, até **3°** (`TruckSim.MAX_BODY_YAW`), pivô no eixo traseiro (20% do comprimento a partir da traseira).
- Medido acelerando sem tocar (desvio máximo / tempo da rota): litoral 0,19 m / 95,6 s · viaduto 0,36 m / 102,7 s · montanha 0,25 m / 120,0 s (antes: 2,8 m / 94,1 s · 9,9 m / 95,5 s · 7,9 m / 110,1 s; o "antes" era mais rápido porque não havia atrito na curva). Bot difícil: 96,9 / 105,8 / 122,9 s (antes 96,6 / 104,7 / 121,7 s); prazos de 133 / 130 / 150 s continuam folgados.
- Com V8 + turbo duplo + escape direto (ou 16 t de carga), acelerando sem soltar o caminhão chega a +47% (+35%) na curva 1,0 do viaduto depois da subida e **escapa** (desvio 9 m): é a regra dos +30%; o aviso vem ~2 s antes. Ajustar jogando.

## Perda de carga proporcional e tipos de carga (ATB-1, T-102)

- `pagamento = frete × (1 − perda) + bônus de posição + bônus de Fama`, com `perda = 0,4 × (1 − integridade da carga)` (0 a 40%).
- `integridade = saúde do sistema "carga" (sobra do dano das peças) − penalidade de contato ÷ 0,4`. **O dano das peças e do motor continua igual**; a perda de carga soma.
- Penalidade de contato: encostar em outro caminhão ou carro = 0,4% do prêmio × fragilidade; batida = 0,4% × variação de velocidade (m/s) × fragilidade; teto 40%.
- Tipo de carga (`CargoDef.trait_kind`): **frágil** (cerâmica 2,2 · eletrônicos 1,8: perde mais por batida), **pesada** (aço, madeira: tração × 0,9, além da massa), **perecível** (alimentos: prazo × 0,8), normal (peças industriais).
- O Mercado de fretes mostra o tipo e o prazo; na contagem regressiva a corrida mostra o aviso da carga.

## Rival de verdade (ATB-1, T-103)

- Sem "borracha": a velocidade desejada do bot nunca depende de quem está na frente ou atrás (só de curva, trânsito e duelo). Teto = 72% / 86% / 97% da velocidade máxima (fácil / normal / difícil).
- Trava no trânsito: preso atrás de um carro lento, espera 0,8 / 1,0 / 1,6 s (fácil / normal / difícil) antes de tentar sair; o difícil enxerga menos longe (7 m + 1,3 × velocidade) — rápido na reta, mas perde tempo no tráfego.
- Duelo (rival da rota e bots normal/difícil): ao ficar a menos de 16 m do jogador abre um duelo de 5–9 s (chance por segundo 30% / 50% / 90%): emparelha a velocidade, anda na faixa vizinha e, a cada 1,6–3,2 s, mira a faixa do jogador por 1,4 s (o empurrão é a batida lateral normal). Espelha a seta do jogador: depois de 0,7 / 0,35 / 0,15 s vai para a faixa que ele quer, fechando-a.
- Bots cancelam uma troca de faixa se aparecer alguém ao lado, exceto quando estão fechando o jogador de propósito.

## Nota de destaque (ATB-2, T-107)

- **Destaque** = Fama das peças instaladas e inteiras (inclui murais, calotas, andon; mural riscado perde proporcionalmente) + escape + pintura + adesivos. `GameState.destaque()`; o antigo `total_fame_rating()` é o mesmo número.
- Pintura: branco de fábrica 0 · grafite 3 · vermelho 6 · azul 6 · rosa 9 · jade 9 · dourado 14 (vermelho/azul exigem 10 de Fama; rosa/jade 30; dourado 60). Cor fora da lista = 4.
- Adesivo: +6 cada, no máximo 4 (lateral esq., lateral dir., traseira, cabine). Tamanho e cor não mudam a nota.
- Na corrida o destaque entra na Fama ganha (peça quebrada perde os pontos dela; pintura e adesivos ficam). O resultado mostra "Destaque do caminhão"; a loja mostra o total no topo e o efeito de cada compra (`Destaque +N`).

## Luzes com padrões de pisca (ATB-2, T-109)

- As luzinhas de marcação do modelo e das peças (âmbar, amarelo, rosa, ciano) usam um material de shader (`LightPatterns`): **fixas**, **sequencial** (onda correndo pelo comprimento), **alternado** (dois grupos trocando) e **respirando**. Lanterna vermelha e farol branco ficam fixos. Escolha na garagem (aba Decoração > Luzes), gravada em `profile.light_pattern`; os rivais usam um padrão cada.
- Acendem à noite e no fim de tarde (`tod.headlights`) e dentro dos túneis (`Tunnel3D.amount`); de dia ficam fracas (12%); a prévia de dia da garagem mostra 40%.
- **Custo medido** (modo médio, rota 1, 75 FPS): 404–409 chamadas de desenho e ~255 mil triângulos, contra 410 e ~257 mil antes. Nenhum custo extra (um material por cor, sem luz real nem script por lâmpada).

## Adesivos, pintura e calotas (ATB-2, T-110)

- **Adesivos** (`DecalCatalog`, `DecalPlacer`): PNG branco/transparente pintado pela cor escolhida; 4 lugares (lateral esq., lateral dir., traseira, cabine = as duas portas); posição X/Y, tamanho e cor ajustáveis na garagem (Decoração > Adesivos). +6 destaque cada. O renderizador Compatibility (celular) não tem o nó Decal, então cada adesivo é um quad colado na superfície (no máx. 5 quads, uma superfície cada).
- 6 provisórios em `game/assets/decals/` (kanji 爆走, kanji 魂, ondas, raio, estrela, sol; gerados por `python tools/gen_decals.py`). Arte própria: coloque o PNG em `game/assets/decals/` ou em `user://decals/` (guia em `LEIA-ME.md` na pasta).
- **Calotas** (aba Decoração, slot Calotas): cromadas 8 (já existia), aço com luz ciano 10, cromadas com luz rosa 12 (Fama 10), douradas 16 (Fama 30).
- Os adesivos e as luzes valem só no aparelho do jogador; no multiplayer os outros jogadores ainda não os veem (falta mandar `decals`/`light_pattern` no descritor da rede).

## Rivais que recusam (ATB-2, T-111)

| Rival | Trecho | Fama mínima | Destaque mínimo |
| --- | --- | --- | --- |
| Trovão Rosa (provisório) | kanto_1 | 0 | 0 |
| Dragão de Aço (provisório) | kanto_2 | 20 | 40 |
| Imperador da Estrada (chefe) | kanto_3 | 60 | 140 |
| (montanha, sem trecho ainda) | — | 40 | 90 |

- `GameState.rival_refusal(route_id)`; recusa = contrato do trecho bloqueado ("RIVAL RECUSA") no Mercado de fretes, que mostra a fala curta do rival e o que falta (Fama e destaque). O botão Continuar do menu abre o Mercado quando o próximo rival recusa.
- Valores são propostas; ajustar jogando. Falas em `game/data/i18n/pt-BR.json` (`rival.<id>.refuse`).

## Largada e chegada com clima (ATB-2, T-112)

- **Largada:** 1,6 s antes do "larga" a câmera corta para o lado (15 m, 5 m de altura, lado com menos caminhões) e fica até 0,3 s depois; banner "LARGOU!" (1,3 s). **Chegada:** corte lateral de 1,9 s, banner "CHEGADA! nº LUGAR", e a tela de resultado só aparece 2,6 s depois (1,8 s no tempo esgotado); o caminhão passa da linha freando sozinho e o resultado é fixado no instante da chegada (o que acontece depois não conta).
- **Clarão na saída do túnel:** tela clareia (mais forte de dia, 80%; à noite, 40%) e some em 0,75 s (`Tunnel3D.exited`, `RaceCinema`).

## Ajuste pós-ATB-1 (T-113): faixas e peso

- **Faixas do asfalto = faixas da simulação:** 3 faixas de 3,6 m (centros em x = −0,5 · 0 · +0,5) e acostamento de 1,8 m de cada lado (x = ±0,875, lento: passou de |x| 0,8 já conta como fora). Antes o asfalto tinha 4 faixas e a linha do meio passava por baixo do caminhão. O caminhão (2,5 m) fica folgado dentro da faixa.
- **Mais pesado:** troca de faixa ~1 s (era 0,7), inércia lateral maior (`STEER_RESPONSE` 3,2), velocidade lateral máxima 0,95 x/s, inclinação da cabine maior (~6°). Carga e peças pesadas já aumentam a inércia pela aderência (`grip`).

## Modelo do caminhão: Canter (T-125)

Cada modelo tem um `BodyDef` (`game/data/bodies/<id>.tres`), lido por `TruckConfig.apply` (campo `body` do descritor,
que vai para o servidor no multiplayer).

| Modelo | Massa vazia | Carga sem contrato | Capacidade | Na pista (hitbox) | Agilidade | Torque |
| --- | --- | --- | --- | --- | --- | --- |
| Baú leve / médio / longo | 8.000 kg | 4.000 kg | 6 / 12 / 16 t | 12 m (`Collision.LEN`) | 1,0 | ×1,0 |
| **Canter** | 3.500 kg | 2.000 kg | **4 t** | **7 m** | 1,1 | ×0,55 (motor menor) |

- Medido (testes, para-choques básicos): 0–100 km/h **19,3 s** (padrão 22,6 s); troca de faixa ~0,7 s (padrão ~1,0 s);
  curva 1,0 segura a **101 km/h** (padrão 90): a aderência sobe com a massa menor (`grip`).
- Pontos fracos: só pega fretes de até 4 t (paga menos), é empurrado mais longe nas batidas laterais (o empurrão é
  proporcional à massa do OUTRO) e o motor rende 55% do torque (com V8 + turbo continua abaixo do caminhão grande no topo).
- Hitbox de 7 m: passa por brechas no trânsito e não encosta em quem está a 8 m. O vácuo conta a partir do nariz (z + 7 m).
- Os bots continuam com 12 m. O trânsito enxerga o comprimento real de cada caminhão (`TruckSim.length`, T-124). Ajustar jogando.

## Tipos de veículo do trânsito (T-124)

Proposta para testar (`TrafficSim.KIND_*`). O tipo de cada veículo é fixo pelo índice (servidor e clientes concordam sem rede).

| Tipo | Quantos | Comprimento | Largura | Velocidade | Massa | Modelos |
| --- | --- | --- | --- | --- | --- | --- |
| Carro | o resto | 4,5 m | 1,9 m | 15–26 m/s (54–94 km/h) | 1.500 kg | hatch, sedã, van, kei, van01, Ascona, Falcon, SUV |
| **Ônibus** | 1 a cada 11 (o 6º, o 17º): 1 no leve/normal, 2 no pesado | **13,3 m** | 2,5 m | **13–17 m/s** (47–61 km/h) | **12.000 kg** | ônibus Jetset |
| **Esportivo** | 1 a cada 9 (o 5º, o 14º): 1 no leve, 2 no normal/pesado | 4,5 m | 2,0 m | **29–34 m/s** (104–122 km/h) | 1.400 kg | Fumi SC |

- **Fila e ultrapassagem:** quem alcança um mais lento (carro, ônibus ou caminhão) na mesma linha tenta a faixa da esquerda,
  depois a da direita (livre = 20,5 m entre carrocerias e nenhum caminhão ao lado); sem faixa livre, freia (7 m/s²) e segue
  atrás com 8 m de folga. Volta à velocidade de cruzeiro a 3 m/s². Antes os carros atravessavam uns aos outros.
- **Batida:** o empurrão e o dano usam a massa do tipo: bater na traseira do ônibus segura mais o caminhão e dói mais
  (`DamageModel.impact_damage(dv, 12000)`). O hitbox usa o comprimento e a largura do tipo.
- O esportivo é mais rápido que todo o trânsito, mas mais lento que o caminhão no limite (38,9 m/s): ele passa o jogador
  que estiver devagar e é alcançado por quem estiver no talo.

## Eventos de pista (T-139)

Código: `sim/track_events.gd` (dados, geometria, sorteio), `sim/event_contact.gd` (física), `BotDriver._closure`, `TrafficSim._avoid_closure`.

| Item | Valor |
| --- | --- |
| Afunilamento (área fechada cresce suave) | acidente 45 m · obras 60 m · estreitamento 120 m (+ 80 m reabrindo) |
| Fechamento total mínimo depois do afunilamento | acidente 50 m · obras 60 m · estreitamento 120 m |
| Aviso (HUD e placas) | 400 m antes (placas a 400 m e 200 m; limite 60 a 90 m antes e logo depois do início da obra) |
| Cone | a cada 5 m dentro do afunilamento: −0,7 m/s e toque na carga (0,4% do prêmio × fragilidade) |
| Veículo parado / barreira | batida de frente com massa 1.500 kg (`DamageModel`), cai para 6 m/s, 1 batida a cada 1,5 s; a 108 km/h ≈ 30% do prêmio + ~100 de dano na frente |
| Encostar só na beirada estando na faixa aberta | sobreposição < 0,12 x (0,86 m): raspa e volta para a faixa (toque na carga a cada 0,8 s), sem batida |
| Fim de faixa (estreitamento) | parede: empurra 2 x/s para dentro, −3 m/s², toque na carga a cada 0,8 s; quem ainda está na faixa que acaba é obrigado a entrar na vizinha |
| Troca de faixa recusada | se a faixa de destino fecha entre a traseira e o nariz + máx(40 m, 2 s × velocidade) |
| Obras: limite | 60 km/h ao lado do fechamento total; acima de 65 km/h, a cada 0,5 s `cargo_hit(excesso m/s × 0,25)`: a 100 km/h numa obra de 110 m ≈ 8% do prêmio |
| Sorteio | fixos da rota + 1 vaga com 45% (`RouteDef.random_events`, `random_chance`); tipo e faixas sorteados (2 faixas: 25%); fora dos 650 m iniciais, dos 350 m finais, de túneis (±60 m) e de curvas ≥ 1,25; 200 m livres entre um evento e o aviso do próximo |
| Folga no prazo | acidente 1 faixa +3 s · obras +7 s · estreitamento +3 s · qualquer fechamento de 2 faixas +8 s |
| Bots | enxergam a faixa fechada a 260 m e vão para a aberta (uma faixa de cada vez, sem bater de lado); ultrapassagem só se a faixa estiver aberta por 120 m; a 110 m saem mesmo atrás de um lento; sem saída, freiam (3,5 m/s²) e esperam; obras: freiam (1,8 m/s² planejados) para 0,9 / 0,95 / 1,0 × 60 km/h (fácil/normal/difícil) |
| Trânsito | sai da faixa fechada a 220 m; sem vaga, para 6 m antes e espera; nas obras desacelera para 60 km/h |

Custo medido em tempo (`godot --headless --path game -s res://tools_dev/measure_event_times.gd`, média dos 2 bots difíceis em
5 sementes de trânsito, evento no z do evento fixo da rota; perda em relação à corrida sem eventos):

| Evento | Litoral | Viaduto | Montanha |
| --- | --- | --- | --- |
| acidente, faixa da direita | +2,4 s | +1,4 s | +0,0 s |
| acidente, meio + direita | +8,4 s | +7,9 s | +4,8 s |
| obras, faixa da direita (com o limite) | +7,3 s | +9,0 s | +5,1 s |
| obras, faixa da esquerda (com o limite) | +5,7 s | +8,1 s | +6,0 s |
| estreitamento, a da direita acaba | +2,8 s | +4,4 s | +0,6 s |

Uma corrida isolada varia muito mais (até ±25 s): o trânsito denso muda de forma caótica com qualquer evento; por isso a média.

## Trechos com 2 faixas (T-153)

Código: `sim/lane_sections.gd` (dados e geometria), `TrackEvents.Kind.SECTION` (as mesmas consultas de faixa fechada dos
eventos), `sim/event_contact.gd` (muretas). Dados: `RouteDef.lane_sections` `{start, end, lanes: 2, taper, look}`.

| Item | Valor |
| --- | --- |
| Faixa que acaba | sempre a da **direita** (ultrapassagem; no Japão se anda pela esquerda) |
| Mureta da direita (face interna) | 13 m → **3,0 m** do centro (faixa do meio termina em 1,8 m + 1,2 m de acostamento) |
| Mureta da esquerda | 13 m → **7,8 m** (acostamento de 2,4 m: o acostamento da esquerda continua cabendo um caminhão) |
| Linha de borda da direita | 5,15 m → 1,95 m; termina o afunilamento a 80% dele (sempre por dentro da mureta), zebrado entre as duas |
| Afunilamento / alargamento | `taper` m antes de `start` e depois de `end` (rotas: 130 m), curva suave (smoothstep) |
| Faixa da direita fecha | quando um caminhão nela encostaria na mureta (~30% do afunilamento antes de `start`); o acostamento da direita fecha antes |
| Quem insiste na faixa que acaba | mureta empurra 2 x/s, −3 m/s², toque na carga a cada 0,8 s, troca de faixa obrigatória (disputa a vez pela batida normal) |
| Troca para a faixa que acabou | recusada ("FAIXA FECHADA"), como nos eventos |
| Avisos | painel de LED 600 m antes do afunilamento, losangos 車線減少 a 400 m e 200 m, placa azul この先 2車線 a 90 m; HUD "PISTA COM 2 FAIXAS" a 400 m até 40 m depois do início |
| Prazo | **sem folga** (o trecho faz parte da rota) |
| Eventos sorteados | ficam a 120 m ou mais da zona do trecho (`TrackEvents.SECTION_GAP_M`); nunca dentro |

Rotas: litoral 2.400–2.760 m (ponte 2.440–2.745 m; a rota ganhou uma lombada de 3% em 2.400–2.800 m para a ponte
ficar ~10 m acima do mar), viaduto 2.270–2.510 m (viaduto antigo), montanha 780–1.060 m (túnel antigo 805–1.040 m).

Custo no tempo (`tools_dev/measure_section_times.gd`, 4 bots, trânsito da rota, 4 sementes, corrida inteira com e sem o
trecho): litoral +1,2 s na média (bot difícil +2,3 s), viaduto +2,9 s (+5,8 s), montanha +2,1 s (+2,9 s).

## Peças tiradas de modelos de terceiros (T-126)

Valores **propostos** (Fama necessária pela regra do preço: < 15 mil livre, < 30 mil = 20, < 50 mil = 60).

| ID | Encaixe | Zona | Peso (kg) | Durab. | Destaque | Preço (¥) | Fama nec. |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `kw_exhaust_stacks` | Escapamentos altos | Esq./Dir. | 90 | 60 | 18 | 26.000 | 20 |
| `kw_fuel_tank` | Caixa lateral | Esq./Dir. | 140 | 120 | 14 | 22.000 | 20 |
| `kw_steps` | Degraus | Esq./Dir. | 60 | 80 | 10 | 14.000 | 0 |
| `kw_visor` | Quebra-sol | Frente | 70 | 60 | 16 | 24.000 | 20 |
| `kw_bumper` | Para-choque frontal | Frente | 300 | 200 | 18 | 38.000 | 60 |
| `kw_grille` | Grade frontal | Frente | 60 | 50 | 14 | 20.000 | 20 |
| `fumi_wing` | Aerofólio | Teto | 35 | 30 | 12 | 18.000 | 20 |
| `fumi_sport_rims` | Calotas | Rodas | 30 | 50 | 14 | 20.000 | 20 |
| `jac_steel_rims` | Calotas | Rodas | 50 | 80 | 9 | 9.000 | 0 |
| `jac_toolbox` | Caixa lateral | Esq./Dir. | 80 | 100 | 6 | 8.000 | 0 |

## Peças deluxe — amostras de acabamento fino (T-172)

Valores **propostos** (mesma regra de Fama necessária pelo preço). Mais caras e com mais Destaque que as antigas do mesmo
encaixe, porque têm mais cromo e luz; ajustar depois que o Marco aprovar o visual.

| ID | Encaixe | Zona | Peso (kg) | Durab. | Destaque | Preço (¥) | Fama nec. | Substitui (mesmo encaixe) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `andon_ichiban_dx` | Andon | Teto | 95 | 45 | 38 | 48.000 | 60 | `andon_kanji` (15), `andon_big_panel` (30) |
| `marker_crown_dx` | Luzes de teto | Teto | 45 | 35 | 26 | 32.000 | 60 | `roof_lights_crown` (30) |
| `underglow_neon_dx` | Neon de chão (novo) | Esq./Dir. | 18 | 25 | 20 | 24.000 | 20 | — |
| `side_bumper_dx` | Saias laterais | Esq./Dir. | 260 | 220 | 30 | 46.000 | 60 | `skirt_chrome` (15), `skirt_light_bar` (25) |
| `step_lit_dx` | Degraus | Esq./Dir. | 40 | 60 | 12 | 16.000 | 20 | `step_metal` (4), `kw_steps` (10) |
| `rear_tail_bar_dx` | Lanternas traseiras | Traseira | 55 | 40 | 22 | 26.000 | 20 | `rear_lamp_cluster` (9) |

## Carroceria graneleira e regra carga x carroceria (T-145)

Proposta para testar (`data/bodies/graneleira.tres`, `CargoDef.needs`, `BodyDef.cargo_kind`).

| Modelo | Massa vazia | Carga sem contrato | Capacidade | Na pista | Agilidade | Torque | Leva |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baú leve / médio / longo, Canter | (ver acima) | | 6 / 12 / 16 / 4 t | | | | carga fechada e comum |
| **Graneleira** | **7.500 kg** | 4.000 kg | **14 t** | 12 m | 1,0 | ×1,0 | granel e carga aberta |

| Carga | Peso (t) | Pagamento | Fragilidade | Tipo | Carroceria |
| --- | --- | --- | --- | --- | --- |
| Eletrônicos · Alimentos refrigerados · Louça e cerâmica | (sem mudança) | | | | **só baú** |
| **Grãos (milho e soja)** — nova | 8–14 | ×0,85 | 0,7 | normal | **só graneleira** |
| **Brita e pedra** — nova | 10–16 | ×0,8 | 0,3 | pesada | **só graneleira** |
| Madeira · Bobinas de aço · Peças industriais | (sem mudança) | | | | qualquer |

- Granel paga menos por tonelada, mas a graneleira leva até 14 t (mais que o baú médio) e é 500 kg mais leve.
- Brita acima de 14 t aparece como "PESADA DEMAIS" na graneleira (só o 2º contrato de um trecho pode passar da capacidade).
- Medido (modo médio, litoral à noite, `--fps-log --quality=1`): baú médio 72–75 FPS, 384–425 chamadas, 196–247 mil triângulos,
  textura 50 MB; graneleira 73–75 FPS, 365–409 chamadas, 191–238 mil triângulos, textura 46 MB.

## Batidas: força e arremesso (T-141) e freada/buzina (T-144)

Constantes em `game/scripts/sim/collision.gd`, `thrown_car.gd`, `hard_brake.gd` e `traffic_sim.gd`.

| Regra | Valor |
| --- | --- |
| Empurrão de faixa (caminhão × caminhão) | batida lateral > 2,5 m/s; quem empurra precisa de ≥ 75% da massa do outro; fumaça 0,9 s |
| Quicar de volta | volta para a própria faixa com 0,35 x/s |
| Restituição caminhão × carro | 0,45 (o caminhão perde `1,45 × m_carro/(m_caminhão+m_carro) × Δv`) |
| Arremesso do carro | Δv ≥ 3 m/s e veículo ≤ 3 t (ônibus só é empurrado); fora de controle 1,3 s + 0,05 s por m/s |
| Deslize lateral | (0,9 + 0,05 × Δv) x/s × fração do impulso; atrito 1,1 x/s² |
| Giro | 0,28 rad/s por m/s; perde 3,5 rad/s² |
| Pulo | acima de 9 m/s: 0,35 m/s para cima por m/s (máx. 3,5 m/s) |
| Escorregando para a frente | −6,5 m/s²; depois endireita a 0,9 rad/s, no máximo 4 m/s enquanto torto |
| Freada forte | freio ≥ 70% a ≥ 60 km/h, perdendo ≥ 9 km/h/s; "pssh" ao soltar se perdeu ≥ 4 m/s |
| Buzina | carro até 55 m à frente do nariz, na mesma faixa, troca para uma faixa livre |

Medido com 4 bots, sem eventos (`tools_dev/measure_impacts.gd`, 4 sementes): por corrida, 0–0,8 batida entre caminhões,
0–0,3 empurrão de faixa, 2–3 batidas no trânsito, 0,3–0,8 carro arremessado; bots difíceis chegam em 117–133 s.

## Batida no trânsito: penalidade e tranco (T-152)

Pedido do Marco: a batida no carro do trânsito tem que custar velocidade (só a troca de momento dava ~1,5 m/s numa batida
de 10 m/s e não se sentia). Constantes em `game/scripts/sim/collision.gd` (`PEN_*`, `JOLT_TIME`); vale para jogador, bots e
servidor (é a simulação). O caminhão fica com o **menor** entre o resultado da física e `velocidade_antes × (1 − penalidade)`
(não soma: no ônibus a física já tira bastante). O carro continua sendo arremessado igual (T-141).

| Regra | Valor |
| --- | --- |
| De frente na traseira do carro | 25% com Δv ≤ 2 m/s → 40% com Δv ≥ 12 m/s (linear entre os dois) |
| Raspão lateral | 8% com Δv ≤ 1,5 m/s → 15% com Δv ≥ 6 m/s (Δv lateral = entrada na faixa × 7,2 m + 0,2 × diferença de velocidade) |
| Veículo pesado (> 3 t: ônibus; futuros caminhões do trânsito) | × 1,35 → de frente 34–54%, de lado 11–20% (teto 60%) |
| Esportivo e carros comuns (1,4–1,5 t) | sem multiplicador |
| Tranco | 0,6 s (18 ticks): acelerador sem efeito (freio funciona; o freio-motor entra como ao soltar o pé) |
| Uma penalidade por batida | durante o tranco, contato novo (até com outro carro) não cobra de novo |
| Abaixo de 1 m/s de diferença | encostar não é batida: sem dano e sem penalidade |

Por que ônibus × 1,35: o ônibus tem 12 t (igual ao caminhão); com o mesmo multiplicador do carro, numa batida de 10 m/s
a física (29%) já ficaria perto da penalidade do carro (37%) e "maior que carro" quase não apareceria. Com × 1,35 o ônibus
custa ~50% de frente contra ~37% do carro na mesma batida.

Quanto custa em tempo (reta, 100 km/h, acelerando, comparado a não bater; o câmbio automático fica na 6ª e recupera devagar):

| Perda | 8% | 15% | 25% | 40% | 54% (ônibus) |
| --- | --- | --- | --- | --- | --- |
| Tempo perdido | ~1,7 s | ~3,0 s | ~5,4 s | ~10 s | ~11 s |

Bots (4 bots sem eventos, 6 sementes, `measure_impacts.gd`; antes → depois): quase todas as batidas deles são raspões
(perda média 13–15%, 1,3–3,7 por corrida). Chegada (difícil, difícil, médio, fácil):

| Rota | Antes | Depois |
| --- | --- | --- |
| Litoral | 116,6 / 116,0 / 117,3 / 127,7 s | 115,4 / 117,1 / 117,2 / 129,5 s |
| Viaduto | 116,2 / 117,9 / 119,4 / 129,1 s | 116,0 / 117,5 / 121,9 / 129,8 s |
| Montanha | 130,1 / 131,8 / 136,0 / 141,4 s | 130,4 / 132,0 / 136,4 / 141,4 s |

Nenhum bot deixou de chegar; diferença de −1,2 a +2,5 s (o trânsito muda a cada batida, então parte é sorte).

## Campanha 1 contra 1, grid lado a lado e rival na largada (T-156)

- **Campanha = 2 caminhões** (jogador × rival da rota; antes + 2 bots). Pagamento não mudou: vitória = 1º e no prazo
  (frete × carga + 50% de bônus de posição + Fama); 2º = derrota, 0 ¥. Com 1 contra 1 o "1º lugar" é só vencer o
  rival (antes um bot comum que chegasse na frente também dava derrota). Menos caminhões = menos ultrapassagens para
  somar Fama (2 por ultrapassagem). HUD de posição mostra "/ 2". Corrida rápida segue com 4.
- **Grid** (`StartGrid`): largada a **30 m** do começo da pista (todos; a corrida ficou 30 m mais curta, ~1 s).
  Duelo: jogador na faixa da **direita**, rival na da **esquerda**, mesma linha, faixa do meio livre. 3–4 caminhões:
  três lado a lado (centro, esquerda, direita) e o 4º 14 m atrás. Antes: um atrás do outro a cada 14 m.
- **Rival na largada** (`BotDriver`): não abre duelo nos **8 s** iniciais (`DUEL_START_GRACE`), não duela/fecha
  quem está no **acostamento** (deixa voltar) e nunca anda abaixo de **80%** da própria velocidade desejada só para
  ficar ao lado (`DUEL_MIN_PACE`). Sem isso, lado a lado desde a largada, o rival empurrava o jogador para o
  acostamento e andava a ~50 km/h ao lado dele: **nas 3 rotas, 4 de 4 corridas estouravam o prazo**.
- Medido (`tools_dev/measure_duel.gd`, 6 sementes, "jogador" = bot difícil que não fecha ninguém, eventos sorteados):

| Rota | Antes (4 caminhões, rival 14 m atrás) | Agora (1 contra 1, lado a lado) |
| --- | --- | --- |
| Litoral | jogador 122,6 s, rival 122,6 s; venceu 5/6; fora do prazo 0 | 123,5 s / 122,2 s; venceu 3/6; fora do prazo 1 |
| Viaduto | 123,6 s / 123,7 s; venceu 4/6; fora do prazo 1 | 126,7 s / 122,3 s; venceu 2/6; fora do prazo 1 |
| Montanha | 148,0 s / 142,7 s; venceu 1/6; fora do prazo 0 | 141,2 s / 138,8 s; venceu 2/6; fora do prazo 0 |

  Leitura: o rival ficou um pouco mais forte (larga junto em vez de 14 m atrás e ninguém o atrapalha); o bot-jogador
  venceu 7 de 18 (antes 10 de 18). Um humano que fecha o rival e usa o vácuo tende a se sair melhor que este bot.
  **Marco: jogar e dizer** se o rival está difícil demais; ajustes possíveis: rival largando meio caminhão atrás,
  carência maior ou prazo do litoral/viaduto +3 s.
- **Comboio online** (3–4 jogadores): trânsito um nível mais leve que a regra da sala (normal → leve).

