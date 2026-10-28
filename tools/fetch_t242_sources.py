"""Baixa as imagens originais das obras da T-242 (domínio público / CC0) para blender/renders/t242/fontes/.

Uso (raiz do projeto):  python -I tools/fetch_t242_sources.py [chave ...]
Só baixa o que falta. Arquivos baixados são DADOS (imagens); nada deles é executado. Pausa entre pedidos (os acervos
bloqueiam rajadas). A lista com links e licenças fica em blender/scripts/lib/t242_sources.py.
"""
import os
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(ROOT, "blender", "scripts"))
from lib import t242_sources as S  # noqa: E402

OUT = os.path.join(ROOT, "blender", "renders", "t242", "fontes")


def main():
    os.makedirs(OUT, exist_ok=True)
    keys = sys.argv[1:] or list(S.SOURCES)
    for k in keys:
        i = S.info(k)
        path = os.path.join(OUT, i["file"])
        if os.path.exists(path) and os.path.getsize(path) > 10000:
            print("ok (já existe)", k)
            continue
        req = urllib.request.Request(i["url"], headers={"User-Agent": "Mozilla/5.0 (Kaido Bakuso art fetch)"})
        with urllib.request.urlopen(req, timeout=180) as r:
            data = r.read()
        if not (data[:3] == b"\xff\xd8\xff" or data[:8] == b"\x89PNG\r\n\x1a\n"):
            raise SystemExit("não é JPG/PNG: %s" % k)
        with open(path, "wb") as f:
            f.write(data)
        print("baixado", k, len(data) // 1024, "KB")
        time.sleep(1.5)


main()
