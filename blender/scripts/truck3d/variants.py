"""Variantes de baú feitas a partir do caminhão padrão (cabine e peças iguais; só muda o comprimento do meio).

`stretch` empurra para frente (delta > 0) ou puxa para trás (delta < 0) tudo que está na frente do trecho de corte
[a, b]: objetos compridos (baú, longarinas, tubos) são esticados/comprimidos; objetos pequenos (tanques, rodas,
bateria, empties de montagem) são movidos inteiros. Depois cada variante acrescenta eixos e detalhes próprios.

| id      | descrição                                                             | delta  |
| base    | baú padrão 8,2 m, 2 eixos traseiros                                   |  0,0   |
| leve    | baú curto 5,4 m, 1 eixo traseiro (ágil, estilo caminhão médio)       | -2,8   |
| longo   | baú longo 9,8 m, 3 eixos traseiros                                    | +1,6   |
| carreta | cavalo + semirreboque 13,2 m (tridem + 2 eixos de tração), ~17 m      | +5,5   |
"""
import bpy

from lib import mesh3d as M

from .chassis import rear_axle
from .dims import BODY_W, MOUNTS, WHEEL_R
from .wheels import make_wheel

VARIANTS = {
    "base": dict(delta=0.0, cut=(3.8, 5.0), rear_axles=(1.5, 3.0), tanks=True, seg=36),
    "leve": dict(delta=-2.8, cut=(3.8, 6.6), rear_axles=(1.5,), tanks=True, seg=36),
    "longo": dict(delta=1.6, cut=(3.8, 5.0), rear_axles=(1.5, 3.0), tanks=True, seg=36),
    "carreta": dict(delta=5.0, cut=(3.8, 5.0), rear_axles=(1.5, 3.0), tanks=False, seg=24),
}
LENGTH_DELTA = {k: v["delta"] for k, v in VARIANTS.items()}
LENGTH_DELTA["carreta"] += 0.5          # + vão entre o cavalo e o semirreboque
LONG_OBJECT = 2.6        # objetos mais compridos que isto (m) são deformados; os menores andam inteiros
DROP = {"leve": ("post_1_2", "post_-1_2", "post_latch_1_2", "post_latch_-1_2", "side_marker_1_5.8", "side_marker_-1_5.8")}


def _bbox_y(o):
    ys = [v.co.y for v in o.data.vertices]
    return min(ys), max(ys)


def stretch(parts, wheels, empties, cut, delta):
    """Aplica a deformação em Y; devolve as peças que sobraram."""
    a, b = cut
    mid = (a + b) / 2
    k = (b - a + delta) / (b - a)

    def f(y):
        return y if y <= a else (y + delta if y >= b else a + (y - a) * k)

    for o in parts:
        M.apply_transforms([o])
        lo, hi = _bbox_y(o)
        if hi - lo > LONG_OBJECT:
            for v in o.data.vertices:
                v.co.y = f(v.co.y)
        elif (lo + hi) / 2 >= mid:
            for v in o.data.vertices:
                v.co.y += delta
        o.data.update()
    for ws in wheels:
        if ws[0].location.y >= mid:
            for o in ws:
                o.location.y += delta
    for e in empties:
        if e.location.y >= mid:
            e.location.y += delta


def _wheel_pair(m, add_wheel, y, seg):
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for tx in (0.72, 1.06):
            add_wheel(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, WHEEL_R), m, rim=(tx > 1.0), seg=seg))


def _posts(m, add, ys, z=2.15):
    for y in ys:
        for sx in (-1, 1):
            add(M.box(f"post_x_{sx}_{y}", (0.07, 0.1, 2.0), (sx * 1.28, y, z), m["steel"], bevel=0.015, seg=1))
            add(M.box(f"post_latch_x_{sx}_{y}", (0.05, 0.07, 0.16), (sx * 1.31, y, 1.35), m["chrome"], bevel=0.015, seg=1))


def _markers(m, add, ys):
    for y in ys:
        for sx in (-1, 1):
            add(M.box(f"side_marker_x_{sx}_{y}", (0.04, 0.16, 0.07), (sx * 1.275, y, 1.18), m["lamp_amber"], bevel=0.015, seg=1))


def apply_variant(kind, m, parts, wheels, empties):
    """Deforma o caminhão padrão e acrescenta o que a variante precisa. Devolve o dicionário de montagens atualizado."""
    spec = VARIANTS[kind]
    delta = spec["delta"]
    add = parts.append
    add_wheel = wheels.append
    mounts = dict(MOUNTS)
    if delta != 0.0:
        stretch(parts, wheels, empties, spec["cut"], delta)
        mid = sum(spec["cut"]) / 2
        mounts = {n: ((x, y + delta, z) if y >= mid else (x, y, z)) for n, (x, y, z) in MOUNTS.items()}
    if kind == "carreta":                           # abre um vão entre o cavalo e o semirreboque
        gap_a, gap_b, gap = 13.25, 13.3, 0.5
        stretch(parts, wheels, empties, (gap_a, gap_b), gap)
        mounts = {n: ((x, y + gap, z) if y >= (gap_a + gap_b) / 2 else (x, y, z)) for n, (x, y, z) in mounts.items()}
    for o in [o for o in parts if o.name in DROP.get(kind, ())]:
        parts.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    body_l = 8.2 + delta
    for e in empties:                               # teto do baú fica no meio do baú novo
        if e.name == "MOUNT_BODY_ROOF":
            e.location.y = body_l / 2
            mounts["MOUNT_BODY_ROOF"] = (0.0, body_l / 2, mounts["MOUNT_BODY_ROOF"][2])
    if kind == "longo":
        rear_axle(m, add, 4.5)
        _wheel_pair(m, add_wheel, 4.5, spec["seg"])
        _posts(m, add, (4.6, 9.4))
        _markers(m, add, (6.1, 8.8))
    elif kind == "carreta":
        rear_axle(m, add, 4.5)                      # tridem do semirreboque
        _wheel_pair(m, add_wheel, 4.5, spec["seg"])
        for y in (10.6, 11.9):                      # eixos de tração do cavalo
            rear_axle(m, add, y)
            _wheel_pair(m, add_wheel, y, 36)
        _posts(m, add, (4.8, 7.2, 9.6, 12.0))
        _markers(m, add, (6.0, 8.4, 10.8, 12.6))
        # saias laterais do semirreboque, mangueiras de ar e quinta roda entre o cavalo e o baú
        for sx in (-1, 1):
            add(M.box(f"trailer_skirt_{sx}", (0.04, 4.6, 0.3), (sx * 1.1, 7.5, 0.95), m["plastic"], bevel=0.01, seg=1))
        add(M.tube("air_hose_red", [(-0.25, 13.2, 2.3), (-0.3, 13.55, 2.85), (-0.4, 13.9, 2.3)], 0.025, m["lamp_red"], seg=8))
        add(M.tube("air_hose_blue", [(0.25, 13.2, 2.3), (0.3, 13.55, 2.85), (0.4, 13.9, 2.3)], 0.025, m["paint_blue"], seg=8))
        add(M.cylinder("fifth_wheel", 0.55, 0.06, (0, 11.3, 1.0), m["steel"], axis="Z", seg=24))
        add(M.box("coupling_beam", (0.5, 0.75, 0.2), (0, 13.58, 1.25), m["steel"], bevel=0.03))     # quinta roda / suporte do engate
        add(M.box("trailer_front_trim", (BODY_W, 0.05, 0.1), (0, 13.22, 3.15), m["chrome"], bevel=0.015, seg=1))
    return mounts
