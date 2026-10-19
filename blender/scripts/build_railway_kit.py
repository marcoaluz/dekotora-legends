"""T-154: kit da FERROVIA ao lado da rodovia (so visual).

Feito POR CODIGO (nenhum arquivo de terceiros):
  rail_mast.glb        portico de catenaria japones (2 colunas + viga, bracos e isoladores) para via dupla
  rail_pier.glb        coluna de concreto do viaduto (1 m de altura: o jogo estica) / rail_pier_cap.glb (travessa)
  rail_portal.glb      boca de tunel ferroviario (muro de concreto com arco, fundo escuro)
  train_loco.glb       locomotiva eletrica de carga (vermelha com faixa creme e frente amarela; ficticia)
  train_wagon_a/b/c    vagao plataforma com conteineres de 12 pes (cores lisas, sem marca)
  textures/rail/rail_atlas.png (+ _emit)  atlas 512 de cores (8x8 celulas) dos modelos acima
  textures/rail/rail_bed.png              1024: lastro + dormentes (via dupla), concreto, trilho, fio (repete na pista)

Do Marco (docs/Modelos Melhorados, fora do Git, licenca "SKETCHFAB Standard" = royalty free sem credito obrigatorio):
  train_lrt.glb        bonde CAF Urbos 3 (35 m): 71 mil -> ~7 mil triangulos, SEM o interior, pintura nova amarela
                       (o verde da linha de Kaohsiung vira amarelo) e os logotipos (CAF, Kaohsiung) apagados.
                       Texturas textures/rail/lrt_body.png (1024) e lrt_door.png (512).

Uso: blender -b --factory-startup -P blender/scripts/build_railway_kit.py -- [--lrt-src ARQUIVO.glb] [--no-lrt] [--preview]
Em worktree passe --lrt-src com o caminho absoluto da pasta principal (a pasta docs/Modelos Melhorados fica fora do Git).
Determinístico: mesma entrada -> mesmos arquivos.
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from lib import export as EX  # noqa: E402

OUT_GLB = os.path.join(ROOT, "game", "assets", "scenery", "rail")
OUT_TEX = os.path.join(ROOT, "game", "assets", "textures", "rail")
WORK = os.path.join(ROOT, "blender", "renders", "t154")
LRT_DEFAULT = os.path.join(ROOT, "docs", "Modelos Melhorados", "kaohsiung_circular_light_rail_caf_urbos_3.glb")

# ---------------------------------------------------------------- atlas 512 (8 x 8 celulas de 64 px)
CELL = {
    "steel": 0, "concrete": 1, "dark": 2, "black": 3, "insulator": 4, "loco_red": 5, "loco_cream": 6, "yellow": 7,
    "roof": 8, "glass": 9, "headlight": 10, "taillight": 11, "bogie": 12, "grille": 13, "flatcar": 14,
    "c_blue": 15, "c_green": 16, "c_red": 17, "c_gray": 18, "c_orange": 19, "c_white": 20, "c_teal": 21, "c_brown": 22,
    "c_door": 23, "tunnel": 24, "pier": 25, "truss": 26,
}
COLORS = {   # sRGB
    "steel": (0.62, 0.64, 0.66), "concrete": (0.68, 0.67, 0.63), "dark": (0.13, 0.13, 0.14), "black": (0.04, 0.04, 0.05),
    "insulator": (0.46, 0.27, 0.17), "loco_red": (0.66, 0.15, 0.12), "loco_cream": (0.90, 0.86, 0.74),
    "yellow": (0.97, 0.76, 0.12), "roof": (0.42, 0.43, 0.45), "glass": (0.10, 0.14, 0.19), "headlight": (1.0, 0.98, 0.9),
    "taillight": (0.9, 0.12, 0.08), "bogie": (0.17, 0.16, 0.15), "grille": (0.30, 0.30, 0.32), "flatcar": (0.27, 0.22, 0.19),
    "c_blue": (0.18, 0.33, 0.56), "c_green": (0.21, 0.46, 0.31), "c_red": (0.62, 0.19, 0.16), "c_gray": (0.56, 0.58, 0.59),
    "c_orange": (0.86, 0.46, 0.13), "c_white": (0.86, 0.87, 0.85), "c_teal": (0.16, 0.50, 0.55), "c_brown": (0.46, 0.31, 0.21),
    "c_door": (0.36, 0.37, 0.38), "tunnel": (0.02, 0.02, 0.025), "pier": (0.58, 0.58, 0.56), "truss": (0.5, 0.52, 0.54),
}
EMIT = {"headlight": (1.0, 0.97, 0.85), "taillight": (1.0, 0.1, 0.05), "glass": (0.18, 0.16, 0.12)}
CORRUGATED = {"c_blue", "c_green", "c_red", "c_gray", "c_orange", "c_white", "c_teal", "c_brown"}


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def build_atlas() -> None:
    os.makedirs(OUT_TEX, exist_ok=True)
    img = np.zeros((512, 512, 4), np.float32)
    emit = np.zeros((512, 512, 4), np.float32)
    img[..., 3] = 1.0
    emit[..., 3] = 1.0
    r = rng(154)
    yy, xx = np.mgrid[0:64, 0:64]
    for name, i in CELL.items():
        row, col = divmod(i, 8)
        c = np.array(COLORS[name], np.float32)
        noise = r.normal(0.0, 0.025, (64, 64)).astype(np.float32)
        shade = 1.0 + noise
        if name in CORRUGATED:                              # chapa ondulada: 16 nervuras verticais
            shade *= 1.0 + 0.10 * np.sin(xx / 64.0 * 16.0 * 2.0 * math.pi)
        elif name == "grille":
            shade *= np.where((yy // 4) % 2 == 0, 0.65, 1.15)
        elif name == "truss":
            d = np.minimum(np.abs(xx - yy), np.abs(xx - (63 - yy)))
            shade *= np.where(d < 4, 1.0, 0.55)
        elif name == "c_door":
            shade *= np.where((xx % 16) < 2, 0.6, 1.0)
        elif name == "glass":                               # reflexo claro em diagonal
            shade *= 1.0 + 0.6 * ((xx + yy) % 64 < 10)
        block = np.clip(c[None, None, :] * shade[..., None], 0.0, 1.0)
        img[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64, :3] = block
        if name in EMIT:
            emit[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64, :3] = EMIT[name]
    EX.save_png(img, os.path.join(OUT_TEX, "rail_atlas.png"))
    EX.save_png(emit, os.path.join(OUT_TEX, "rail_atlas_emit.png"))


# ---------------------------------------------------------------- textura da via (repete ao longo da pista)
BED_U_M = 4.8             # metros por repeticao (8 dormentes a cada 0,6 m)
BED_W_M = 11.0            # largura do lastro da via dupla (v 0..BED_V)
BED_V = 0.75
TRACK_SPACING = 4.0       # entre os eixos das duas vias
GAUGE = 1.067             # bitola estreita japonesa


def build_bed() -> None:
    n = 1024
    img = np.zeros((n, n, 4), np.float32)
    img[..., 3] = 1.0
    r = rng(7154)
    v_px = int(BED_V * n)                        # linhas de baixo (UV v=0 embaixo => linha n-1 da imagem)
    # lastro: pedra britada (ruido grosso + fino), marrom-cinza
    g = r.normal(0.0, 1.0, (n // 4, n // 4)).astype(np.float32)
    g = np.kron(g, np.ones((4, 4), np.float32))
    f = r.normal(0.0, 1.0, (n, n)).astype(np.float32)
    ball = 0.40 + 0.06 * g + 0.05 * f
    base = np.stack([ball * 1.02, ball * 0.98, ball * 0.92], -1)
    rows = np.arange(n)[:, None]
    cols = np.arange(n)[None, :]
    v = (n - 1 - rows) / n                          # UV v de cada linha
    u = cols / n
    lat = v / BED_V * BED_W_M                       # metros a partir da borda do lastro
    bed = np.broadcast_to(v < BED_V, (n, n))
    out = np.zeros((n, n, 3), np.float32)
    out[bed] = base[bed]
    for tc in (BED_W_M * 0.5 - TRACK_SPACING * 0.5, BED_W_M * 0.5 + TRACK_SPACING * 0.5):
        sleeper = (np.abs(lat - tc) < 1.0) & ((u * BED_U_M) % 0.6 < 0.2) & bed
        out[sleeper] = (np.array([0.56, 0.55, 0.51]) * (1.0 + 0.04 * f[..., None]))[sleeper]
        for s in (-1.0, 1.0):                      # sujeira de ferrugem embaixo dos trilhos
            rust = (np.abs(lat - (tc + s * GAUGE * 0.5)) < 0.12) & bed
            out[rust] = out[rust] * np.array([0.75, 0.6, 0.5])
    edge = bed & ((lat < 0.6) | (lat > BED_W_M - 0.6))  # bordas do lastro mais escuras (talude)
    out[edge] *= 0.8
    def band(v0: float, v1: float, col, streak: float = 0.0) -> None:
        m = np.broadcast_to((v >= v0) & (v < v1), (n, n))
        c = np.array(col, np.float32)[None, None, :] * (1.0 + 0.03 * f[..., None])
        if streak > 0.0:                            # manchas de chuva escorrida (variam so ao longo de u)
            s = r.normal(0.0, 1.0, n).astype(np.float32)
            s = np.convolve(s, np.ones(9) / 9.0, mode="same")
            c = c * (1.0 + streak * s[None, :, None])
        out[m] = np.broadcast_to(c, (n, n, 3))[m]
    band(0.77, 0.87, (0.47, 0.47, 0.45), 0.15)      # concreto (muro, tabuleiro): cinza medio (o sol clareia)
    band(0.885, 0.90, (0.45, 0.33, 0.25))           # alma do trilho (ferrugem)
    band(0.90, 0.92, (0.80, 0.81, 0.83))            # boleto do trilho (aco polido)
    band(0.94, 0.965, (0.07, 0.07, 0.08))           # fio da catenaria
    band(0.975, 1.0, (0.30, 0.30, 0.31))            # concreto escuro (embaixo do tabuleiro)
    img[..., :3] = np.clip(out, 0.0, 1.0)
    EX.save_png(img, os.path.join(OUT_TEX, "rail_bed.png"))


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_import(png: str) -> None:
    """Comprimida na VRAM (S3TC no PC, ETC2/ASTC no Android) com mipmaps, como T-136/T-146."""
    p = png + ".import"
    if not os.path.isfile(p):
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(IMPORT_TMPL)


# ---------------------------------------------------------------- geometria (bmesh)
def cell_rect(name: str) -> tuple[float, float, float, float]:
    i = CELL[name]
    row, col = divmod(i, 8)
    m = 4.0 / 512.0
    return col / 8.0 + m, 1.0 - (row + 1) / 8.0 + m, (col + 1) / 8.0 - m, 1.0 - row / 8.0 - m


def face(bm, uv, pts, cell: str, flip_u: bool = False):
    """Poligono plano com o UV esticado dentro da celula (eixo u = maior direcao horizontal do poligono)."""
    vs = [bm.verts.new(Vector(p)) for p in pts]
    f = bm.faces.new(vs)
    P = np.array([list(p) for p in pts], np.float64)
    n = np.cross(P[1] - P[0], P[2] - P[0])
    n = n / (np.linalg.norm(n) + 1e-9)
    up = np.array([0.0, 0.0, 1.0])
    ax = np.cross(up, n)
    if np.linalg.norm(ax) < 1e-3:                    # face horizontal: u = Y, v = X
        ax = np.array([0.0, 1.0, 0.0])
    ax = ax / np.linalg.norm(ax)
    ay = np.cross(n, ax)
    pu = P @ ax
    pv = P @ ay
    u0, v0, u1, v1 = cell_rect(cell)
    su = (pu - pu.min()) / max(pu.max() - pu.min(), 1e-6)
    sv = (pv - pv.min()) / max(pv.max() - pv.min(), 1e-6)
    if flip_u:
        su = 1.0 - su
    for lp, a, b in zip(f.loops, su, sv):
        lp[uv].uv = (u0 + a * (u1 - u0), v0 + b * (v1 - v0))
    return f


def box(bm, uv, lo, hi, cell: str, cells: dict | None = None, skip: tuple = ()) -> None:
    """Caixa alinhada aos eixos; `cells` troca a celula por face ('+x','-x','+y','-y','+z','-z')."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    fs = {
        "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        "-x": [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
        "+y": [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
        "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
        "+z": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        "-z": [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)],
    }
    for k, pts in fs.items():
        if k in skip:
            continue
        face(bm, uv, pts, (cells or {}).get(k, cell))


