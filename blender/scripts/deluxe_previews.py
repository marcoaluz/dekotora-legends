"""Prévias das peças deluxe (T-172): cada peça de dia, de noite e de perto, numa folha de contato; e o caminhão
com todas as peças deluxe montadas (importa o .glb do caminhão do jogo, que já traz os pontos MOUNT_*).
Chamado por `build_accessories.py -- --deluxe` e `-- --assembled-deluxe`."""
import math
import os

import bpy
from mathutils import Vector

import accessories as ACC
from lib import mesh3d as M, pbr, preview, scene

TRUCK_GLB = "game/assets/vehicles/dekotora/truck/dekotora_truck_base_chata.glb"


def _clean(keep) -> None:
    """Tira luzes, câmera e chão da prévia anterior (render_views cria de novo a cada chamada)."""
    keep = set(keep)
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)


def _build(acc):
    m = pbr.standard_set()
    objs = acc["build"](m)
    M.apply_transforms(objs)
    M.smooth(objs, 35.0)
    return objs


def sheet(out: str, todo) -> str:
    paths = []
    for acc in todo:
        scene.reset_scene()
        objs = _build(acc)
        mn, mx = M.bounds(objs)
        for o in objs:                       # apoia no chão da prévia (peças de lado ficam abaixo do ponto de montagem)
            o.location.z -= mn.z - 0.012     # o brilho no chão fica 1 cm acima do chão da prévia
        bpy.context.view_layer.update()
        mn, mx = M.bounds(objs)
        ctr = (mn + mx) / 2
        size = mx - mn
        rear = "REAR" in acc["mount"]
        az = 205 if rear else (62 if acc["category"] == "sides" else 32)
        dist = max(size.length * 1.6, 1.3)
        base = os.path.join(out, "previews", acc["id"])
        # de perto: a ponta da frente das peças compridas (lado), o centro alto das outras
        if size.y > 2.0:
            det = Vector((ctr.x, mx.y - 0.45, ctr.z))
        else:
            det = Vector((ctr.x + size.x * 0.25, ctr.y, ctr.z + size.z * 0.15))
        det_dist = max(min(size.length * 0.42, 1.4), 0.7)
        for tag, night in (("day", False), ("night", True)):
            preview.render_views(f"{base}_{tag}", objs, size=(640, 480), center=tuple(ctr), views={"34": (az, 18)},
                                 dist=dist, lens=55.0, night=night)
            paths.append(f"{base}_{tag}_34.png")
            _clean(objs)
        preview.render_views(f"{base}_detail", objs, size=(640, 480), center=tuple(det),
                             views={"34": (az + 18, 12, det_dist, tuple(det))}, lens=55.0, night=True)
        paths.append(f"{base}_detail_34.png")
        _clean(objs)
        print("[deluxe] prévias:", acc["id"])
    path = os.path.join(out, "previews", "deluxe_contact_sheet.png")
    preview.contact_sheet(paths, path, cols=3)
    print("[deluxe] folha de contato:", path)
    return path


def _import_truck():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(TRUCK_GLB))
    new = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    mounts = {o.name.split(".")[0]: o.matrix_world.translation.copy() for o in new if o.name.startswith("MOUNT_")}
    meshes = [o for o in new if o.type == "MESH"]
    return meshes, mounts, new


def assembled(out: str, out_dir: str) -> None:
    """Caminhão padrão (baú médio + cabine chata) com as 6 peças deluxe: frente 3/4, traseira 3/4 e lado, dia e noite."""
    os.makedirs(out_dir, exist_ok=True)
    scene.reset_scene()
    truck, mounts, new = _import_truck()
    objs = list(truck)
    m = pbr.standard_set()
    for acc in [ACC.BY_ID[i] for i in ACC.DELUXE]:
        for side in ((1, -1) if acc["mirror"] else (1,)):
            parts = acc["build"](m)
            M.apply_transforms(parts)
            if side == -1:
                M.mirror_x(parts)
            name = acc["mount"][:-1] + ("L" if side == -1 else "R") if acc["mirror"] else acc["mount"]
            for o in parts:
                o.location = mounts[name]
            objs += parts
    M.smooth([o for o in objs if o not in truck], 35.0)
    keep = list(new) + objs
    views = {"front34": (32, 12, 15.0, (0.0, 7.5, 2.0)), "rear34": (205, 12, 13.0, (0.0, 2.0, 1.8)),
             "side": (80, 5, 17.0, (0.0, 5.5, 1.5)), "roof": (20, 22, 7.0, (0.0, 10.2, 3.6))}
    paths = []
    for tag, night in (("day", False), ("night", True)):
        preview.render_views(os.path.join(out_dir, f"assembled_deluxe_{tag}"), objs, size=(960, 540), views=views, night=night)
        paths += [os.path.join(out_dir, f"assembled_deluxe_{tag}_{v}.png") for v in views]
        _clean(keep)
    preview.contact_sheet(paths, os.path.join(out_dir, "assembled_deluxe_sheet.png"), cols=4)
    print("[deluxe] montado:", out_dir)
