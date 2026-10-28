"""T-242: pinturas a partir de obras prontas de domínio público (ukiyo-e e biombos). Substituem a arte por código da
T-232 nas MESMAS peças (mesmo id: quem já comprou ganha a versão nova; protocolo de rede não muda).

Cada arte: como compor (recorte único, quadros lado a lado ou traseira com kanji), tratamento de cor e o brilho noturno
DESENHADO À MÃO só nos pontos escolhidos (coordenadas da arte final: x 0..aspect, y 0..1 de cima para baixo).
Obras, links e licenças: `t242_sources.py`. Build: `blender/scripts/build_t242_ukiyoe.py`.

Brilho (tuplas):
  ("disc", x, y, r, cor, força)                 lua / sol / lanterna
  ("eye", x, y, rx, ry, cor, força, giro)       olho
  ("dots", [(x, y), ...], r, cor, força)        vaga-lumes, olhos pequenos
  ("line", [(x, y), ...], largura, cor, força)  raio, feixe, lâmina
  ("key", x, y, rx, ry, cor, força, limiar)     só as partes claras da obra dentro da elipse
"""
from __future__ import annotations

MURAL_PX = (2048, 512)      # T-232 usava 1536 x 384; foto de obra perde detalhe demais nisso (ver DECISOES T-242)
MURAL_EMIT_SCALE = 4        # emissão 512 x 128 (o tamanho que o MuralGlow já usa)
REAR_PX = (800, 640)        # T-232: 640 x 512
REAR_EMIT_SCALE = 2
DIM = 0.2                   # parte da obra que "acende" com as luzinhas do baú à noite (T-232 usava 0,3 na arte toda)

# tons comuns
SCREEN = {"paper": 0.7, "paper_lo": 0.45, "paper_hi": 0.78, "paper_sat": 0.36, "paper_tint": (0.52, 0.42, 0.3),
          "sat": 1.25, "gamma": 1.12}                     # biombo de seda clara: fundo bem mais escuro
GOLD = {"paper": 0.3, "paper_sat": 0.3, "sat": 1.1, "gamma": 1.05}  # biombo de folha de ouro: quase como está
PRINT = {"paper": 0.4, "paper_lo": 0.6, "paper_hi": 0.88, "paper_sat": 0.28, "sat": 1.2, "gamma": 1.06}
SCENE = {"paper": 0.55, "paper_lo": 0.5, "paper_hi": 0.85, "paper_sat": 0.3, "paper_tint": (0.55, 0.45, 0.33),
         "sat": 1.22, "gamma": 1.08}                      # gravura de paisagem: papel mais escuro (rostos à parte)
EYE = "#d8ff6a"     # olho de tigre aceso (amarelo-esverdeado)
FIREFLIES = [(0.15, 0.15), (0.3, 0.35), (0.55, 0.12), (0.68, 0.55), (0.82, 0.2), (1.0, 0.08), (1.25, 0.62),
             (1.32, 0.3), (1.38, 0.12), (1.95, 0.1), (2.1, 0.28), (2.35, 0.08), (2.45, 0.33), (2.55, 0.55),
             (2.62, 0.18), (2.7, 0.4), (3.05, 0.06), (3.35, 0.12), (3.62, 0.25), (3.7, 0.62), (3.8, 0.1), (3.85, 0.45)]
BEAM = [(0.85, 0.31), (1.3, 0.38), (1.75, 0.45), (2.2, 0.52), (2.65, 0.6), (3.1, 0.67), (3.55, 0.74), (3.9, 0.8)]

