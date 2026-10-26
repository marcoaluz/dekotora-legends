"""Textos (kanji) da T-232 num lugar só. Nunca espelhados: o PaintFit garante u x v = normal em todas as faces."""

# Pintura do teto: as 9 frases aprovadas pelo Marco (DECISOES T-210, decisão 7), na ordem de roofpaint_01..09.
ROOF = ["一番星", "男花道", "爆走", "御意見無用", "唯我独尊", "義理人情", "浪漫街道", "天下御免", "夜明けまで"]

# Pintura da traseira: texto vertical à esquerda e à direita do rosto.
REAR = {
    "ryu": ("昇龍", "天翔"), "tora": ("猛虎", "咆哮"), "hannya": ("般若", "夜叉"), "oni": ("鬼神", "豪胆"),
    "kitsune": ("稲荷", "狐火"), "tengu": ("天狗", "鞍馬"), "noh": ("能楽", "幽玄"), "kabuki": ("歌舞伎", "見得"),
    "bijin": ("花魁", "夜桜"), "shishi": ("獅子", "牡丹"), "hoo": ("鳳凰", "瑞祥"), "koi": ("錦鯉", "登龍門"),
}


def all_chars() -> str:
    s = "".join(ROOF)
    for a, b in REAR.values():
        s += a + b
    return s
