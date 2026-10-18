"""Canter / cabine curta (T-125): o que fazer com cada peça do JAC 1045 (as peças vêm com nome, em espanhol).

PARTS[nome] = (material NOSSO ou "drop", grupo, teto de triângulos ou None = mantém)
  grupo "cab"     = cabine (entra no Canter e na cabine curta dos baús grandes);
  grupo "chassis" = chassi, motor, suspensão, tanque/caixa, barra das lanternas (só no Canter: os baús grandes têm o nosso).
Descartados: emblema "JAC" da frente (marca), o plano de fundo da grade ("malla_fondo"), o vidro do farol (escurece o
farol aceso), as rodas originais (usamos as nossas `wheels.make_wheel`, que o TruckNode gira) e um pedaço do motor.
Materiais = nomes de `pbr.truck_set` (o jogo tinge "paint_white", troca o cromo pelo matcap e aplica as texturas
compartilhadas pelo nome).
"""
from __future__ import annotations

PARTS = {
    # --- cabine: casca, portas e painel da frente pintados (o jogo tinge pelo nome paint_white)
    "CABINA": ("paint_white_panel", "cab", None),
    "CAPOTA": ("paint_white_panel", "cab", None),
    "PUERTA_Left": ("paint_white_panel", "cab", None),
    "PUERTA_Right": ("paint_white_panel", "cab", None),
    "Cubre_Motor": ("plastic", "cab", 300),               # forro das caixas de roda / base da cabine
    "GUARDABARRO": ("plastic_trim", "cab", 500),          # para-lama atrás da roda dianteira
    "GUARDABARRO.001": ("plastic", "cab", None),
    "GUARDABARRO.002": ("rubber", "cab", 160),            # protetor de lama
    "Babero": ("plastic_trim", "cab", 200),               # saia da frente
    "PARACHOQUES": ("plastic_trim", "cab", None),
    "PARACHOQUES.001": ("plastic_trim", "cab", 500),
    "Escalones": ("plastic", "cab", 260),
    "Escalones.001": ("diamond", "cab", None),
    # --- frente: grade cromada com fundo preto, faróis (carcaça cromada, lâmpada acesa), neblina, piscas
    "PARRILLA": ("chrome", "cab", 600),
    "Parrilla_fondo": ("plastic", "cab", None),
    "Parrilla_fondo.001": ("drop", "cab", None),          # plano "malla_fondo" (fundo cinza da grade)
    "Frente_JAC_Emblema": ("drop", "cab", None),          # marca
    "FAROS_DELANTEROS": ("chrome", "cab", 260),
    "Focos_Enciende_0": ("chrome", "cab", 220),
    "Focos_Enciende_0_1": ("lamp_white", "cab", None),
    "Focos_Enciende_1": ("chrome", "cab", 500),
    "Focos_Enciende_1.001": ("lamp_amber", "cab", 260),
    "Focos_Enciende_2": ("chrome", "cab", 260),
    "Focos_Enciende_2.001": ("lamp_white", "cab", 260),
    "Vidrio_de_foco": ("drop", "cab", None),
    "Luces_Uribechoques": ("plastic", "cab", None),
    "Luces_Uribechoques.001": ("plastic", "cab", None),
    "Luces_Uribechoques_1": ("lamp_white", "cab", None),
    "Lucesita": ("lamp_amber", "cab", None),
    "Lucesita.001": ("plastic", "cab", 100),
    "Lucesita_l": ("plastic", "cab", 100),
    "Lucesita_l.001": ("lamp_amber", "cab", None),
    # --- vidros e borrachas
    "PARABRISAS": ("glass_wind", "cab", None),
    "bisel_parabrisas": ("plastic", "cab", 220),
    "bisel_parabrisas.001": ("plastic", "cab", 120),
    "Base_limpoiapara": ("plastic", "cab", None),
    "LIMPIAPARABRISA": ("plastic", "cab", 260),
    "LIMPIAPARABRISA.001": ("steel", "cab", None),
    "LIMPIAPARABRISA.002": ("plastic", "cab", 160),
    "Vidrio_puerta": ("glass", "cab", None),
    "Vidrio_puerta_l": ("glass", "cab", None),
    "Bisel_Vidrio": ("plastic", "cab", 140),
    "Bisel_Vidrio_l": ("plastic", "cab", 140),
    "vidrio_trasero": ("glass", "cab", None),
    "Biseles_Parabrisas_trasero": ("plastic", "cab", 160),
    "Manija_de_puerta": ("chrome", "cab", 120),
    "Manija_de_puerta_l": ("chrome", "cab", 120),
    # --- retrovisores: carcaça preta, espelho cromado
    "Espejos": ("plastic", "cab", 420),
    "Espejos.001": ("chrome", "cab", None),
    "Espejos.002": ("plastic", "cab", 320),
    # --- chassi do Canter (os baús grandes usam o nosso chassi)
    "Chassis": ("plastic", "chassis", 1400),
    "Motore": ("plastic", "chassis", 700),                # quase todo escondido sob a cabine
    "Motore.001": ("drop", "chassis", None),
    "suspensi_n": ("steel", "chassis", 1500),             # molas, eixos, cardã e o snorkel atrás da cabine
    "suspensi_n.001": ("steel", "chassis", 150),
    "Tanque_y_caja": ("chrome", "chassis", None),         # cintas e tampas
    "Tanque_y_caja.001": ("steel", "chassis", 500),       # tanque (esq.) e caixa de ferramentas (dir.)
    "Luces_y_luces_traseras": ("plastic", "chassis", 500),
    "Luces_y_luces_traseras_0": ("plastic", "chassis", 1400),   # para-lamas traseiros e barra das lanternas
    "Luces_y_mas_luces_0": ("lamp_red", "chassis", None),        # refletores da barra traseira
    "Luces_y_mas_luces_1": ("lamp_amber", "chassis", None),      # refletores laterais
    "Luces_y_mas_luces_2": ("lamp_amber", "chassis", None),      # pisca
    "Luces_y_mas_luces_3": ("lamp_red", "chassis", None),        # lanterna/freio
    "Luces_y_mas_luces_4": ("lamp_white", "chassis", None),      # ré
}


def is_wheel(name: str) -> bool:
    return name.startswith("Llantas")


def spec(name: str):
    """(material, grupo, teto) da peça; rodas e peças desconhecidas são descartadas."""
    if is_wheel(name):
        return ("drop", "wheel", None)
    return PARTS.get(name, ("drop", "unknown", None))