def beam(bm, uv, a, b, w: float, cell: str) -> None:
    """Barra de secao quadrada w x w de a ate b (qualquer direcao)."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    s = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    p = d.cross(s).normalized() * w * 0.5
    q = d.cross(p).normalized() * w * 0.5
    ring = [p + q, -p + q, -p - q, p - q]
    for i in range(4):
        j = (i + 1) % 4
        face(bm, uv, [a + ring[i], a + ring[j], b + ring[j], b + ring[i]], cell)


def new_obj(name: str, mat: str):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    return bm, uv


def finish(name: str, bm, mat: str):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials.get(mat) or bpy.data.materials.new(mat))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ---------------------------------------------------------------- pecas fixas
MAST_HALF = 5.2           # colunas do portico a +-5,2 m do eixo da via dupla (fora do lastro de 11 m)
MAST_TOP = 8.3
WIRE_H = 5.4              # fio de contato acima do trilho


def build_mast():
    bm, uv = new_obj("rail_mast", "rail_kit")
    for sx in (-1.0, 1.0):
        x = sx * MAST_HALF
        box(bm, uv, (x - 0.45, -0.45, -0.4), (x + 0.45, 0.45, 0.25), "concrete")         # sapata
        box(bm, uv, (x - 0.16, -0.16, 0.25), (x + 0.16, 0.16, MAST_TOP), "steel", skip=("-z",))
    box(bm, uv, (-MAST_HALF - 0.3, -0.28, MAST_TOP - 0.7), (MAST_HALF + 0.3, 0.28, MAST_TOP), "truss",
        cells={"+z": "steel", "-z": "steel"})
    for sx in (-1.0, 1.0):                                    # sobre cada via: pendural, isolador e braco
        x = sx * TRACK_SPACING * 0.5
        beam(bm, uv, (x, 0, MAST_TOP - 0.7), (x, 0, WIRE_H + 1.1), 0.08, "steel")
        box(bm, uv, (x - 0.09, -0.09, WIRE_H + 0.75), (x + 0.09, 0.09, WIRE_H + 1.1), "insulator")
        beam(bm, uv, (x, 0, WIRE_H + 0.8), (x + 0.6, 0, WIRE_H + 0.05), 0.06, "steel")
    return [("rail_mast", [finish("rail_mast", bm, "rail_kit")])]


def build_piers():
    bm, uv = new_obj("rail_pier", "rail_kit")
    box(bm, uv, (-1.0, -1.0, 0.0), (1.0, 1.0, 1.0), "pier", skip=("+z", "-z"))
    pier = finish("rail_pier", bm, "rail_kit")
    bm, uv = new_obj("rail_pier_cap", "rail_kit")
    box(bm, uv, (-5.6, -1.1, -1.3), (5.6, 1.1, 0.0), "pier")
    cap = finish("rail_pier_cap", bm, "rail_kit")
    return [("rail_pier", [pier]), ("rail_pier_cap", [cap])]


PORTAL_W = 7.5            # meia largura do muro
PORTAL_H = 10.0
ARCH_W = 4.8              # meia largura do furo
ARCH_SPRING = 5.2
ARCH_TOP = 7.6


def _arch_pts(n: int = 10) -> list:
    pts = [(ARCH_W, 0.0), (ARCH_W, ARCH_SPRING)]
    for i in range(1, n):
        a = math.pi * i / n
        pts.append((ARCH_W * math.cos(a), ARCH_SPRING + (ARCH_TOP - ARCH_SPRING) * math.sin(a)))
    pts += [(-ARCH_W, ARCH_SPRING), (-ARCH_W, 0.0)]
    return pts


def build_portal():
    """Boca do tunel: face virada para -Y (quem chega), o tunel entra em +Y."""
    bm, uv = new_obj("rail_portal", "rail_kit")
    arch = _arch_pts()
    outer = [(PORTAL_W, 0.0), (PORTAL_W, PORTAL_H)] + [(PORTAL_W - (2 * PORTAL_W) * i / (len(arch) - 3), PORTAL_H)
                                                       for i in range(1, len(arch) - 3)] + [(-PORTAL_W, PORTAL_H), (-PORTAL_W, 0.0)]
    # muro: quadrilateros entre o arco e o contorno (mesmo numero de pontos)
    for i in range(len(arch) - 1):
        a0, a1 = arch[i], arch[i + 1]
        o0, o1 = outer[i], outer[i + 1]
        face(bm, uv, [(a0[0], 0, a0[1]), (o0[0], 0, o0[1]), (o1[0], 0, o1[1]), (a1[0], 0, a1[1])], "concrete")
    box(bm, uv, (-PORTAL_W - 0.3, -0.6, PORTAL_H), (PORTAL_W + 0.3, 0.4, PORTAL_H + 0.6), "concrete")   # cornija
    for i in range(len(arch) - 1):                                                                     # revestimento
        a0, a1 = arch[i], arch[i + 1]
        face(bm, uv, [(a1[0], 0, a1[1]), (a1[0], 7.0, a1[1]), (a0[0], 7.0, a0[1]), (a0[0], 0, a0[1])], "pier")
    face(bm, uv, [(ARCH_W, 7.0, 0), (-ARCH_W, 7.0, 0), (-ARCH_W, 7.0, ARCH_TOP), (ARCH_W, 7.0, ARCH_TOP)], "tunnel")
    for sx in (-1.0, 1.0):                                                                            # muros de ala
        x = sx * PORTAL_W
        face(bm, uv, [(x, 0, 0), (x + sx * 5.0, -4.0, 0), (x + sx * 5.0, -4.0, 2.0), (x, 0, PORTAL_H)], "concrete")
    return [("rail_portal", [finish("rail_portal", bm, "rail_kit")])]


# ---------------------------------------------------------------- trem de carga (ficticio)
LOCO_LEN = 18.0
WAGON_LEN = 20.4


def bogie(bm, uv, y: float, half: float = 1.15) -> None:
    box(bm, uv, (-half, y - 1.35, 0.35), (half, y + 1.35, 0.95), "bogie")
    for wy in (y - 0.95, y + 0.95):
        for sx in (-1.0, 1.0):
            box(bm, uv, (sx * 0.62 - 0.07, wy - 0.43, 0.0), (sx * 0.62 + 0.07, wy + 0.43, 0.86), "black")


def build_loco():
    bm, uv = new_obj("train_loco", "rail_train")
    L = LOCO_LEN * 0.5
    box(bm, uv, (-1.35, -L + 0.2, 0.95), (1.35, L - 0.2, 1.35), "dark")                  # estrado
    box(bm, uv, (-1.45, -L + 1.3, 1.35), (1.45, L - 1.3, 3.9), "loco_red", skip=("+y", "-y"))
    box(bm, uv, (-1.3, -L + 0.6, 3.9), (1.3, L - 0.6, 4.1), "roof")
    for s in (1.0, -1.0):                                                                 # cabines nas pontas
        y0, y1 = s * (L - 1.3), s * (L - 0.05)
        prof = [(y0, 1.35), (y1, 1.35), (y1, 2.35), (s * (L - 0.55), 3.55), (y0, 3.9)]
        for sx in (-1.45, 1.45):
            pts = [(sx, py, pz) for py, pz in prof]
            face(bm, uv, pts if (sx > 0) == (s > 0) else pts[::-1], "loco_red")
        face(bm, uv, [(-1.45, y1, 1.35), (1.45, y1, 1.35), (1.45, y1, 2.35), (-1.45, y1, 2.35)], "yellow")
        face(bm, uv, [(-1.45, y1, 2.35), (1.45, y1, 2.35), (1.45, s * (L - 0.55), 3.55), (-1.45, s * (L - 0.55), 3.55)], "glass")
        face(bm, uv, [(-1.45, s * (L - 0.55), 3.55), (1.45, s * (L - 0.55), 3.55), (1.45, y0, 3.9), (-1.45, y0, 3.9)], "loco_red")
        lamp = "headlight" if s > 0 else "taillight"                                       # frente = +Y
        for sx in (-1.0, 1.0):
            yy = y1 + s * 0.02
            face(bm, uv, [(sx * 0.75, yy, 1.7), (sx * 1.15, yy, 1.7), (sx * 1.15, yy, 2.0), (sx * 0.75, yy, 2.0)], lamp)
        box(bm, uv, (-0.25, y1 - 0.1, 3.62), (0.25, y1 + s * 0.08, 3.82), lamp)
        for sx in (-1.0, 1.0):                                                             # janela lateral da cabine
            x = sx * 1.465
            face(bm, uv, [(x, s * (L - 1.2), 2.5), (x, s * (L - 0.7), 2.5), (x, s * (L - 0.7), 3.3), (x, s * (L - 1.2), 3.3)], "glass")
    for sx in (-1.0, 1.0):
        x = sx * 1.47
        face(bm, uv, [(x, -L + 1.3, 2.55), (x, L - 1.3, 2.55), (x, L - 1.3, 2.78), (x, -L + 1.3, 2.78)], "loco_cream")
        face(bm, uv, [(x, -3.6, 2.95), (x, 3.6, 2.95), (x, 3.6, 3.6), (x, -3.6, 3.6)], "grille")
    for py in (-4.6, 4.6):                                                                 # pantografos e caixas
        box(bm, uv, (-0.7, py - 0.5, 4.1), (0.7, py + 0.5, 4.25), "dark")
        beam(bm, uv, (0, py - 0.6, 4.25), (0, py, 5.0), 0.06, "dark")
        beam(bm, uv, (0, py + 0.6, 4.25), (0, py, 5.0), 0.06, "dark")
        box(bm, uv, (-0.85, py - 0.05, 4.98), (0.85, py + 0.05, 5.06), "steel")
    box(bm, uv, (-0.8, -2.2, 4.1), (0.8, 2.2, 4.5), "roof")
    for by in (-L + 4.2, L - 4.2):
        bogie(bm, uv, by)
    return [("train_loco", [finish("train_loco", bm, "rail_train")])]


WAGON_SETS = {   # cores dos 5 conteineres (None = posicao vazia)
    "train_wagon_a": ["c_blue", "c_red", "c_gray", "c_green", "c_orange"],
    "train_wagon_b": ["c_teal", "c_white", "c_brown", "c_blue", "c_gray"],
    "train_wagon_c": ["c_green", "c_orange", None, "c_red", "c_white"],
}


def build_wagons():
    out = []
    L = WAGON_LEN * 0.5
    for name, cols in WAGON_SETS.items():
        bm, uv = new_obj(name, "rail_train")
        box(bm, uv, (-1.3, -L + 0.3, 1.0), (1.3, L - 0.3, 1.25), "flatcar")
        box(bm, uv, (-0.4, -L, 0.95), (0.4, -L + 0.3, 1.2), "dark")
        box(bm, uv, (-0.4, L - 0.3, 0.95), (0.4, L, 1.2), "dark")
        for i, c in enumerate(cols):
            if c is None:
                continue
            yc = -7.9 + i * 3.95
            box(bm, uv, (-1.22, yc - 1.83, 1.25), (1.22, yc + 1.83, 3.75), c, cells={"+y": "c_door", "-y": "c_door"})
        for by in (-L + 2.6, L - 2.6):
            bogie(bm, uv, by, 1.05)
        out.append((name, [finish(name, bm, "rail_train")]))
    return out


# ---------------------------------------------------------------- bonde Urbos (arquivo do Marco)
LRT_KEEP = {"caf_urbos_100_exterior": "lrt_body", "caf_urbos_100_exterior.001": "lrt_body",
            "caf_urbos_100_singledoor_exterior": "lrt_door", "exterior_windows": "lrt_window",
            "exterior_lights.001": "lrt_light"}
LRT_TRIS = 7000
LOGOS = [  # retangulos (fracao u0, v0_topo, u1, v1_topo) do atlas exterior com marca/logo: pintados por cima
    (0.428, 0.606, 0.470, 0.628),   # "caf" na saia lateral
    (0.330, 0.295, 0.392, 0.335),   # simbolo da linha de Kaohsiung
]


def _image_of(mat) -> bpy.types.Image | None:
    if mat is None or mat.node_tree is None:
        return None
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            lk = n.inputs["Base Color"].links
            if lk and lk[0].from_node.type == "TEX_IMAGE":
                return lk[0].from_node.image
    return None


def _pixels(im, size: int) -> np.ndarray:
    im = im.copy()
    im.colorspace_settings.name = "Non-Color"
    if tuple(im.size) != (size, size):
        im.scale(size, size)
    px = np.empty(size * size * 4, np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    return px.reshape(size, size, 4)[::-1].copy()


def recolor(px: np.ndarray, logos: bool) -> np.ndarray:
    """Verde da linha de Kaohsiung -> amarelo (mantendo o sombreado); apaga os logotipos."""
    rgb = px[..., :3]
    g_ex = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
    mask = (g_ex > 0.06) & (rgb[..., 1] > 0.12)
    lum = rgb.max(-1)
    ref = np.median(lum[mask]) if mask.any() else 1.0
    yellow = np.array([0.98, 0.76, 0.10], np.float32)
    rgb[mask] = yellow[None, :] * np.clip(lum[mask] / ref, 0.55, 1.25)[:, None]
    if logos:
        h, w = rgb.shape[:2]
        for u0, v0, u1, v1 in LOGOS:
            y0, y1, x0, x1 = int(v0 * h), int(v1 * h), int(u0 * w), int(u1 * w)
            ring = np.concatenate([rgb[y0 - 2:y0, x0:x1].reshape(-1, 3), rgb[y1:y1 + 2, x0:x1].reshape(-1, 3)])
            rgb[y0:y1, x0:x1] = np.median(ring, 0)
    px[..., :3] = np.clip(rgb, 0.0, 1.0)
    px[..., 3] = 1.0
    return px


def build_lrt(src: str):
    from lib import traffic_kit as TK
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=src)
    new = [o for o in bpy.context.scene.objects if o not in before]
    objs = [o for o in new if o.type == "MESH"]
    empties = [o for o in new if o.type != "MESH"]
    imgs = {}
    for o in objs:
        for m in o.data.materials:
            if m is not None and m.name in LRT_KEEP and LRT_KEEP[m.name] not in imgs:
                im = _image_of(m)
                if im is not None and LRT_KEEP[m.name] in ("lrt_body", "lrt_door"):
                    imgs[LRT_KEEP[m.name]] = im
    keep = []
    for o in objs:
        names = {m.name for m in o.data.materials if m is not None}
        if names and names <= set(LRT_KEEP):
            keep.append(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)          # interior, luz interna, vidro interno
    TK.unparent_apply(keep)
    for o in empties:
        bpy.data.objects.remove(o, do_unlink=True)
    o = TK.join(keep, "train_lrt")
    # materiais finais pelo nome (o jogo cria os materiais: RailKit)
    me = o.data
    final = sorted(set(LRT_KEEP.values()))
    old = [m.name if m else "" for m in me.materials]
    mi = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", mi)
    remap = np.array([final.index(LRT_KEEP.get(n, "lrt_body")) for n in old], np.int32)
    me.materials.clear()
    for n in final:
        me.materials.append(bpy.data.materials.get(n) or bpy.data.materials.new(n))
    me.polygons.foreach_set("material_index", remap[mi])
    me.update()
    TK.weld(o, 1e-4)
    TK.decimate(o, LRT_TRIS, border_weight=1.0)
    o.data.transform(Matrix.Rotation(math.radians(90.0), 4, "Z"))   # comprimento em X -> frente em +Y
    lo = min(v.co.z for v in o.data.vertices)
    o.data.transform(Matrix.Translation((0, 0, -lo)))
    for uvl in [l.name for l in o.data.uv_layers][1:]:
        o.data.uv_layers.remove(o.data.uv_layers[uvl])
    EX.save_png(recolor(_pixels(imgs["lrt_body"], 1024), True), os.path.join(OUT_TEX, "lrt_body.png"))
    EX.save_png(recolor(_pixels(imgs["lrt_door"], 512), False), os.path.join(OUT_TEX, "lrt_door.png"))
    return [("train_lrt", [o])]


# ---------------------------------------------------------------- exportar / conferir
def export(objs: list, name: str) -> str:
    os.makedirs(OUT_GLB, exist_ok=True)
    path = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False,
                              export_image_format="NONE", export_materials="EXPORT")
    return path


def tri_count(objs) -> int:
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


def preview(items: list, path: str) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 480, 320
    sc.world = bpy.data.worlds.get("w") or bpy.data.worlds.new("w")
    tex = {"rail_kit": "rail_atlas.png", "rail_train": "rail_atlas.png", "lrt_body": "lrt_body.png", "lrt_door": "lrt_door.png"}
    for mn, fn in tex.items():
        m = bpy.data.materials.get(mn)
        if m is None:
            continue
        if m.node_tree is None:
            m.use_nodes = True
        nt = m.node_tree
        if not any(n.type == "TEX_IMAGE" for n in nt.nodes):
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = bpy.data.images.load(os.path.join(OUT_TEX, fn))
            bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
            nt.nodes.active = tn
    cam_d = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    every = [o for _, objs in items for o in objs]
    for name, objs in items:
        for o in every:
            o.hide_render = o not in objs
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        ctr, rad = (lo + hi) * 0.5, max((hi - lo).length * 0.5, 0.2)
        d = Vector((1.0, 0.8, 0.45)).normalized()
        cam.location = ctr + d * rad * 2.2
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(WORK, "prev_" + name + ".png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    from lib import preview as PV
    PV.contact_sheet(shots, path, cols=3)


def main() -> None:
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lrt_src = a[a.index("--lrt-src") + 1] if "--lrt-src" in a else LRT_DEFAULT
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(WORK, exist_ok=True)
    build_atlas()
    build_bed()
    items = build_mast() + build_piers() + build_portal() + build_loco() + build_wagons()
    if "--no-lrt" not in a:
        if not os.path.isfile(lrt_src):
            raise SystemExit("ERRO: bonde nao encontrado: %s (use --lrt-src ou --no-lrt)" % lrt_src)
        items += build_lrt(lrt_src)
    for name, objs in items:
        export(objs, name)
        print("RAIL %-16s %6d tri" % (name, tri_count(objs)))
    for fn in os.listdir(OUT_TEX):
        if fn.endswith(".png"):
            write_import(os.path.join(OUT_TEX, fn))
    if "--preview" in a:
        preview(items, os.path.join(WORK, "contact_sheet.png"))
        print("folha:", os.path.join(WORK, "contact_sheet.png"))
    print("OK ferrovia", len(items), "modelos")


main()
