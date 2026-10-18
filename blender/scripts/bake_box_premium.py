"""Baú premium (T-136): grava os mapas da versão ALTA (só no Blender) na versão LEVE (a que vai para o jogo).

Uso: blender -b --factory-startup -P blender/scripts/bake_box_premium.py -- [--out game/assets/vehicles/dekotora/textures]
     [--size 1024] [--samples 8] [--ao-samples 48] [--sheet blender/renders/t136]
Saída (compartilhada por todos os caminhões, ver lib/shared_tex.py e TruckTextures no jogo):
  tex_box_albedo.png  cor (sRGB) do atlas do baú: pintura branca com desgaste/lascas/poeira e alumínio
  tex_box_orm.png     R = oclusão, G = rugosidade, B = metálico (atlas)
  tex_box_nrm.png     normais (espaço tangente, OpenGL = convenção do Godot) do atlas
  tex_box_mural_orm.png / tex_box_mural_nrm.png   mesmos mapas na área do mural (a COR do mural é o PNG trocável)
Mais a folha de conferência <sheet>/box_premium_maps.png (os 5 mapas lado a lado).

Fluxo: alta (box_high: nervuras arredondadas, juntas, rebites, portas estampadas, borracha) com materiais PBR CC0
(lib/cc0_mats) -> passes do Cycles (normal, oclusão, cor, rugosidade, metálico) -> numpy -> PNG. As ferragens
(box_rear: dobradiças, barras, escada, lanternas) entram só como sombra na oclusão. Determinístico (semente fixa).
Leva ~3-4 min na CPU do PC do Marco.
"""
import argparse
import os
import sys
import time

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import bake, cc0_mats, pbr, preview, scene  # noqa: E402
from lib import mesh3d as M  # noqa: E402
from lib.meshbuild import mirror_x  # noqa: E402
from truck3d import box_high, box_layout as BL, box_premium as BP, box_rear  # noqa: E402
from truck3d.body import STD  # noqa: E402

AO_IN_ALBEDO = 0.45      # parte da oclusão multiplicada na cor (o Compatibility só usa a AO na luz ambiente)


def _placeholders() -> dict:
    m = pbr.standard_set()
    m["paint_white_box"] = pbr.pbr("paint_white_box", "#eef1f4")
    m["box_metal"] = pbr.pbr("box_metal", "#b8bec6", metallic=1.0, roughness=0.35)
    m["mural"] = pbr.pbr("mural", "#ffffff")
    return m


def _blur(a: np.ndarray, r: int = 1) -> np.ndarray:
    """Caixa (2r+1)^2 com borda repetida: tira o grão da oclusão sem apagar as frestas."""
    p = np.pad(a, ((r, r), (r, r)), mode="edge")
    out = np.zeros_like(a)
    for dy in range(2 * r + 1):
        for dx in range(2 * r + 1):
            out += p[dy:dy + a.shape[0], dx:dx + a.shape[1]]
    return out / (2 * r + 1) ** 2


def _bake_target(name, target, sources, size, args):
    """Os 5 passes de um alvo. Devolve dicionário de arrays (h, w) / (h, w, 3), linha 0 embaixo."""
    w, h = size
    out = {}
    t0 = time.time()
    img = bake.new_image(f"{name}_nrm", w, h, (0.5, 0.5, 1.0, 1.0))
    bake.bake_pass("NORMAL", sources, target, img, samples=args.samples)
    out["nrm"] = bake.pixels(img)[..., :3].copy()
    img = bake.new_image(f"{name}_ao", w, h, (1, 1, 1, 1))
    bake.bake_pass("AO", sources, target, img, samples=args.ao_samples)
    out["ao"] = _blur(bake.pixels(img)[..., 0].copy())
    cc0_mats.emit_pass("color")                       # cor base pela emissão (DIFFUSE zera a cor do metal)
    img = bake.new_image(f"{name}_col", w, h, (0.8, 0.8, 0.8, 1))
    bake.bake_pass("EMIT", sources, target, img, samples=args.samples)
    cc0_mats.emit_pass(None)
    out["col"] = bake.pixels(img)[..., :3].copy()
    img = bake.new_image(f"{name}_rough", w, h, (0.5, 0.5, 0.5, 1))
    bake.bake_pass("ROUGHNESS", sources, target, img, samples=args.samples)
    out["rough"] = bake.pixels(img)[..., 0].copy()
    cc0_mats.emit_pass("metal")
    img = bake.new_image(f"{name}_metal", w, h, (0, 0, 0, 1))
    bake.bake_pass("EMIT", sources, target, img, samples=args.samples)
    cc0_mats.emit_pass(None)
    out["metal"] = bake.pixels(img)[..., 0].copy()
    print(f"  {name}: {w}x{h} em {time.time() - t0:.0f} s")
    return out


