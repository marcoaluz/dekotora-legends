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
