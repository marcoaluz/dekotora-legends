"""T-242 (ampliação): murais estilo anime GERADOS PELO MARCO no Gemini (exceção dele à regra "nada de imagem feita por
IA"; registrada em docs/DECISOES.md e docs/CREDITOS_MURAIS.md). Só personagens adultas, sem nudez; nenhum texto/kanji
nas imagens (nada a espelhar). Um mural por lado: cada peça tem uma imagem à direita (R) e outra à esquerda (L).

Arquivos em docs/Murais/ (fora do Git). Recortes em frações (x0, y0, x1, y1) da imagem original; a arte final é
2048 x 512 (4:1). Brilho noturno só nos pontos escolhidos (lua, olhos, lanternas, neon da cidade), coordenadas da arte
final (x 0..4, y 0..1 de cima para baixo), mesmas formas de `t242_registry.py`.
"""
from __future__ import annotations

ORIGIN = "gerada pelo Marco (Gemini), uso por decisão dele (T-242)"
MOON = "#fff2d0"
NEON_P, NEON_C = "#ff5fd2", "#4fe8ff"
LANTERN = "#ffb050"

# imagens com tarja preta em cima e embaixo (1536 x 1024): só a faixa do meio, perto do rosto
TONE = {"paper": 0.0, "sat": 1.05, "gamma": 1.0, "lo": 0.2, "hi": 99.8}

ARTS = {
    ("mural_anime_neon", "R"): {"src": "laterado D.jpeg", "box": (0.0, 0.0, 1.0, 1.0), "glow": [("key", 1.2, 0.33, 0.6, 0.4, NEON_C, 0.9, 0.6)]},
    ("mural_anime_neon", "L"): {"src": "lateral esquerdo.jpeg", "box": (0.0, 0.0, 1.0, 1.0), "glow": [("key", 1.25, 0.35, 0.55, 0.4, NEON_C, 0.9, 0.6)]},
    ("mural_anime_quimono", "R"): {"src": "lateral 4.jpeg", "box": (0.0, 0.0, 1.0, 1.0), "glow": [("key", 0.7, 0.3, 0.25, 0.25, NEON_P, 0.9, 0.6)]},
    ("mural_anime_quimono", "L"): {"src": "lateral esquerdo 2.jpeg", "box": (0.0, 0.0, 1.0, 1.0), "glow": [("key", 0.5, 0.3, 0.22, 0.22, NEON_P, 0.9, 0.6), ("key", 0.95, 0.25, 0.12, 0.15, NEON_C, 0.9, 0.6)]},
    ("mural_anime_lua", "R"): {"src": "lateral.png", "box": (0.012, 0.19, 0.988, 0.62), "glow": [("disc", 3.16, 0.10, 0.17, MOON, 0.9), ("key", 3.5, 0.42, 0.55, 0.35, LANTERN, 0.8, 0.55), ("key", 1.88, 0.3, 0.08, 0.15, LANTERN, 0.8, 0.5)]},
    ("mural_anime_lua", "L"): {"src": "lateral 3.png", "box": (0.05, 0.506, 0.70, 0.744), "glow": [("key", 3.82, 0.15, 0.2, 0.25, "#ff9a60", 0.8, 0.55), ("key", 3.3, 0.37, 0.25, 0.12, LANTERN, 0.8, 0.5)]},
    ("mural_anime_cyber", "R"): {"src": "lateral 2.png", "box": (0.012, 0.17, 0.988, 0.60), "glow": [("disc", 2.65, 0.07, 0.1, MOON, 0.8), ("key", 2.65, 0.55, 0.45, 0.45, NEON_P, 0.9, 0.6), ("key", 3.1, 0.25, 0.9, 0.3, NEON_C, 0.7, 0.65), ("dots", [(3.6, 0.74), (3.66, 0.74)], 0.012, "#ff3040", 1.0)]},
    ("mural_anime_cyber", "L"): {"src": "lateral 3.png", "box": (0.08, 0.255, 0.73, 0.493), "glow": [("key", 2.85, 0.45, 0.65, 0.15, LANTERN, 0.9, 0.6)]},
    ("mural_anime_kitsune", "R"): {"src": "lateral 3.png", "box": (0.0, 0.003, 0.65, 0.241), "glow": [("eye", 0.96, 0.34, 0.035, 0.02, "#ff3030", 1.0, -10.0), ("eye", 1.29, 0.31, 0.02, 0.015, "#ff3030", 0.9, 10.0), ("key", 3.8, 0.35, 0.3, 0.35, "#ff5050", 0.8, 0.55)]},
    ("mural_anime_kitsune", "L"): {"src": "lateral 3.png", "box": (0.0, 0.757, 0.65, 0.997), "glow": [("key", 0.5, 0.42, 0.14, 0.15, "#4fa8ff", 1.0, 0.45), ("key", 2.78, 0.22, 0.1, 0.25, LANTERN, 0.9, 0.55), ("key", 3.83, 0.22, 0.1, 0.25, LANTERN, 0.9, 0.55)]},
}

NAMES = {
    "mural_anime_neon": "Dama do quimono na cidade neon",
    "mural_anime_quimono": "Dama do quimono vermelho e ondas",
    "mural_anime_lua": "Damas da lua vermelha",
    "mural_anime_cyber": "Dama cyber e glicínias",
    "mural_anime_kitsune": "Dama da raposa e borboleta azul",
}


def pieces():
    out = []
    for pid, _side in ARTS:
        if pid not in out:
            out.append(pid)
    return out
