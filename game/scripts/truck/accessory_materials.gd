class_name AccessoryMaterials
extends RefCounted
## Materiais PBR nomeados, iguais aos do Blender (blender/scripts/lib/pbr.py), para trocar variantes
## de cor/acabamento dos acessorios em tempo de execucao. Os nomes sao os mesmos do catalog.json.

static var _cache: Dictionary = {}

const DEFS: Dictionary = {
	"paint_white": {"c": "#d6dce6", "metal": 0.35, "rough": 0.32, "coat": 0.8},
	"paint_pink": {"c": "#ff2e88", "metal": 0.35, "rough": 0.32, "coat": 0.8},
	"paint_red": {"c": "#c8202f", "metal": 0.35, "rough": 0.32, "coat": 0.8},
	"paint_blue": {"c": "#1d3f8a", "metal": 0.35, "rough": 0.32, "coat": 0.8},
	"paint_gold": {"c": "#f0b83a", "metal": 1.0, "rough": 0.22, "coat": 0.0},
	"chrome": {"c": "#e6ebf2", "metal": 1.0, "rough": 0.07, "coat": 0.0},
	"steel": {"c": "#aeb8c8", "metal": 1.0, "rough": 0.32, "coat": 0.0},
	"rubber": {"c": "#1a1a1d", "metal": 0.0, "rough": 0.88, "coat": 0.0},
	"plastic": {"c": "#121214", "metal": 0.0, "rough": 0.55, "coat": 0.0},
	"lamp_amber": {"c": "#ffb347", "emit": 5.0},
	"lamp_white": {"c": "#ffe9c2", "emit": 7.0},
	"lamp_red": {"c": "#ff2a2a", "emit": 5.0},
	"lamp_cyan": {"c": "#21e6ff", "emit": 5.0},
	"lamp_pink": {"c": "#ff2e88", "emit": 5.0},
	"lamp_yellow": {"c": "#fff35c", "emit": 5.0},
}


static func make(name: String) -> StandardMaterial3D:
	if _cache.has(name):
		return _cache[name]
	var d: Dictionary = DEFS.get(name, DEFS["steel"])
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = Color(String(d["c"]))
	m.metallic = float(d.get("metal", 0.0))
	m.roughness = float(d.get("rough", 0.4))
	if float(d.get("coat", 0.0)) > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = float(d["coat"])
		m.clearcoat_roughness = 0.05
	if d.has("emit"):
		m.emission_enabled = true
		m.emission = Color(String(d["c"]))
		m.emission_energy_multiplier = float(d["emit"])
	_cache[name] = m
	return m
