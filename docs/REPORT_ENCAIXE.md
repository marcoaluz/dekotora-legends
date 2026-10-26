# Relatório de encaixe das peças da oficina (gerado)

Gerado por `godot --headless --path game -s res://tools_dev/report_part_fit.gd` (T-211). Não edite à mão.
Regras: `game/scripts/truck/part_fit.gd`; encaixes e zonas: `game/assets/vehicles/dekotora/truck/sockets/*.json`
(gerados por `blender/scripts/build_sockets.py`). Teste automático: `game/tests/test_part_fit.gd`.

## Matriz caminhão × lote 1 (17 deques + 14 viseiras)

| Caminhão | Deques OK | Viseiras OK | Escala deque | Escala viseira | Encaixes que se cruzam / entram em zona | Falhas |
| --- | --- | --- | --- | --- | --- | --- |
| alubox | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| base_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| base_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| base_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| base_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| canter | 17/17 | 14/14 | 0.85–0.85 | 0.90–0.90 | nenhum | nenhuma |
| carreta (guardada) | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| dump | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| graneleira_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| graneleira_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| graneleira_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| graneleira_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| leve_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| leve_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| leve_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| leve_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| longo_americana | 17/17 | 14/14 | 0.70–0.70 | 0.92–0.92 | nenhum | nenhuma |
| longo_chata | 17/17 | 14/14 | 0.85–0.86 | 1.03–1.03 | nenhum | nenhuma |
| longo_curta | 17/17 | 14/14 | 0.89–0.91 | 1.01–1.01 | nenhum | nenhuma |
| longo_jac | 17/17 | 14/14 | 0.91–0.93 | 1.06–1.06 | nenhum | nenhuma |
| pinkbox | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tanker | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |
| tarp | 17/17 | 14/14 | 1.12–1.15 | 1.15–1.15 | nenhum | nenhuma |

**Total: 713 de 713 combinações cabem** (peça dentro da caixa, fora da lataria e de toda zona protegida).

## Falhas

Nenhuma. (Na 1ª rodada o teste reprovou ~70 combinações: deques 2–3 cm mais largos que a caixa e canhões fundos
demais na cabine americana; corrigido no Blender: largura nominal = largura real da peça; canhões medidos pela
largura do teto. Imagem das caixas e zonas: `docs/capturas_t211/encaixes_zonas.png`.)

## Zonas protegidas e encaixes (exemplos)

**base_chata**: windshield, headlight_l, headlight_r, front_lamp_l, front_lamp_r, blinker_front_l, blinker_rear_l, blinker_front_r, blinker_rear_r, rear_lamp_l, rear_lamp_r, front_plate, rear_plate, door_l, door_r, wheel_f_L, wheel_f_R, wheel_r_L_1, wheel_r_L_3, wheel_r_R_1, wheel_r_R_3, rear_doors
encaixes: andon (seat), visor (seat), mirror_stay_r (uniform), mirror_stay_l (uniform), front_bumper (uniform), grille (uniform), exhaust_stacks_r (point), exhaust_stacks_l (point), ladder_r (stretch_y), ladder_l (stretch_y), rocket (stretch9), box_light_top (face), box_light_r (face), box_light_l (face), side_skirts_r (stretch9), side_skirts_l (stretch9), rear_bumper (uniform), mural_r (face), mural_l (face), roof_paint (face), rear_paint (face), hubcaps (none), horn (none), interior (none), decals (none)
**canter**: windshield, headlight_l, headlight_r, front_lamp_l, front_lamp_r, blinker_front_l, blinker_rear_l, blinker_front_r, blinker_rear_r, rear_lamp_l, rear_lamp_r, front_plate, rear_plate, door_l, door_r, wheel_f_L, wheel_f_R, wheel_r_L_1, wheel_r_R_1, rear_doors
encaixes: andon (seat), visor (seat), mirror_stay_r (uniform), mirror_stay_l (uniform), front_bumper (uniform), grille (uniform), exhaust_stacks_r (point), exhaust_stacks_l (point), ladder_r (stretch_y), ladder_l (stretch_y), rocket (stretch9), box_light_top (face), box_light_r (face), box_light_l (face), side_skirts_r (stretch9), side_skirts_l (stretch9), rear_bumper (uniform), mural_r (face), mural_l (face), roof_paint (face), rear_paint (face), hubcaps (none), horn (none), interior (none), decals (none)

Isenções declaradas: `front_plate` (a placa fica em cima do para-choque) e `blinker_front_*` (o para-choque novo
leva a seta junto) para `front_bumper`; `rear_plate` para `rear_bumper`; rodas para `hubcaps`.

