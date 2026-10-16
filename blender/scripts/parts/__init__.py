"""Peças decorativas. Cada módulo define ID, SLOT, ZONE e build(m) -> lista de objetos.
Nomes de objeto: part_<slot>_<id>_*. ORDER = ordem de empilhamento no Godot (de baixo para cima)."""
import importlib

ORDER = ["fb_chrome_steps", "roof_lights_row", "andon_kanji"]


def load(part_id: str):
    return importlib.import_module(f"parts.{part_id}")
