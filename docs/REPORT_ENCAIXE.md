# Relatório de encaixe das peças da oficina (gerado)

Gerado por `godot --headless --path game -s res://tools_dev/report_part_fit.gd` (T-211). Não edite à mão.
Regras: `game/scripts/truck/part_fit.gd`; encaixes e zonas: `game/assets/vehicles/dekotora/truck/sockets/*.json`
(gerados por `blender/scripts/build_sockets.py`). Teste automático: `game/tests/test_part_fit.gd`.

## Matriz caminhão × lote 1 (17 deques + 14 viseiras)

| Caminhão | Deques OK | Viseiras OK | Escala deque | Escala viseira | Encaixes que se cruzam / entram em zona | Falhas |
| --- | --- | --- | --- | --- | --- | --- |
| alubox_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| alubox_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| alubox_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| alubox_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| alubox_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| alubox_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| base_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| base_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| base_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| base_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| base_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| base_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| canter | 17/17 | 14/14 | 0.85–0.85 | 0.90–0.90 | nenhum | nenhuma |
| carreta (guardada) | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| dump_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| dump_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| dump_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| dump_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| dump_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| dump_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| graneleira_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| graneleira_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| graneleira_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| graneleira_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| graneleira_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| graneleira_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| leve_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| leve_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| leve_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| leve_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| leve_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| leve_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| longo_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| longo_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| longo_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| longo_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| longo_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| longo_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| pinkbox_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| pinkbox_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| pinkbox_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| pinkbox_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| pinkbox_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| pinkbox_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| tanker_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| tanker_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| tanker_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| tanker_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tanker_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tanker_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| tarp_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| tarp_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| tarp_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| tarp_flat_quad | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tarp_flat_wide | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tarp_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |

**Total: 1736 de 1736 combinações cabem** (peça dentro da caixa, fora da lataria e de toda zona protegida).

## Matriz caminhão × lote 2 (T-231: 11 para-choques traseiros, 7 foguetes, 3 contornos do baú)

