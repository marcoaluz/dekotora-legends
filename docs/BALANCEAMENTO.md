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
| `exh_straight` | Direto | +3% torque, +10 Fama | 18.000 |

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
- Curvas (controle por faixas): acima da velocidade segura `sqrt(0,5 × aderência ÷ (|curva| × 7,9e-4))` o caminhão é empurrado para fora da faixa (curva 1,0 = 90 km/h; curva 0,6 = 117 km/h).

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
