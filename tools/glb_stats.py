"""Mede arquivos .glb sem Blender: triângulos, materiais, imagens (bytes) e tamanho total.

Uso: python tools/glb_stats.py game/assets/vehicles/dekotora/truck/*.glb
Só usa a biblioteca padrão do Python.
"""
import json
import os
import struct
import sys


def stats(path: str) -> dict:
    with open(path, "rb") as f:
        data = f.read()
    _magic, _ver, _length = struct.unpack_from("<III", data, 0)
    clen, _ctype = struct.unpack_from("<II", data, 12)
    gj = json.loads(data[20:20 + clen].decode("utf-8"))
    acc = gj.get("accessors", [])
    tris = 0
    for mesh in gj.get("meshes", []):
        for p in mesh.get("primitives", []):
            if "indices" in p:
                tris += acc[p["indices"]]["count"] // 3
            else:
                tris += acc[p["attributes"]["POSITION"]]["count"] // 3
    views = gj.get("bufferViews", [])
    img_bytes = 0
    imgs = []
    for im in gj.get("images", []):
        if "bufferView" in im:
            n = views[im["bufferView"]]["byteLength"]
            img_bytes += n
            imgs.append((im.get("name", "?"), n))
    return {"tris": tris, "materials": len(gj.get("materials", [])), "images": imgs,
            "img_bytes": img_bytes, "file_bytes": os.path.getsize(path)}


def main() -> None:
    tot_t = tot_i = tot_f = 0
    for p in sys.argv[1:]:
        s = stats(p)
        tot_t += s["tris"]
        tot_i += s["img_bytes"]
        tot_f += s["file_bytes"]
        print(f"{os.path.basename(p):42s} tris={s['tris']:7d} mats={s['materials']:3d} "
              f"imgs={len(s['images']):2d} tex={s['img_bytes'] / 1e6:6.2f} MB file={s['file_bytes'] / 1e6:6.2f} MB")
        if "-v" in os.environ.get("GLB_STATS", ""):
            for n, b in s["images"]:
                print(f"    {n:30s} {b / 1e3:8.1f} KB")
    print(f"TOTAL tex={tot_i / 1e6:.2f} MB file={tot_f / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
