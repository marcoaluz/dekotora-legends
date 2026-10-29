"""T-266: imagens "Praia" do Marco (docs/Murais/Paria/, fora do Git; arte do Marco, criada por ele) no grupo Wallpapers.

Cada arte: `src` (arquivo), `box` (recorte em pixels da imagem original: x0, y0, x1, y1), `size` (arte final em px),
`focus` (ponto que o jogo deixa no centro quando corta para a proporção de cada baú: o rosto; frações da arte FINAL,
v = 0 no topo), `keep` (fração mínima visível antes de esticar; murais 0,45 = a carreta 7:1 quase não estica),
`rot` (teto: gira 90° anti-horário, o alto da imagem vai para o lado esquerdo do caminhão: lê-se de pé olhando do lado
direito) e `glow` (pontos que acendem à noite, por COR dentro de uma elipse: (x, y, rx, ry, cor alvo, tolerância, força),
x/y em frações da arte ANTES de girar, rx/ry em frações da altura).

Lados do mural: no lado direito a direita da imagem é a frente do caminhão; no esquerdo, a esquerda é a frente. Por
isso o rosto olhando/à direita vai no lado direito e o rosto à esquerda no lado esquerdo (as duas olham para a frente).
"""
from __future__ import annotations

ORIGIN = "arte do Marco (criada por ele), uso por decisão dele (grupo Wallpapers, T-266; ver docs/CREDITOS_MURAIS.md)"
SRC_DIR = "docs/Murais/Paria"

PURPLE = (0.55, 0.22, 0.85)     # hibisco roxo no cabelo
PINK = (1.0, 0.35, 0.62)        # drinque rosa, hibisco
HEART = (0.95, 0.18, 0.48)      # óculos de coração
ORANGE = (1.0, 0.62, 0.12)      # drinque de laranja, guarda-sol
WARM = (1.0, 0.82, 0.45)        # lanterna
WHITE = (0.95, 0.97, 1.0)       # kanji pintado em branco
KPINK = (1.0, 0.3, 0.55)        # kanji rosa (キツネ)

# 3:1 (2172 x 724 na fonte). Peso do APK: 512 px de altura = a mesma densidade (px por metro de baú) dos murais da
# T-232 (2048 x 512 em 4:1); 2048 x 684 custava 0,94 MB de ETC2 por lado, 1536 x 512 custa 0,52 MB.
MURAL = (1536, 512)
ROOF = (960, 320)               # antes de girar (1:3 depois); teto quase só se vê de cima
FULL = (2.1, 0.0, 2169.9, 724.0)
KEEP_MURAL = 0.45