def _flat_caps(d: dict, size: int) -> None:
    """As tampas de todas as extrusões dividem o mesmo retângulo (R_CAPS): lá o bake se sobrepõe. Preenche com
    normal reta e os valores médios do metal (as tampas têm poucos centímetros)."""
    r = BL.R_CAPS
    rs = slice(int(r.v0 * size), int((r.v0 + r.h) * size))
    cs = slice(int(r.u0 * size), int((r.u0 + r.w) * size))
    mr = BL.R_RAIL_LO
    ref = (slice(int(mr.v0 * size) + 4, int((mr.v0 + mr.h) * size) - 4), slice(8, size - 8))
    d["nrm"][rs, cs] = (0.5, 0.5, 1.0)
    for k in ("col", "ao", "rough", "metal"):
        d[k][rs, cs] = np.median(d[k][ref].reshape(-1, *d[k].shape[2:]), axis=0)


def _orm(d) -> np.ndarray:
    return np.stack([d["ao"], d["rough"], d["metal"]], axis=2)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="game/assets/vehicles/dekotora/textures")
    ap.add_argument("--size", type=int, default=BL.ATLAS)
    ap.add_argument("--samples", type=int, default=8)
    ap.add_argument("--ao-samples", type=int, default=48)
    ap.add_argument("--sheet", default="blender/renders/t136")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    t0 = time.time()
    scene.reset_scene()
    bake.setup(samples=args.samples, ao_distance=0.25)
    m = _placeholders()
    lay = BL.Layout(STD)
    low = BP.build_low_parts(m, STD)
    atlas_objs = [o for o, t in low if t == "atlas"]
    mural_objs = [o for o, t in low if t == "mural"]
    hm = {"paint": cc0_mats.paint(z0=STD.z0), "metal": cc0_mats.metal(z0=STD.z0), "rubber": cc0_mats.rubber(z0=STD.z0)}
    high = box_high.build_high(lay, hm)
    for o in list(high):                                   # lado esquerdo das peças de metal: borda do teto simétrica
        if o.name == "hi_metal_R":
            mo = mirror_x(o, "hi_metal_L")
            M.uv_world(mo, 1.0)
            high.append(mo)
    bpy.ops.object.select_all(action="DESELECT")           # uma fonte só: o Blender procura pixel a pixel em
    for o in high:                                         # cada objeto selecionado, sem threads (bem mais lento)
        o.select_set(True)
    bpy.context.view_layer.objects.active = high[0]
    bpy.ops.object.join()
    high = [bpy.context.view_layer.objects.active]
    hw = []
    box_rear.build_hardware(m, hw.append, STD)             # só fazem sombra (não são selecionadas)
    M.apply_transforms(hw)
    t_atlas = bake.target_copy(atlas_objs, "bake_atlas")
    t_mural = bake.target_copy(mural_objs, "bake_mural")
    for o, _t in low:                                      # a malha leve não pode tapar a alta
        bpy.data.objects.remove(o, do_unlink=True)
    print(f"alta: {M.count_tris(high)} triangulos; leve (alvos): {M.count_tris([t_atlas, t_mural])}")
    a = _bake_target("box", t_atlas, high, (args.size, args.size), args)
    _flat_caps(a, args.size)
    mw, mh = BL.MURAL_SIZE
    mu = _bake_target("box_mural", t_mural, high, (mw * args.size // BL.ATLAS, mh * args.size // BL.ATLAS), args)
    col = bake.linear_to_srgb(a["col"] * (1.0 - AO_IN_ALBEDO + AO_IN_ALBEDO * a["ao"])[..., None])
    files = {
        "tex_box_albedo": col,
        "tex_box_orm": _orm(a),
        "tex_box_nrm": a["nrm"],
        "tex_box_mural_orm": _orm(mu),
        "tex_box_mural_nrm": mu["nrm"],
    }
    for k, arr in files.items():
        bake.save_png(arr, os.path.join(out, k + ".png"))
    sheet_dir = os.path.abspath(args.sheet)
    os.makedirs(sheet_dir, exist_ok=True)
    tiles = []
    for k in ("tex_box_albedo", "tex_box_orm", "tex_box_nrm"):
        tiles.append(os.path.join(out, k + ".png"))
    for k in ("tex_box_mural_orm", "tex_box_mural_nrm"):     # mural (4:1) dentro de um quadro do mesmo tamanho
        arr = files[k]
        sq = np.zeros((args.size, args.size, 3), np.float32) + 0.05
        sq[:arr.shape[0], :arr.shape[1]] = arr
        p = os.path.join(sheet_dir, k + "_sq.png")
        bake.save_png(sq, p)
        tiles.append(p)
    preview.contact_sheet(tiles, os.path.join(sheet_dir, "box_premium_maps.png"), cols=3)
    print(f"OK bake_box_premium -> {out} ({time.time() - t0:.0f} s)")


if __name__ == "__main__":
    main()