ARTS = {
    # ---------------------------------------------------------------------------------------------- tigres
    ("mural_tora_take", "R"): {"layout": "crop", "src": "soga_tiger", "box": (0.025, 0.24, 0.985, 0.84),
                               "tone": SCREEN, "glow": [("eye", 2.218, 0.355, 0.017, 0.022, EYE, 1.0, 0.0),
                                                        ("eye", 2.31, 0.41, 0.028, 0.019, EYE, 1.0, 0.0)]},
    ("mural_tora_take", "L"): {"layout": "crop", "src": "sekkei_tigers", "box": (0.05, 0.615, 0.95, 0.885), "stretch": 1.2,
                               "tone": GOLD, "glow": [("eye", 0.475, 0.225, 0.03, 0.02, EYE, 1.0, 0.0),
                                                      ("eye", 2.165, 0.49, 0.02, 0.017, EYE, 1.0, 0.0),
                                                      ("eye", 2.29, 0.515, 0.034, 0.022, EYE, 1.0, 0.0)]},
    ("mural_tora_yuki", "R"): {"layout": "crop", "src": "ganku_family_r", "box": (0.03, 0.2, 0.97, 0.72),
                               "tone": SCREEN, "glow": [("eye", 1.625, 0.505, 0.013, 0.011, "#7fe8ff", 1.0, 0.0),
                                                        ("eye", 1.745, 0.51, 0.013, 0.011, "#7fe8ff", 1.0, 0.0)]},
    ("mural_tora_yuki", "L"): {"layout": "crop", "src": "ganku_family_l", "box": (0.03, 0.24, 0.97, 0.76),
                               "tone": SCREEN, "glow": [("eye", 1.12, 0.325, 0.014, 0.01, "#7fe8ff", 1.0, 0.0),
                                                        ("eye", 2.19, 0.87, 0.012, 0.009, "#7fe8ff", 1.0, 0.0),
                                                        ("eye", 2.12, 0.865, 0.01, 0.008, "#7fe8ff", 0.8, 0.0)]},
    ("rearpaint_tora", "R"): {"layout": "rear", "kind": "tora", "src": "ganku_tiger", "box": (0.0, 0.32, 0.7),
                              "tone": GOLD, "glow": [("eye", 0.435, 0.577, 0.03, 0.02, EYE, 1.0, 0.0),
                                                     ("eye", 0.639, 0.506, 0.03, 0.02, EYE, 1.0, 0.0)]},
    # ---------------------------------------------------------------------------------------------- kabuki
    ("mural_kabuki", "R"): {"layout": "tiles", "tiles": [("sharaku_omezo", (0.04, 0.07, 0.96)),
                                                         ("sharaku_hikosaburo", (0.04, 0.07, 0.96)),
                                                         ("sharaku_komazo", (0.04, 0.07, 0.96))],
                            "frame": "#ff4fb4", "tone": PRINT, "glow": []},
    ("mural_kabuki", "L"): {"layout": "tiles", "tiles": [("sharaku_ebizo", (0.04, 0.07, 0.96)),
                                                         ("sharaku_hangoro", (0.04, 0.07, 0.96)),
                                                         ("sharaku_mitsugoro", (0.04, 0.07, 0.96))],
                            "frame": "#3ff0ff", "tone": PRINT, "glow": []},
    ("rearpaint_kabuki", "R"): {"layout": "rear", "kind": "kabuki", "src": "sharaku_oniji", "box": (0.08, 0.1, 0.92),
                                "tone": PRINT, "glow": []},
    # ---------------------------------------------------------------------------------------------- damas
    ("mural_bijin_ogi", "R"): {"layout": "tiles", "tiles": [("utamaro_courtesan", (0.04, 0.15, 0.96)),
                                                            ("utamaro_parasol", (0.04, 0.14, 0.96)),
                                                            ("utamaro_konosumi", (0.04, 0.2, 0.96))],
                               "frame": "#ff6fae", "tone": PRINT, "glow": []},
    ("mural_bijin_ogi", "L"): {"layout": "crop", "src": "utamaro_ise", "box": (0.0, 0.03, 1.0, 0.53),
                               "tone": SCENE, "glow": [("disc", 0.72, 0.235, 0.075, "#ff7a3a", 1.0, 1.6, 0.25)]},
    ("mural_bijin_tsuki", "R"): {"layout": "crop", "src": "kuniyoshi_autumn", "box": (0.008, 0.08, 0.992, 0.62),
                                 "tone": SCENE, "glow": [("key", 0.765, 0.085, 0.06, 0.07, "#fff4c8", 2.0, 0.45),
                                                         ("disc", 0.765, 0.085, 0.066, "#fff0c0", 0.45, 2.0)]},
    ("mural_bijin_tsuki", "L"): {"layout": "crop", "src": "utamaro_fireflies", "box": (0.008, 0.04, 0.992, 0.55),
                                 "tone": SCENE, "glow": [("dots", FIREFLIES, 0.006, "#d8ff6a", 1.0)]},
    ("rearpaint_bijin", "R"): {"layout": "rear", "kind": "bijin", "src": "utamaro_hanaogi", "box": (0.06, 0.06, 0.94),
                               "tone": PRINT, "glow": []},
    # ---------------------------------------------------------------------------------------------- guerreiros
    ("mural_musha", "R"): {"layout": "crop", "src": "kunisada_awazu", "box": (0.0, 0.08, 1.0, 0.6),
                           "tone": PRINT, "glow": [("line", [(0.075, 0.0), (0.27, 0.56)], 0.008, "#bfe6ff", 0.9)]},
    ("mural_musha", "L"): {"layout": "crop", "src": "kuniyoshi_shotoku", "box": (0.0, 0.04, 1.0, 0.56),
                           "tone": PRINT, "glow": [("key", x, y, 0.3, 0.12, "#fff4c8", 1.0, 0.62) for x, y in BEAM[1:]] + [("key", 0.85, 0.31, 0.32, 0.06, "#fff4c8", 1.0, 0.62)]},
}

# Nome novo na loja (o id não muda) e obras de cada peça (para a licença no catálogo)
NAMES = {
    "mural_tora_take": "Tigres no bambuzal (biombos Edo)",
    "mural_tora_yuki": "Família de tigres (Kishi Ganku)",
    "mural_kabuki": "Kabuki de Sharaku",
    "mural_musha": "Guerreiros (Kunisada e Kuniyoshi)",
    "mural_bijin_ogi": "Belas de Utamaro",
    "mural_bijin_tsuki": "Damas da noite (lua e vaga-lumes)",
    "rearpaint_tora": "Traseira: tigre (Kishi Ganku)",
    "rearpaint_kabuki": "Traseira: kabuki (Sharaku)",
    "rearpaint_bijin": "Traseira: gueixa (Utamaro)",
}


def pieces() -> list:
    out = []
    for pid, _side in ARTS:
        if pid not in out:
            out.append(pid)
    return out


def sources_of(pid: str) -> list:
    keys = []
    for (q, _s), a in ARTS.items():
        if q != pid:
            continue
        for k in ([a["src"]] if "src" in a else [t[0] for t in a["tiles"]]):
            if k not in keys:
                keys.append(k)
    return keys


def rel_path(pid: str, side: str) -> str:
    """Mesmo arquivo da T-232 (o catálogo não muda de caminho)."""
    if pid.startswith("rearpaint_"):
        return f"rear/{pid}.png"
    return f"mural/{pid}_{side.lower()}.png"