| Caminhão | Para-choques OK | Escala | Foguetes OK | Faixa / comprimento do foguete | Contornos OK | Contorno (m: dir/esq/teto) | Falhas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| alubox_americana | 11/11 | 1.03 | 7/7 | 0.34 / 8.19 m | 3/3 | 20.8/20.8/21.3 | nenhuma |
| alubox_chata | 11/11 | 1.03 | 7/7 | 0.34 / 8.24 m | 3/3 | 20.9/20.9/21.4 | nenhuma |
| alubox_curta | 11/11 | 1.03 | 7/7 | 0.34 / 9.29 m | 3/3 | 23.0/23.0/23.6 | nenhuma |
| alubox_flat_quad | 11/11 | 1.03 | 7/7 | 0.34 / 8.24 m | 3/3 | 20.9/20.9/21.4 | nenhuma |
| alubox_flat_wide | 11/11 | 1.03 | 7/7 | 0.34 / 8.24 m | 3/3 | 20.9/20.9/21.4 | nenhuma |
| alubox_jac | 11/11 | 1.03 | 7/7 | 0.34 / 9.19 m | 3/3 | 22.9/22.9/23.4 | nenhuma |
| base_americana | 11/11 | 1.08 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.5 | nenhuma |
| base_chata | 11/11 | 1.08 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.5 | nenhuma |
| base_curta | 11/11 | 1.08 | 7/7 | 0.34 / 8.94 m | 3/3 | 23.0/23.0/23.9 | nenhuma |
| base_flat_quad | 11/11 | 1.08 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.5 | nenhuma |
| base_flat_wide | 11/11 | 1.08 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.5 | nenhuma |
| base_jac | 11/11 | 1.08 | 7/7 | 0.34 / 8.39 m | 3/3 | 21.9/21.9/22.8 | nenhuma |
| canter | 11/11 | 0.95 | 7/7 | 0.34 / 4.54 m | 3/3 | 13.1/13.1/14.4 | nenhuma |
| carreta (guardada) | 11/11 | 1.03 | 7/7 | 0.34 / 13.09 m | 3/3 | 28.7/28.7/31.1 | nenhuma |
| dump_americana | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_chata | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_curta | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_flat_quad | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_flat_wide | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_jac | 11/11 | 1.06 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_americana | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_chata | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_curta | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_flat_quad | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_flat_wide | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_jac | 11/11 | 1.00 | só baú fechado | — | só baú fechado | — | nenhuma |
| leve_americana | 11/11 | 1.03 | 7/7 | 0.34 / 4.89 m | 3/3 | 13.4/13.4/15.4 | nenhuma |
| leve_chata | 11/11 | 1.03 | 7/7 | 0.34 / 4.94 m | 3/3 | 13.9/13.9/15.5 | nenhuma |
| leve_curta | 11/11 | 1.03 | 7/7 | 0.34 / 6.09 m | 3/3 | 15.6/15.6/17.9 | nenhuma |
| leve_flat_quad | 11/11 | 1.03 | 7/7 | 0.34 / 4.94 m | 3/3 | 13.9/13.9/15.5 | nenhuma |
| leve_flat_wide | 11/11 | 1.03 | 7/7 | 0.34 / 4.94 m | 3/3 | 13.9/13.9/15.5 | nenhuma |
| leve_jac | 11/11 | 1.03 | 7/7 | 0.34 / 5.59 m | 3/3 | 15.3/15.3/16.8 | nenhuma |
| longo_americana | 11/11 | 1.03 | 7/7 | 0.34 / 9.29 m | 3/3 | 22.0/22.0/24.2 | nenhuma |
| longo_chata | 11/11 | 1.03 | 7/7 | 0.34 / 9.34 m | 3/3 | 22.0/22.0/24.3 | nenhuma |
| longo_curta | 11/11 | 1.03 | 7/7 | 0.34 / 10.49 m | 3/3 | 24.3/24.3/26.7 | nenhuma |
| longo_flat_quad | 11/11 | 1.03 | 7/7 | 0.34 / 9.34 m | 3/3 | 22.0/22.0/24.3 | nenhuma |
| longo_flat_wide | 11/11 | 1.03 | 7/7 | 0.34 / 9.34 m | 3/3 | 22.0/22.0/24.3 | nenhuma |
| longo_jac | 11/11 | 1.03 | 7/7 | 0.34 / 9.99 m | 3/3 | 23.3/23.3/25.6 | nenhuma |
| pinkbox_americana | 11/11 | 1.03 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.1 | nenhuma |
| pinkbox_chata | 11/11 | 1.03 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.1 | nenhuma |
| pinkbox_curta | 11/11 | 1.03 | 7/7 | 0.34 / 8.69 m | 3/3 | 22.7/22.7/23.2 | nenhuma |
| pinkbox_flat_quad | 11/11 | 1.03 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.1 | nenhuma |
| pinkbox_flat_wide | 11/11 | 1.03 | 7/7 | 0.34 / 7.74 m | 3/3 | 20.6/20.6/21.1 | nenhuma |
| pinkbox_jac | 11/11 | 1.03 | 7/7 | 0.34 / 8.59 m | 3/3 | 22.5/22.5/23.0 | nenhuma |
| tanker_americana | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_chata | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_curta | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_flat_quad | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_flat_wide | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_jac | 11/11 | 0.97 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_americana | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_chata | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_curta | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_flat_quad | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_flat_wide | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_jac | 11/11 | 1.03 | só baú fechado | — | só baú fechado | — | nenhuma |

Lote 2: **936 de 936** combinações cabem. Para-choque traseiro: largura do baú, atrás de tudo o que fica
embaixo dele (substitui o para-choque e as lanternas de fábrica de baixo: leva lanternas próprias e a caixa da
placa), topo a 0,93 m (abaixo das setas). Foguete e contorno: faixas medidas por raios na lataria real
(`truck_measure.box_edges`); conferidos vértice a vértice (`StripFit.problems`).

## Matriz caminhão × pinturas (T-232: 12 murais com os 2 lados, 12 traseiras, 9 tetos)

