"""Tabela única das 33 pinturas da T-232 (12 murais, 12 traseiras, 9 tetos): id, nome, preço, destaque e a função que
desenha cada arte. Lida pelo build do Blender (`build_t232_paint.py`) e pelo gerador de dados (`tools/gen_t232_data.py`).
Números = PROPOSTA (docs/BALANCEAMENTO.md, seção T-232). Raridade e "fama mínima" seguem a faixa de preço (decisão 4:
só etiqueta, não trava a compra)."""
from __future__ import annotations

OUT_DIR = "game/assets/vehicles/dekotora/paint_t232"
RES_DIR = "res://assets/vehicles/dekotora/paint_t232"

# Murais: (id, módulo, função, nome, preço ¥, destaque)
MURALS = [
    ("mural_ryu_kumo", "t232_murals_a", "ryu_kumo", "Dragão nas nuvens", 58000, 40),
    ("mural_ryu_nami", "t232_murals_a", "ryu_nami", "Dragão e ondas", 54000, 38),
    ("mural_tora_take", "t232_murals_b", "tora_take", "Tigre no bambuzal", 44000, 32),
    ("mural_tora_yuki", "t232_murals_b", "tora_yuki", "Tigre na neve", 46000, 32),
    ("mural_nami_fuji", "t232_murals_a", "nami_fuji", "Grande onda e Fuji", 26000, 22),
    ("mural_kabuki", "t232_murals_c", "kabuki", "Kabuki", 40000, 30),
    ("mural_musha", "t232_murals_c", "musha", "Guerreiro samurai", 48000, 34),
    ("mural_bijin_ogi", "t232_murals_c", "bijin_ogi", "Dama do leque", 34000, 28),
    ("mural_bijin_tsuki", "t232_murals_c", "bijin_tsuki", "Dama sob a lua", 36000, 28),
    ("mural_hoo", "t232_murals_c", "hoo", "Fênix e grous", 34000, 28),
    ("mural_men", "t232_murals_c", "men", "Máscaras do Japão", 38000, 30),
    ("mural_koi", "t232_murals_b", "koi", "Carpas", 28000, 22),
]
# Traseiras: (id, tipo em t232_rear.ORDER, nome, preço, destaque)
REARS = [
    ("rearpaint_ryu", "ryu", "Traseira: dragão", 28000, 24),
    ("rearpaint_tora", "tora", "Traseira: tigre", 26000, 22),
    ("rearpaint_hannya", "hannya", "Traseira: hannya", 24000, 21),
    ("rearpaint_oni", "oni", "Traseira: oni", 23000, 20),
    ("rearpaint_kitsune", "kitsune", "Traseira: raposa", 17000, 15),
    ("rearpaint_tengu", "tengu", "Traseira: tengu", 18000, 16),
    ("rearpaint_noh", "noh", "Traseira: máscara de Noh", 16000, 14),
    ("rearpaint_kabuki", "kabuki", "Traseira: kabuki", 21000, 18),
    ("rearpaint_bijin", "bijin", "Traseira: gueixa", 19000, 17),
    ("rearpaint_shishi", "shishi", "Traseira: leão do kabuki", 22000, 19),
    ("rearpaint_hoo", "hoo", "Traseira: fênix", 20000, 18),
    ("rearpaint_koi", "koi", "Traseira: carpas", 15000, 14),
]
# Tetos: (id, índice da frase em t232_texts.ROOF, nome, preço, destaque)
ROOFS = [
    ("roofpaint_01", 0, "Teto: 一番星 (estrela nº 1)", 12000, 10),
    ("roofpaint_02", 1, "Teto: 男花道 (caminho de honra)", 13000, 11),
    ("roofpaint_03", 2, "Teto: 爆走 (corrida louca)", 14000, 12),
    ("roofpaint_04", 3, "Teto: 御意見無用 (dispenso opinião)", 15000, 12),
    ("roofpaint_05", 4, "Teto: 唯我独尊 (único no mundo)", 16000, 13),
    ("roofpaint_06", 5, "Teto: 義理人情 (dever e coração)", 17000, 14),
    ("roofpaint_07", 6, "Teto: 浪漫街道 (estrada romântica)", 18000, 14),
    ("roofpaint_08", 7, "Teto: 天下御免 (licença do mundo)", 19000, 15),
    ("roofpaint_09", 8, "Teto: 夜明けまで (até o amanhecer)", 20000, 16),
]
# Tamanhos (largura x altura) e proporção (largura/altura) das artes
MURAL_PX = (1536, 384)        # 2048 x 512 custava 17,8 MB de ETC2 no APK (24 lados); 1536 x 384 ~10 MB
REAR_PX = (640, 512)
ROOF_PX = {"long": (256, 1024), "short": (256, 512)}


def rarity(price: int) -> str:
    return "comum" if price < 15000 else "incomum" if price < 30000 else "rara" if price < 50000 else "lendaria"


def fame_min(price: int) -> int:
    return 0 if price < 15000 else 20 if price < 30000 else 60 if price < 50000 else 120


def files() -> dict:
    """{id: {"slot", "zones", "sides": {lado: [(arquivo da cor, arquivo da emissão, proporção, (w, h)), ...]}}}"""
    out = {}
    for pid, _m, _f, *_ in MURALS:
        out[pid] = {"slot": "mural", "zones": ["left", "right"], "socket": "mural_r", "socket_left": "mural_l",
                    "sides": {s.upper(): [(f"mural/{pid}_{s}.png", f"mural/{pid}_{s}_emit.png", 4.0, MURAL_PX)] for s in ("r", "l")}}
    for pid, *_ in REARS:
        out[pid] = {"slot": "rear_paint", "zones": ["rear"], "socket": "rear_paint",
                    "sides": {"R": [(f"rear/{pid}.png", f"rear/{pid}_emit.png", REAR_PX[0] / REAR_PX[1], REAR_PX)]}}
    for pid, *_ in ROOFS:
        out[pid] = {"slot": "roof_paint", "zones": ["roof"], "socket": "roof_paint",
                    "sides": {"R": [(f"roof/{pid}_{k}.png", f"roof/{pid}_{k}_emit.png", ROOF_PX[k][0] / ROOF_PX[k][1], ROOF_PX[k])
                                    for k in ("long", "short")]}}
    return out
