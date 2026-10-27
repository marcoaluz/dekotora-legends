"""Cabine trocável (T-240): cabines e carrocerias em .glb SEPARADOS, montados pelo jogo (TruckKit).

Antes (T-218) cada caminhão de homenagem era um .glb com a cabine fixa. Agora:
  <out>/truck/kit/cab_<cabine>.glb   cabine + eixo dianteiro + rodas da frente + "sobrancelha" de luzes + pontos MOUNT_*
                                     da frente (para-choque, grade, viseira, teto, degraus, rodas da frente)
  <out>/truck/kit/body_<modelo>.glb  chassi (sem o eixo dianteiro) + carroceria + decoração + rodas de trás + pontos
                                     MOUNT_* da carroceria
  <out>/truck/kit/lod/<nome>_lod1.glb e _lod2.glb (as mesmas regras de LOD da T-218)
O jogo junta cabine + carroceria em tempo de execução (um material = uma malha, como no .glb único): nenhum .glb por
combinação. Cabines: as 4 de arquivo (chata, jac, curta, americana; mesmas funções do build_truck_3d.py) e as 2 da
T-218 (flat_wide, flat_quad). Carrocerias: as 5 de homenagem (mesmas funções do build_t218_trucks.py) e, com
--old-bodies, base/leve/longo/graneleira no layout da cabine chata (para as cabines novas nos baús antigos).

Uso (na raiz do projeto):
  blender -b --factory-startup -P blender/scripts/build_t240_kits.py -- [--cabs a,b] [--bodies a,b] [--out PASTA]
Determinístico (mesma entrada, mesmos arquivos).
"""
import argparse
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, scene  # noqa: E402
import build_t218_trucks as T  # noqa: E402  (main() só roda como script)
import build_truck_3d as BT  # noqa: E402
from truck3d import t218_bodies as B, t218_cab as C  # noqa: E402
from truck3d.chassis import build_chassis  # noqa: E402
from truck3d.deco import build_deco, cab_brow  # noqa: E402
from truck3d.dims import CAB_Y1, FRONT_AXLE_Y, MOUNTS  # noqa: E402
from truck3d.wheels import make_wheel  # noqa: E402

CABS = ("chata", "jac", "curta", "americana", "flat_wide", "flat_quad")
FLAT = {"flat_wide": "wide", "flat_quad": "quad"}
BODIES = ("alubox", "tarp", "pinkbox", "tanker", "dump")
OLD_BODIES = ("base", "leve", "longo", "graneleira")
CAB_MOUNTS = ("MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_FRONT_ORNAMENT", "MOUNT_VISOR", "MOUNT_ROOF",
              "MOUNT_ROOF_LIGHTS", "MOUNT_STEP_", "MOUNT_CAB_SIDE_", "MOUNT_WHEEL_FRONT_")


def is_cab_mount(name: str) -> bool:
    return any(name == p or (p.endswith("_") and name.startswith(p)) for p in CAB_MOUNTS)


def _front_axle(m, add, dy):
    """Só o eixo dianteiro do chassi (o resto do chassi é da carroceria)."""
    tmp = []

    def keep(o):
        tmp.append(o)
        return o
    build_chassis(m, keep, T.REAR_AXLES, tanks=True)
    for o in tmp:
        if o.name.startswith(BT.FRONT_AXLE_PARTS):
            o.location.y += dy
            add(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)


def build_cab_kit(cab, m, src=None):
    parts = []

    def add(o):
        parts.append(o)
        return o
    if cab in FLAT:
        info = C.build_cab(m, add, FLAT[cab])
        cab_front = (C.yf(info.wz0), info.wz0, info.surf)
    else:
        info = BT.build_file_cab(m, add, cab, src)
        cab_front = (CAB_Y1, info.wz0, info.surf)
    _front_axle(m, add, info.front_axle - FRONT_AXLE_Y)
    cab_brow(m, add, cab_front)
    wheels = []
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        wheels.append(make_wheel(f"wheel_f_{side}", (sx * 1.0, info.front_axle, info.front_r), m, rim=True, radius=info.front_r))
    mounts = {n: p for n, p in MOUNTS.items() if is_cab_mount(n)}
    mounts.update({n: p for n, p in info.mounts.items() if is_cab_mount(n)})
    BT._front_wheel_mounts(mounts, info)
    empties = [M.empty(n, p) for n, p in sorted(mounts.items())]
    print(f"[t240] cabine {cab}: {info.tris} triangulos; costas y={info.y_back if hasattr(info, 'y_back') else '?'}"
          f" eixo y={info.front_axle:.2f} r={info.front_r}")
    return parts, wheels, empties