| Caminhão | Murais OK | Lateral (m) | Traseiras OK | Traseira (m) | Tetos OK | Teto (m) | Falhas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| alubox_americana | 12/12 | 8.15 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.18 | nenhuma |
| alubox_chata | 12/12 | 8.20 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.20 | nenhuma |
| alubox_curta | 12/12 | 9.28 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 9.28 | nenhuma |
| alubox_flat_quad | 12/12 | 8.20 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.20 | nenhuma |
| alubox_flat_wide | 12/12 | 8.20 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.20 | nenhuma |
| alubox_jac | 12/12 | 9.18 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 9.20 | nenhuma |
| base_americana | 12/12 | 8.13 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 8.15 | nenhuma |
| base_chata | 12/12 | 8.13 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 8.15 | nenhuma |
| base_curta | 12/12 | 9.40 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 9.38 | nenhuma |
| base_flat_quad | 12/12 | 8.13 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 8.15 | nenhuma |
| base_flat_wide | 12/12 | 8.13 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 8.15 | nenhuma |
| base_jac | 12/12 | 8.82 × 1.98 | 12/12 | 2.40 × 1.90 | 9/9 | 2.42 × 8.80 | nenhuma |
| canter | 12/12 | 4.42 × 1.73 | 12/12 | 2.10 × 1.83 | 9/9 | 2.17 × 4.83 | nenhuma |
| carreta (guardada) | 12/12 | 13.05 × 1.85 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 13.07 | nenhuma |
| dump_americana | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_chata | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_curta | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_flat_quad | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_flat_wide | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| dump_jac | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_americana | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_chata | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_curta | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_flat_quad | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_flat_wide | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| graneleira_jac | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| leve_americana | 12/12 | 4.80 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 5.10 | nenhuma |
| leve_chata | 12/12 | 4.80 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 5.20 | nenhuma |
| leve_curta | 12/12 | 6.03 × 1.80 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 6.38 | nenhuma |
| leve_flat_quad | 12/12 | 4.80 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 5.20 | nenhuma |
| leve_flat_wide | 12/12 | 4.80 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 5.20 | nenhuma |
| leve_jac | 12/12 | 5.45 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 5.85 | nenhuma |
| longo_americana | 12/12 | 9.20 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 9.53 | nenhuma |
| longo_chata | 12/12 | 9.20 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 9.60 | nenhuma |
| longo_curta | 12/12 | 10.43 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 10.78 | nenhuma |
| longo_flat_quad | 12/12 | 9.20 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 9.60 | nenhuma |
| longo_flat_wide | 12/12 | 9.20 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 9.60 | nenhuma |
| longo_jac | 12/12 | 9.85 × 1.70 | 12/12 | 2.27 × 1.88 | 9/9 | 2.38 × 10.25 | nenhuma |
| pinkbox_americana | 12/12 | 7.90 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.00 | nenhuma |
| pinkbox_chata | 12/12 | 7.90 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.00 | nenhuma |
| pinkbox_curta | 12/12 | 9.00 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 9.03 | nenhuma |
| pinkbox_flat_quad | 12/12 | 7.90 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.00 | nenhuma |
| pinkbox_flat_wide | 12/12 | 7.90 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.00 | nenhuma |
| pinkbox_jac | 12/12 | 8.82 × 2.23 | 12/12 | 2.27 × 2.13 | 9/9 | 2.38 × 8.93 | nenhuma |
| tanker_americana | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_chata | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_curta | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_flat_quad | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_flat_wide | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tanker_jac | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_americana | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_chata | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_curta | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_flat_quad | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_flat_wide | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |
| tarp_jac | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |

Pinturas: **1056 de 1056** combinações cabem (os murais contam os 2 lados numa combinação). Cada face é um retângulo
medido por raios no plano real da lataria (`blender/scripts/lib/paint_measure.py`), por dentro do contorno de LED;
a arte nunca sai espelhada (u × v = normal) e fica fora das zonas protegidas (a traseira é tinta na porta: isenta só
de `rear_doors`). Conferido por `PaintFit.problems`.

## Matriz caminhão × lote 4 (T-233: 11 para-choques da frente, 6 retrovisores, 3 escadas, 8 saias)

