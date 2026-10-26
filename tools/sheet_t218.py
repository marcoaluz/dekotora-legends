"""Folhas de contato das capturas da T-218 (garagem e corrida com o rival), pelo Python do Blender (sem Pillow).
Uso (raiz do projeto): blender -b --factory-startup -P tools/sheet_t218.py -- PASTA_DAS_CAPTURAS PASTA_DE_SAIDA
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender", "scripts"))
from lib import preview  # noqa: E402

src, out = [os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2]]
os.makedirs(out, exist_ok=True)
IDS = ("alubox", "tarp", "pinkbox", "tanker", "dump")
gar = []
for i in IDS:
    gar += [os.path.join(src, f"garagem_{i}_34.png"), os.path.join(src, f"garagem_{i}_lado.png")]
gar += [os.path.join(src, n) for n in ("garagem_pinkbox_noite_34.png", "garagem_pinkbox_noite_lado.png",
                                       "garagem_tarp_pecas_noite.png", "garagem_dump_pecas_noite.png")]
preview.contact_sheet([p for p in gar if os.path.exists(p)], os.path.join(out, "garagem_t218.png"), cols=4)
race = []
for t in ("day", "night"):
    for i in IDS:
        p = os.path.join(src, f"corrida_{i}_{t}", "t01_1.png")
        if os.path.exists(p):
            race.append(p)
preview.contact_sheet(race, os.path.join(out, "rival_na_pista_t218.png"), cols=5)
print("OK sheet_t218")