def build_body_kit(body, m, out_dir):
    """Carroceria de homenagem: igual ao build() da T-218, sem a cabine, o eixo dianteiro e a sobrancelha."""
    parts = []

    def add(o):
        parts.append(o)
        return o
    build_chassis(m, add, T.REAR_AXLES, tanks=True)
    for o in [o for o in parts if o.name.startswith(BT.FRONT_AXLE_PARTS)]:
        parts.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    info = B.build_pinkbox(m, add, T.mural_material(body, out_dir)) if body == "pinkbox" else B.BUILDERS[body](m, add)
    if info.get("drop_stacks"):
        for o in [o for o in parts if o.name.startswith("stack_")]:
            parts.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    if info.get("stack_guards"):
        B.stack_guards(m, add)
    if info["deco"] == "full":                          # andon da frente na altura de sempre (cabine HAYATE)
        build_deco(m, add, B.L, C.ROOF + 0.02, None, box=info["box"], mural_plates=False)
    wheels = []
    for sx in (-1, 1):
        side = "L" if sx < 0 else "R"
        for y in T.REAR_AXLES:
            for tx in (0.72, 1.06):
                wheels.append(make_wheel(f"wheel_r_{side}_{y}_{tx}", (sx * tx, y, T.WHEEL_R), m, rim=(tx > 1.0), seg=36))
    mounts = {n: p for n, p in MOUNTS.items() if not is_cab_mount(n)}
    mounts.update({n: p for n, p in info["mounts"].items() if not is_cab_mount(n)})
    empties = [M.empty(n, p) for n, p in sorted(mounts.items())]
    print(f"[t240] carroceria {body}: carga ate {info['top']:.2f} m")
    return parts, wheels, empties


def build_old_body_kit(body, m, body_src=None):
    """Baú antigo no layout da cabine chata (baú até 8,2 m, escapamentos em 8,3), sem a cabine chata."""
    cab_names = set()
    real = BT.build_file_cab

    def spy(mm, add, cab, src=None):
        n0 = len(bpy.data.objects)
        before = set(bpy.data.objects)
        info = real(mm, add, cab, src)
        cab_names.update(o.name for o in bpy.data.objects if o not in before)
        del n0
        return info
    BT.build_file_cab = spy
    try:
        premium = BT.use_premium("auto", body)
        parts, wheels, empties = BT.build_truck(m, "paint_white", body, "chata", None, premium, body_src)
    finally:
        BT.build_file_cab = real
    drop = [o for o in parts if o.name in cab_names or o.name.startswith(BT.FRONT_AXLE_PARTS) or o.name.startswith("mk_cab_")]
    for o in drop:
        parts.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    keep_w = []
    for ws in wheels:
        if ws[0].name.startswith("wheel_f_"):
            for o in ws:
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep_w.append(ws)
    keep_e = []
    for e in empties:
        if is_cab_mount(e.name):
            bpy.data.objects.remove(e, do_unlink=True)
        else:
            keep_e.append(e)
    print(f"[t240] carroceria antiga {body}: {len(drop)} objetos da cabine retirados")
    return parts, keep_w, keep_e


def export_kit(name, parts, wheels, empties, out_dir, root_name, lod=True):
    """`lod=False`: sem LOD1/LOD2 (baús antigos: só o caminhão do jogador usa, sempre perto da câmera)."""
    T._uv(parts)
    lods = {level: T._clone(T._lod_pick(parts, wheels, level)) for level in (1, 2)} if lod else {}
    all_meshes = parts + [w for ws in wheels for w in ws]
    M.smooth(all_meshes, 35.0)
    tris0 = M.count_tris(all_meshes)
    merged = M.join_by_material(parts, prefix="truck_")
    wheel_objs = T._join_wheels(wheels) if wheels else []
    kit = os.path.join(out_dir, "truck", "kit")
    os.makedirs(os.path.join(kit, "lod"), exist_ok=True)
    path = os.path.join(kit, name + ".glb")
    T._export(path, merged + wheel_objs + empties, root_name, out_dir)
    rep = [tris0]
    if not lod:
        print(f"[t240] {name}: triangulos {rep} bytes {[os.path.getsize(path)]} (sem LOD)")
        return
    for level in (1, 2):
        joined = M.join_by_material(lods[level], prefix=f"lod{level}_")
        ratio = (T.LOD1_RATIO if level == 1 else T.LOD2_RATIO) * tris0 / max(1, M.count_tris(joined))
        if ratio < 1.0:
            for o in joined:
                T._reduce(o, ratio)
        for o in joined:
            T._sharp_by_angle(o, 0.61)
        rep.append(M.count_tris(joined))
        T._export(os.path.join(kit, "lod", f"{name}_lod{level}.glb"), joined, f"LOD{level}", out_dir)
    sizes = [os.path.getsize(path)] + [os.path.getsize(os.path.join(kit, "lod", f"{name}_lod{k}.glb")) for k in (1, 2)]
    print(f"[t240] {name}: triangulos {rep} bytes {sizes}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--cabs", default=",".join(CABS))
    ap.add_argument("--bodies", default=",".join(BODIES))
    ap.add_argument("--out", default="game/assets/vehicles/dekotora")
    ap.add_argument("--body-src", default=None, help="graneleira: Carroceria_Brasil_Graneleiro.obj")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    for cab in [s for s in args.cabs.split(",") if s]:
        if cab not in CABS:
            raise SystemExit(f"ERRO: cabine desconhecida: {cab}")
        scene.reset_scene()
        m = T.materials(out_dir)
        export_kit(f"cab_{cab}", *build_cab_kit(cab, m), out_dir, "CabKit")
    for body in [s for s in args.bodies.split(",") if s]:
        scene.reset_scene()
        m = T.materials(out_dir)
        if body in BODIES:
            kit = build_body_kit(body, m, out_dir)
        elif body in OLD_BODIES:
            if BT.use_premium("auto", body):
                from lib import pbr
                pbr.box_premium_set(m, os.path.join(out_dir, "textures"))
            kit = build_old_body_kit(body, m, args.body_src)
        else:
            raise SystemExit(f"ERRO: carroceria desconhecida: {body}")
        export_kit(f"body_{body}", *kit, out_dir, "DekotoraTruckBase", lod=body in BODIES)
    print("OK build_t240_kits")


main()