| Caminhão | Para-choques OK | Altura livre / faixa do meio | Retrovisores OK | Escadas OK | Saias OK | Trechos da saia (dir., m) | Falhas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| alubox_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | 3/3 | 8/8 | 1.62 + 1.48 | nenhuma |
| alubox_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | 8/8 | 1.63 + 1.48 | nenhuma |
| alubox_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | 3/3 | 8/8 | 2.71 + 1.48 | nenhuma |
| alubox_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.63 + 1.48 | nenhuma |
| alubox_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.63 + 1.48 | nenhuma |
| alubox_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | 3/3 | 8/8 | 2.62 + 1.48 | nenhuma |
| base_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| base_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| base_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | 3/3 | 8/8 | 2.75 + 1.48 | nenhuma |
| base_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| base_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| base_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | 3/3 | 8/8 | 2.29 + 1.48 | nenhuma |
| canter | 11/11 | 0.37 m / ×0.92 | 6/6 | 3/3 | 8/8 | 2.74 | nenhuma |
| carreta (guardada) | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | — | — | nenhuma |
| dump_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | só baú fechado | 8/8 | 1.68 + 0.78 + 1.78 | nenhuma |
| dump_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | só baú fechado | 8/8 | 1.74 + 0.83 + 1.83 | nenhuma |
| dump_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | só baú fechado | 8/8 | 0.78 + 1.78 + 0.83 + 1.83 | nenhuma |
| dump_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.74 + 0.83 + 1.83 | nenhuma |
| dump_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.74 + 0.83 + 1.83 | nenhuma |
| dump_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | só baú fechado | 8/8 | 0.69 + 1.78 + 0.83 + 1.83 | nenhuma |
| graneleira_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | só baú fechado | 8/8 | 1.46 + 1.48 | nenhuma |
| graneleira_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | só baú fechado | 8/8 | 1.44 + 1.48 | nenhuma |
| graneleira_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | só baú fechado | 8/8 | 2.61 + 1.48 | nenhuma |
| graneleira_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.44 + 1.48 | nenhuma |
| graneleira_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.44 + 1.48 | nenhuma |
| graneleira_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | só baú fechado | 8/8 | 2.29 + 1.48 | nenhuma |
| leve_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | 3/3 | 8/8 | 1.46 | nenhuma |
| leve_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | 8/8 | 1.48 | nenhuma |
| leve_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | 3/3 | 8/8 | 2.68 | nenhuma |
| leve_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 | nenhuma |
| leve_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 | nenhuma |
| leve_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | 3/3 | 8/8 | 2.29 | nenhuma |
| longo_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | 3/3 | 8/8 | 1.46 + 1.58 | nenhuma |
| longo_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | 8/8 | 1.48 + 1.58 | nenhuma |
| longo_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | 3/3 | 8/8 | 2.68 + 1.58 | nenhuma |
| longo_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.58 | nenhuma |
| longo_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.58 | nenhuma |
| longo_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | 3/3 | 8/8 | 2.29 + 1.58 | nenhuma |
| pinkbox_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| pinkbox_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| pinkbox_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | 3/3 | 8/8 | 2.48 + 1.48 | nenhuma |
| pinkbox_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| pinkbox_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | 3/3 | 8/8 | 1.48 + 1.48 | nenhuma |
| pinkbox_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | 3/3 | 8/8 | 2.38 + 1.48 | nenhuma |
| tanker_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | só baú fechado | 8/8 | 1.49 + 1.58 | nenhuma |
| tanker_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | só baú fechado | 8/8 | 1.50 + 1.58 | nenhuma |
| tanker_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | só baú fechado | 8/8 | 2.59 + 1.58 | nenhuma |
| tanker_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.50 + 1.58 | nenhuma |
| tanker_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.50 + 1.58 | nenhuma |
| tanker_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | só baú fechado | 8/8 | 2.50 + 1.58 | nenhuma |
| tarp_americana | 11/11 | 0.75 m / ×1.58 | 6/6 | só baú fechado | 8/8 | 1.48 + 1.53 | nenhuma |
| tarp_chata | 11/11 | 0.89 m / ×1.64 | 6/6 | só baú fechado | 8/8 | 1.48 + 1.48 | nenhuma |
| tarp_curta | 11/11 | 0.45 m / ×1.04 | 6/6 | só baú fechado | 8/8 | 2.53 + 1.48 | nenhuma |
| tarp_flat_quad | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.48 + 1.48 | nenhuma |
| tarp_flat_wide | 11/11 | 0.34 m / ×0.48 | 6/6 | só baú fechado | 8/8 | 1.48 + 1.48 | nenhuma |
| tarp_jac | 11/11 | 0.53 m / ×1.33 | 6/6 | só baú fechado | 8/8 | 2.43 + 1.48 | nenhuma |

Lote 4: **1468 de 1468** combinações cabem (a carreta guardada não conta). Para-choque: encosta na frente do
nariz de fábrica, entre 0,16 m do chão e 3 cm abaixo do farol mais baixo; a faixa do meio estica/encolhe (coluna
"faixa do meio", para o leque de 0,42 m). Retrovisor: até 0,50 m para fora da cabine e 0,60 m à frente; o
espelho de fábrica some. Escada: por fora do contorno de LED, até 0,16 m. Saia: só nos trechos livres (tanque e
bateria de fábrica ficam de fora). Conferido vértice a vértice (`FrameFit.problems`).

## Matriz caminhão × lote 5 (T-234: grades, escapamentos, buzinas, calotas e interiores)

