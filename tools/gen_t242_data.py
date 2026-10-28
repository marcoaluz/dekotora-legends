"""T-242: atualiza no lugar (sem reordenar nada) as peças da T-232 que passaram a usar obras prontas de domínio
público: nome na loja (pt-BR), licença e tamanho da arte no catálogo. Os ids, preços e caminhos não mudam.

Uso (raiz do projeto, Python do sistema, só biblioteca padrão):  python -I tools/gen_t242_data.py
Idempotente. Tabelas: blender/scripts/lib/t242_registry.py e t242_sources.py.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "game")
sys.path.insert(0, os.path.join(HERE, "..", "blender", "scripts"))
from lib import t242_registry as REG  # noqa: E402
from lib import t242_sources as SRC  # noqa: E402


def license_text(pid):
    works = []
    for k in REG.sources_of(pid):
        i = SRC.info(k)
        works.append(f"{i['artist']}, {i['title']}, {i['date']} ({i['museum'].split(' (')[0]} {i['object']})")
    return ("domínio público / CC0 (T-242; obras: " + "; ".join(works) +
            "; tratamento de cor, recorte e brilho noturno nossos; ver docs/CREDITOS_MURAIS.md)")


def main():
    cpath = os.path.join(ROOT, "assets", "vehicles", "dekotora", "catalog.json")
    with open(cpath, encoding="utf-8") as f:
        cat = json.load(f)
    done = 0
    for e in cat["accessories"]:
        pid = e.get("id")
        if pid not in REG.NAMES:
            continue
        e["name"] = REG.NAMES[pid]
        e["license"] = license_text(pid)
        px = list(REG.REAR_PX if pid.startswith("rearpaint_") else REG.MURAL_PX)
        for arts in e["paint"].values():
            for a in arts:
                a["px"] = px
        done += 1
    if done != len(REG.NAMES):
        raise SystemExit("faltam peças no catálogo: %d de %d" % (done, len(REG.NAMES)))
    with open(cpath, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2)
    path = os.path.join(ROOT, "data", "i18n", "pt-BR.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    for pid, name in REG.NAMES.items():
        d["part." + pid] = name
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"OK gen_t242_data: {done} peças")


main()
