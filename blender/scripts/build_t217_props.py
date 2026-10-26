"""T-217: route landmarks and people (only READS docs/Modelos; writes reduced .glb into game/assets/scenery/t217/).

Uso: blender -b --factory-startup -P blender/scripts/build_t217_props.py -- [--root PASTA_PRINCIPAL]
         [--only lighthouse,bridge,swimmer,worker] [--out game/assets/scenery/t217] [--preview PASTA_ABS]
  lighthouse : farol branco por codigo (torre conica, galeria, lanterna de vidro acesa a noite, cupula vermelha, casa)
  bridge     : docs/Modelos/Road_pontes/Outra ponte/Bridge.fbx (ponte pensil de 155 m) reduzida para ~9 mil tri,
               pintada de vermelho (cabos e torres) com piso escuro: ponte de pedestres sobre o vale da cachoeira
  swimmer    : docs/Modelos/Homem/anim/anim/Idle.fbx (homem de sunga) parado, pose do quadro 12, ~4 mil tri
  worker     : Homem machucado (OBJ + texturas, extraidos de docs/Modelos/Homem machucado/*.rar para
               blender/renders/t217/src/homem_machucado/) com os bracos abaixados (pose T dobrada no ombro), ~4 mil tri
Origem no chao; frente +Y (Blender) = -Z (Godot). Texturas reduzidas para 512 px e embutidas.
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import mesh3d as M, pbr, preview, scene  # noqa: E402
from lib import traffic_kit as K  # noqa: E402


def _args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.getcwd())
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="game/assets/scenery/t217")
    ap.add_argument("--preview", default="")
    return ap.parse_args(a)


def export(name, objs, out):
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    path = os.path.join(os.path.abspath(out), name + ".glb")
    M.export_glb(path, [root] + objs)
    print(f"OK {name}: {M.count_tris(objs)} tri -> {path}")
    return path


def preview_of(name, objs, outdir):
    if not outdir:
        return
    mn, mx = M.bounds(objs)
    ctr = (mn + mx) / 2
    preview.render_views(os.path.join(outdir, name), objs, size=(640, 480), center=tuple(ctr),
                         views={"34": (30, 16)}, dist=max((mx - mn).length * 1.4, 3.0), lens=50.0)


# ---------------------------------------------------------------- lighthouse (by code)
def lighthouse(args):
    scene.reset_scene()
    m = pbr.standard_set()
    white = pbr.pbr("lh_white", "#eef0ee", roughness=0.6)
    red = pbr.pbr("lh_red", "#b8231e", roughness=0.5)
    dark = pbr.pbr("lh_dark", "#2a2d33", metallic=0.5, roughness=0.4)
    lamp = pbr.emissive("lamp_white", "#fff3d6", 4.0)
    o = [M.cylinder("tower", 2.3, 16.0, (0, 0, 8.0), white, axis="Z", seg=24, radius2=1.55),
         M.cylinder("gallery", 2.3, 0.35, (0, 0, 16.15), white, axis="Z", seg=24),
         M.cylinder("rail", 2.25, 0.9, (0, 0, 16.75), dark, axis="Z", seg=24),
         M.cylinder("lantern", 1.25, 2.2, (0, 0, 17.4), lamp, axis="Z", seg=16),
         M.cylinder("frame", 1.32, 0.2, (0, 0, 18.55), dark, axis="Z", seg=16),
         M.sphere("dome", 1.35, (0, 0, 18.6), red, seg=16, rings=8, scale=(1, 1, 0.7)),
         M.cylinder("vent", 0.25, 0.6, (0, 0, 19.6), dark, axis="Z", seg=10),
         M.box("door", (1.0, 0.2, 2.1), (0, -2.25, 1.05), dark, bevel=0.03, seg=1),
         M.box("house", (6.0, 4.5, 3.2), (0, -5.5, 1.6), white, bevel=0.08),
         M.box("roof", (6.4, 4.9, 0.3), (0, -5.5, 3.3), red, bevel=0.05)]
    for k in range(4):                                     # small windows up the tower
        a = k * math.pi * 0.5 + 0.4
        r = 2.3 - (2.3 - 1.55) * (3.0 + 3.0 * k) / 16.0
        o.append(M.box(f"win{k}", (0.45, 0.12, 0.8), (math.cos(a) * r, math.sin(a) * r, 3.0 + 3.0 * k), dark, bevel=0.02,
                       seg=1, rot=(0, 0, math.degrees(a) + 90)))
    M.apply_transforms(o)
    M.smooth(o, 35.0)
    merged = M.join_by_material(o, prefix="")
    export("lighthouse", merged, args.out)
    preview_of("lighthouse", merged, args.preview)


# ---------------------------------------------------------------- suspension footbridge (docs/Modelos)
def bridge(args):
    scene.reset_scene()
    src = os.path.join(args.root, "docs", "Modelos", "Road_pontes", "Outra ponte", "Bridge.fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=src, use_image_search=False)
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in objs:
        if o.data.users > 1:
            o.data = o.data.copy()
    K.unparent_apply(objs)
    red = pbr.pbr("br_red", "#b3332a", metallic=0.3, roughness=0.45)
    deck = pbr.pbr("br_deck", "#4a4239", roughness=0.85)
    conc = pbr.pbr("br_concrete", "#a9a59b", roughness=0.9)
    for o in [o for o in objs if o.name.startswith("road.001")]:   # 600 k tri of hanger net: rebuilt by code below
        objs.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    for o in objs:
        mat = o.data.materials[0].name.lower() if o.data.materials and o.data.materials[0] else ""
        target = red if "metal" in mat else (deck if "asphalt" in mat else conc)
        o.data.materials.clear()
        o.data.materials.append(target)
        if M.count_tris([o]) > 3000:
            md = o.modifiers.new("planar", "DECIMATE")
            md.decimate_type = "DISSOLVE"
            md.angle_limit = math.radians(4.0)
            K.select_only([o])
            bpy.ops.object.modifier_apply(modifier=md.name)
            tri = o.modifiers.new("tri", "TRIANGULATE")
            bpy.ops.object.modifier_apply(modifier=tri.name)
            K.decimate(o, 6000 if "metal" in mat else 1500)
    lo, hi = M.bounds(objs)
    d = hi - lo
    rot = Matrix.Rotation(math.radians(90), 4, "Z") if d.x > d.y else Matrix.Identity(4)
    K.place(objs, rot)
    lo, hi = M.bounds(objs)
    K.place(objs, Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
    lo, hi = M.bounds(objs)
    objs += _cables(lo, hi, red)
    merged = M.join_by_material(objs, prefix="")
    export("footbridge", merged, args.out)
    lo, hi = M.bounds(merged)
    print(f"   footbridge {hi.x - lo.x:.1f} x {hi.y - lo.y:.1f} x {hi.z - lo.z:.1f} m")
    preview_of("footbridge", merged, args.preview)


def _cables(lo, hi, mat):
    """Main cables (parabola between the tops of the two towers at y = +-L*0.36) and vertical hangers every 4 m."""
    out = []
    L = hi.y - lo.y
    top = hi.z - 0.3
    deck_z = lo.z + (hi.z - lo.z) * 0.12
    ty = L * 0.36
    sag_low = deck_z + 1.2
    for sx in (-1.0, 1.0):
        x = sx * ((hi.x - lo.x) * 0.5 - 0.25)
        pts = []
        for k in range(25):
            y = -ty + 2.0 * ty * k / 24.0
            t = y / ty
            pts.append((x, y, sag_low + (top - sag_low) * t * t))
        out.append(M.tube(f"cable{int(sx)}", pts, 0.09, mat, seg=6))
        for side in (-1.0, 1.0):                       # back stays to the anchors
            out.append(M.tube(f"stay{int(sx)}{int(side)}", [(x, side * ty, top), (x, side * L * 0.49, deck_z + 0.3)], 0.08, mat, seg=6))
        y = -ty + 4.0
        while y < ty - 2.0:
            t = y / ty
            z = sag_low + (top - sag_low) * t * t
            out.append(M.box(f"h{int(sx)}_{int(y)}", (0.04, 0.04, max(z - deck_z, 0.2)), (x, y, (z + deck_z) * 0.5), mat, bevel=0.0, seg=1))
            y += 4.0
    return out


# ---------------------------------------------------------------- people
def _shrink_images(objs, size=512):
    for o in objs:
        for slot in o.material_slots:
            mt = slot.material
            if mt is None or not mt.use_nodes:
                continue
            for n in mt.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    im = n.image
                    if im.size[0] > size:
                        im.scale(size, size)
                    im.pack()


def _keep_basecolor_only(objs):
    """Only the colour texture goes to the game (normal/gloss/specular maps dropped: tiny on screen)."""
    for o in objs:
        for slot in o.material_slots:
            mt = slot.material
            if mt is None or not mt.use_nodes:
                continue
            nt = mt.node_tree
            b = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if b is None:
                continue
            for inp in b.inputs:
                if inp.name != "Base Color":
                    for link in list(inp.links):
                        nt.links.remove(link)
            b.inputs["Roughness"].default_value = 0.7
            b.inputs["Alpha"].default_value = 1.0


def _normalise_person(objs, height):
    lo, hi = M.bounds(objs)
    d = hi - lo
    s = height / d.z
    K.place(objs, Matrix.Scale(s, 4))
    lo, hi = M.bounds(objs)
    K.place(objs, Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))


def swimmer(args):
    scene.reset_scene()
    src = os.path.join(args.root, "docs", "Modelos", "Homem", "anim", "anim", "Idle.fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=src, use_image_search=True)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    if arm is not None and arm.animation_data and arm.animation_data.action:
        bpy.context.scene.frame_set(12)
    meshes = [o for o in new if o.type == "MESH"]
    baked = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
        b = bpy.data.objects.new(o.name + "_pose", me)
        b.matrix_world = o.matrix_world.copy()
        bpy.context.scene.collection.objects.link(b)
        baked.append(b)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    texdir = os.path.join(args.root, "docs", "Modelos", "Homem", "textures", "textures")
    diff = os.path.join(texdir, "FuseModel_Body_Diffuse.png")
    for o in baked:                                         # the FBX points at the author's disk: relink our copy
        for slot in o.material_slots:
            mt = slot.material
            if mt is None:
                continue
            mt.use_nodes = True
            nt = mt.node_tree
            for n in [n for n in nt.nodes if n.type == "TEX_IMAGE"]:
                nt.nodes.remove(n)
            b = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if b is not None and os.path.exists(diff) and "eye" not in mt.name.lower():
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bpy.data.images.load(diff)
                nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    K.unparent_apply(baked)
    _normalise_person(baked, 1.74)
    for o in baked:
        K.decimate(o, 3800 if "Body" in o.name else 300)
    _keep_basecolor_only(baked)
    _shrink_images(baked, 512)
    export("swimmer", baked, args.out)
    preview_of("swimmer", baked, args.preview)


def worker(args):
    scene.reset_scene()
    base = os.path.join(args.root, "blender", "renders", "t217", "src", "homem_machucado")
    bpy.ops.wm.obj_import(filepath=os.path.join(base, "OBJ", "CharacterMesh-VA.obj"))
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    K.unparent_apply(objs)
    _normalise_person(objs, 1.78)
    # bend the T-pose arms down at the shoulders (no rig in the file)
    for o in objs:
        me = o.data
        co = np.zeros(len(me.vertices) * 3, np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        sh_z = 1.78 * 0.815
        torso = np.abs(co[:, 0])[(co[:, 2] > 1.1) & (co[:, 2] < 1.3)]
        sh_x = float(np.percentile(torso, 97)) if torso.size else 0.2
        for side in (-1.0, 1.0):
            sel = ((co[:, 0] * side) > sh_x - 0.02) & (co[:, 2] > sh_z - 0.28)
            w = np.clip(((co[:, 0] * side) - (sh_x - 0.02)) / 0.14, 0.0, 1.0)
            w = w * w * (3 - 2 * w)
            ang = np.radians(78.0) * w
            dx = co[:, 0] - side * sh_x
            dz = co[:, 2] - sh_z
            # rotate (dx, dz) by -ang*side (arm goes down)
            ca, sa = np.cos(-side * ang), np.sin(-side * ang)
            rx = dx * ca - dz * sa
            rz = dx * sa + dz * ca
            co[sel, 0] = (side * sh_x + rx)[sel]
            co[sel, 2] = (sh_z + rz)[sel]
        me.vertices.foreach_set("co", co.ravel())
        me.update()
    texdir = os.path.join(base, "Textures")
    for o in objs:
        for slot in o.material_slots:
            mt = slot.material
            if mt is None:
                continue
            key = "Clothing" if "cloth" in mt.name.lower() else "skin"
            img = os.path.join(texdir, f"TexCharacterVersion-VA_{key}_BaseColor.png")
            mt.use_nodes = True
            nt = mt.node_tree
            b = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if b is not None and os.path.exists(img):
                t = nt.nodes.new("ShaderNodeTexImage")
                t.image = bpy.data.images.load(img)
                nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        K.decimate(o, 4000)
    _keep_basecolor_only(objs)
    _shrink_images(objs, 512)
    export("worker", objs, args.out)
    preview_of("worker", objs, args.preview)


def main():
    args = _args()
    only = set(x for x in args.only.split(",") if x)
    for name, fn in (("lighthouse", lighthouse), ("bridge", bridge), ("swimmer", swimmer), ("worker", worker)):
        if only and name not in only:
            continue
        fn(args)


if __name__ == "__main__":
    main()