| Caminhão | Grades OK | Escapamentos OK | Buzinas OK | Calotas OK | Interiores OK | Falhas |
| --- | --- | --- | --- | --- | --- | --- |
| alubox_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| alubox_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| alubox_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| alubox_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| alubox_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| alubox_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| base_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| base_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| base_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| base_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| base_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| base_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| canter | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| carreta (guardada) | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| dump_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| dump_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| dump_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| dump_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| dump_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| dump_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| graneleira_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| graneleira_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| graneleira_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| graneleira_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| graneleira_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| graneleira_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| leve_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| leve_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| leve_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| leve_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| leve_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| leve_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| longo_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| longo_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| longo_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| longo_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| longo_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| longo_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| pinkbox_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| pinkbox_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| pinkbox_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| pinkbox_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| pinkbox_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| pinkbox_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tanker_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| tanker_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tanker_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tanker_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tanker_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tanker_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tarp_americana | 3/3 | 3/3 | — | 3/3 | 3/3 | nenhuma |
| tarp_chata | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tarp_curta | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tarp_flat_quad | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tarp_flat_wide | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |
| tarp_jac | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 | nenhuma |

Lote 5: **798 de 798** combinações cabem (a carreta guardada não conta). Grade: encosta na frente da cabine entre os
faróis e estica na caixa de cada cabine. Escapamento: no vão entre a cabine e a carga. Buzina: no topo da carga
(caçamba sem topo plano não tem). Calota: em cada roda de fora. Interior: pintura no retângulo do para-brisa (`PaintFit`).
Conferido vértice a vértice (`Lot5Fit.problems`, `Lot5Fit.wheel_problems`).

**Total geral (lotes 1, 2, 4, 5 e pinturas): 5994 de 5994 combinações cabem.**

## Falhas

Nenhuma. (Na 1ª rodada o teste reprovou ~70 combinações: deques 2–3 cm mais largos que a caixa e canhões fundos
demais na cabine americana; corrigido no Blender: largura nominal = largura real da peça; canhões medidos pela
largura do teto. Imagem das caixas e zonas: `docs/capturas_t211/encaixes_zonas.png`.)

## Zonas protegidas e encaixes (exemplos)

**base_chata**: windshield, headlight_l, headlight_r, front_lamp_l, front_lamp_r, blinker_front_l, blinker_rear_l, blinker_front_r, blinker_rear_r, rear_lamp_l, rear_lamp_r, front_plate, rear_plate, door_l, door_r, wheel_f_L, wheel_f_R, wheel_r_L_1, wheel_r_L_3, wheel_r_R_1, wheel_r_R_3, rear_doors
encaixes: andon (seat), visor (seat), mirror_stay_r (stay), mirror_stay_l (stay), front_bumper (bumper), grille (grille), exhaust_stacks_r (point), exhaust_stacks_l (point), ladder_r (ladder), ladder_l (ladder), rocket_r (stretch), rocket_l (stretch), box_light_r (strips), box_light_l (strips), box_light_top (strips), side_skirts_r (runs), side_skirts_l (runs), rear_bumper (uniform), mural_r (face), mural_l (face), roof_paint (face), rear_paint (face), hubcaps (none), decals (none), horn (horn), interior (face)
**canter**: windshield, headlight_l, headlight_r, front_lamp_l, front_lamp_r, blinker_front_l, blinker_rear_l, blinker_front_r, blinker_rear_r, rear_lamp_l, rear_lamp_r, front_plate, rear_plate, door_l, door_r, wheel_f_L, wheel_f_R, wheel_r_L_1, wheel_r_R_1, rear_doors
encaixes: andon (seat), visor (seat), mirror_stay_r (stay), mirror_stay_l (stay), front_bumper (bumper), grille (grille), exhaust_stacks_r (point), exhaust_stacks_l (point), ladder_r (ladder), ladder_l (ladder), rocket_r (stretch), rocket_l (stretch), box_light_r (strips), box_light_l (strips), box_light_top (strips), side_skirts_r (runs), side_skirts_l (runs), rear_bumper (uniform), mural_r (face), mural_l (face), roof_paint (face), rear_paint (face), hubcaps (none), decals (none), horn (horn), interior (face)

Isenções declaradas: `front_plate` (a placa fica em cima do para-choque) e `blinker_front_*` (o para-choque novo
leva a seta junto) para `front_bumper`; `rear_plate` e `rear_lamp_*` (T-231: a peça leva lanternas e caixa da
placa próprias) para `rear_bumper`; rodas para `hubcaps`; `rear_doors` para `rear_paint` (T-232: tinta na porta).
T-233: o para-choque da frente leva a seta (pontos SIGNAL_L/R) e a caixa da placa; o espelho de fábrica (caixa
`hide` do encaixe `mirror_stay_*`) some enquanto a haste está montada.