PIECES = [
    {"id": "wall_praia_raposa_dourada", "kind": "mural", "label": "Wallpaper: Raposa dourada na praia",
     "price": 30000, "fame": 22, "sides": {
         "R": {"src": "Raposa Loira na Praia Tropical-4.png", "box": FULL, "size": MURAL, "focus": (0.63, 0.45),
               "keep": KEEP_MURAL, "glow": [(0.595, 0.11, 0.09, 0.12, PURPLE, 0.33, 1.1), (0.83, 0.79, 0.06, 0.2, ORANGE, 0.3, 1.0)]},
         "L": {"src": "Raposa Dourada na Praia Tropical-3.png", "box": FULL, "size": MURAL, "focus": (0.33, 0.42),
               "keep": KEEP_MURAL, "glow": [(0.235, 0.2, 0.07, 0.2, PURPLE, 0.33, 1.1), (0.135, 0.74, 0.07, 0.24, PINK, 0.3, 1.0),
                                            (0.105, 0.56, 0.05, 0.08, ORANGE, 0.3, 0.9)]}}},
    {"id": "wall_praia_raposa_tropical", "kind": "mural", "label": "Wallpaper: Raposa tropical",
     "price": 30000, "fame": 22, "sides": {
         "R": {"src": "Raposa Tropical em Dia de Praia.png", "box": FULL, "size": MURAL, "focus": (0.62, 0.40),
               "keep": KEEP_MURAL, "glow": [(0.58, 0.14, 0.08, 0.13, PURPLE, 0.33, 1.1), (0.972, 0.21, 0.03, 0.16, WARM, 0.32, 1.3),
                                            (0.91, 0.72, 0.05, 0.12, PINK, 0.3, 0.9)]},
         "L": {"src": "Raposa Dourada na Praia Tropical-5.png", "box": FULL, "size": MURAL, "focus": (0.33, 0.38),
               "keep": KEEP_MURAL, "glow": [(0.24, 0.17, 0.06, 0.18, PURPLE, 0.33, 1.1), (0.925, 0.82, 0.05, 0.2, ORANGE, 0.3, 1.0),
                                            (0.045, 0.22, 0.04, 0.12, PINK, 0.3, 0.8)]}}},
    {"id": "wall_praia_amigas", "kind": "mural", "label": "Wallpaper: Gatinha e amigas na praia",
     "price": 30000, "fame": 22, "sides": {
         "R": {"src": "Gatinha Anime na Praia Tropical.png", "box": FULL, "size": MURAL, "focus": (0.60, 0.40),
               "keep": KEEP_MURAL, "glow": [(0.635, 0.09, 0.07, 0.09, HEART, 0.33, 1.2), (0.73, 0.58, 0.04, 0.2, PINK, 0.3, 1.0),
                                            (0.765, 0.32, 0.03, 0.05, ORANGE, 0.3, 0.9)]},
         "L": {"src": "Paraíso Tropical das Garotas Raposa.png", "box": FULL, "size": MURAL, "focus": (0.58, 0.36),
               "keep": KEEP_MURAL, "glow": [(0.315, 0.11, 0.07, 0.08, HEART, 0.33, 1.2), (0.465, 0.24, 0.05, 0.14, PURPLE, 0.33, 1.1),
                                            (0.365, 0.63, 0.03, 0.14, PINK, 0.3, 1.0)]}}},
    {"id": "wallrear_praia_verao", "kind": "rear", "label": "Traseira (wallpaper): Praia, mar de verão 夏の海",
     "price": 14000, "fame": 12, "sides": {
         "R": {"src": "parte de traz - praia.png", "box": (0.0, 1.0, 765.0, 638.5), "size": (768, 640), "focus": (0.44, 0.5),
               "glow": [(0.12, 0.45, 0.13, 0.36, WHITE, 0.18, 0.9), (0.55, 0.14, 0.12, 0.08, HEART, 0.33, 1.2),
                        (0.855, 0.6, 0.05, 0.16, PINK, 0.3, 1.0)]}}},
    {"id": "wallrear_praia_amigas", "kind": "rear", "label": "Traseira (wallpaper): Praia, raposa e coelhinhas",
     "price": 14000, "fame": 12, "sides": {
         "R": {"src": "parte de traz - praia.png", "box": (772.0, 1.0, 1536.0, 637.7), "size": (768, 640), "focus": (0.54, 0.5),
               "glow": [(0.395, 0.23, 0.06, 0.2, KPINK, 0.3, 1.1), (0.92, 0.75, 0.06, 0.15, WHITE, 0.18, 0.9),
                        (0.10, 0.22, 0.06, 0.1, PURPLE, 0.33, 1.1)]}}},
    {"id": "wallroof_praia_raposa", "kind": "roof", "label": "Teto (wallpaper): Raposa na praia",
     "price": 12000, "fame": 10, "sides": {
         "R": {"src": "Garota Raposa na Praia Tropical-2.png", "box": FULL, "size": ROOF, "rot": True,
               "focus": (0.40, 0.40), "keep": KEEP_MURAL,
               "glow": [(0.595, 0.12, 0.07, 0.13, PURPLE, 0.33, 1.1), (0.925, 0.27, 0.03, 0.14, WARM, 0.32, 1.3)]}}},
]
# Teto: `size` é ANTES de girar (960 x 320 -> 320 x 960, 1:3); `focus` já é na arte girada: (fy, 1 - fx) do rosto
# (0,40; 0,60 da imagem) = (0,40; 0,40).
