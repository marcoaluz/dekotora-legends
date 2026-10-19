#!/usr/bin/env python
"""Gera os sons do jogo no ElevenLabs a partir das tabelas de docs/AUDIO_ELEVENLABS.md.

Uso (na raiz do projeto):
    python tools/gen_audio.py --list                  # mostra o que falta
    python tools/gen_audio.py --only ui_select,ui_buy # gera só estes
    python tools/gen_audio.py --section 5             # gera uma seção (1..7)
    python tools/gen_audio.py --all                   # gera tudo que falta (não regrava o que já existe)
    python tools/gen_audio.py --music                 # só a música (seção 7)

A chave vem de .chaves.env (ELEVENLABS_API_KEY); NUNCA é impressa. Os arquivos saem em MP3 (o Godot
importa MP3 e a música/loops usam loop=true no import); o nome segue a tabela, com extensão .mp3.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(ROOT, "docs", "AUDIO_ELEVENLABS.md")
OUT = os.path.join(ROOT, "game", "assets", "audio")
FOLDERS = {1: "engines", 2: "sfx/truck", 3: "sfx/crash", 4: "sfx/ambient", 5: "sfx/ui", 6: "sfx/net", 7: "music"}
API = "https://api.elevenlabs.io"


def key_file():
    """.chaves.env na raiz do projeto; numa worktree (.claude/worktrees/...) procura nas pastas acima."""
    d = ROOT
    for _ in range(6):
        p = os.path.join(d, ".chaves.env")
        if os.path.exists(p):
            return p
        d = os.path.dirname(d)
    return os.path.join(ROOT, ".chaves.env")


def load_key():
    env = {}
    with open(key_file(), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env["ELEVENLABS_API_KEY"]


def parse_seconds(txt):
    t = txt.strip().lower().replace(",", ".")
    m = re.match(r"(\d+(?:\.\d+)?)\s*min(?:\s*(\d+(?:\.\d+)?)\s*s)?", t)
    if m:
        return float(m.group(1)) * 60 + (float(m.group(2)) if m.group(2) else 0.0)
    m = re.match(r"(\d+(?:\.\d+)?)\s*s", t)
    return float(m.group(1)) if m else 3.0


def parse_doc():
    """Devolve lista de dicts {file, section, seconds, prompt}."""
    items = []
    section = 0
    with open(DOC, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"##\s+(\d+)\.", line)
            if m:
                section = int(m.group(1))
                continue
            m = re.match(r"\|\s*`([\w\-]+\.(?:wav|mp3))`\s*\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|\s*$", line)
            if m and section in FOLDERS:
                items.append({"file": os.path.splitext(m.group(1))[0], "section": section,
                              "seconds": parse_seconds(m.group(2)), "prompt": m.group(3)})
    # motor 6 cilindros preparado: mesmos prompts com outro começo (ver doc)
    extra = []
    for it in items:
        if it["file"].startswith("i6_std_"):
            p = re.sub(r"^Heavy (?:Japanese )?truck inline-six diesel engine", "Tuned high-performance inline-six diesel truck engine, aggressive and raspy,", it["prompt"])
            extra.append({"file": it["file"].replace("i6_std_", "i6_tuned_"), "section": 1, "seconds": it["seconds"], "prompt": p})
    return items + extra


def target_path(it):
    return os.path.join(OUT, FOLDERS[it["section"]], it["file"] + ".mp3")


def is_loop(it):
    p = it["prompt"].lower()
    return "seamless loop" in p or "loopable" in p


def post(path, body, key, timeout=300):
    """POST com repetição (429 = limite de requisições: espera e tenta de novo)."""
    for attempt in range(6):
        req = urllib.request.Request(API + path, data=json.dumps(body).encode("utf-8"), method="POST",
                                     headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and attempt < 5:
                time.sleep(4 * (attempt + 1))
                continue
            raise


def usage(key):
    for attempt in range(5):
        req = urllib.request.Request(API + "/v1/user/subscription", headers={"xi-api-key": key})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.load(r)
            return int(d["character_count"]), int(d["character_limit"])
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            raise
    return 0, 0


def generate(it, key):
    os.makedirs(os.path.dirname(target_path(it)), exist_ok=True)
    if it["section"] == 7:
        body = {"prompt": it["prompt"], "music_length_ms": int(it["seconds"] * 1000), "force_instrumental": True}
        data = post("/v1/music?output_format=mp3_44100_128", body, key, timeout=600)
    else:
        body = {"text": it["prompt"], "duration_seconds": max(0.5, min(it["seconds"], 30.0)),
                "prompt_influence": 0.5, "model_id": "eleven_text_to_sound_v2"}
        if is_loop(it):
            body["loop"] = True
        data = post("/v1/sound-generation?output_format=mp3_44100_128", body, key)
    with open(target_path(it), "wb") as f:
        f.write(data)
    return len(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--music", action="store_true")
    ap.add_argument("--section", type=int, default=0)
    ap.add_argument("--only", default="")
    ap.add_argument("--max-credits", type=int, default=30000, help="para de gerar se gastar mais que isso nesta execução")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--music-max", type=float, default=120.0, help="duração máxima (s) de cada música, para economizar créditos")
    args = ap.parse_args()
    items = parse_doc()
    if args.only:
        wanted = set(args.only.split(","))
        items = [i for i in items if i["file"] in wanted]
    elif args.section:
        items = [i for i in items if i["section"] == args.section]
    elif args.music:
        items = [i for i in items if i["section"] == 7]
    for i in items:
        if i["section"] == 7:
            i["seconds"] = min(i["seconds"], args.music_max)
    todo = [i for i in items if args.force or not os.path.exists(target_path(i))]
    if args.list or not (args.all or args.only or args.section or args.music):
        for i in items:
            print(("OK      " if os.path.exists(target_path(i)) else "FALTA   ") + FOLDERS[i["section"]] + "/" + i["file"])
        print(f"{len(todo)} faltando de {len(items)}")
        return
    key = load_key()
    start, limit = usage(key)
    print(f"créditos usados: {start}/{limit}")
    for n, it in enumerate(todo, 1):
        if n % 8 == 1 and n > 1:
            used, _ = usage(key)
            if used - start > args.max_credits:
                print("limite de créditos desta execução atingido; parando")
                break
        try:
            size = generate(it, key)
            print(f"[{n}/{len(todo)}] {FOLDERS[it['section']]}/{it['file']}.mp3  {size // 1024} KB")
        except urllib.error.HTTPError as e:
            print(f"[{n}/{len(todo)}] ERRO {it['file']}: HTTP {e.code} {e.read()[:200]!r}")
        except Exception as e:  # noqa: BLE001
            print(f"[{n}/{len(todo)}] ERRO {it['file']}: {e}")
        time.sleep(1.2)
    end, _ = usage(key)
    print(f"créditos gastos nesta execução: {end - start}  (total {end}/{limit})")


if __name__ == "__main__":
    main()
