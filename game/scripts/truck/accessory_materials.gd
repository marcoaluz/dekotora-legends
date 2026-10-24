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
	"andon_ink": {"c": "#7c0d1c", "metal": 0.0, "rough": 0.35, "coat": 0.0},   # letras do andon deluxe (T-172)
	"lamp_amber": {"c": "#ffb347", "emit": 2.5},
	"lamp_white": {"c": "#ffe9c2", "emit": 3.5},
	"lamp_red": {"c": "#ff2a2a", "emit": 2.5},
	"lamp_cyan": {"c": "#21e6ff", "emit": 2.5},
	"lamp_pink": {"c": "#ff2e88", "emit": 2.5},
	"lamp_yellow": {"c": "#fff35c", "emit": 2.5},
	# T-211: cores L/R das pecas da oficina (DecoColorDef): estrutura, painel e luzes
	"deco_black": {"c": "#15171c", "metal": 0.35, "rough": 0.28, "coat": 0.6},
	"deco_white": {"c": "#e9eef5", "metal": 0.25, "rough": 0.3, "coat": 0.8},
	"deco_silver": {"c": "#b9c2d0", "metal": 0.85, "rough": 0.22, "coat": 0.0},
	"deco_navy": {"c": "#1d2f6b", "metal": 0.3, "rough": 0.35, "coat": 0.6},
	"deco_gunmetal": {"c": "#4a505c", "metal": 0.9, "rough": 0.25, "coat": 0.0},
	"deco_red": {"c": "#c8202f", "metal": 0.35, "rough": 0.3, "coat": 0.8},
	"lamp_green": {"c": "#3dff7a", "emit": 2.5},
	"lamp_blue": {"c": "#2f7bff", "emit": 2.5},
	"lamp_violet": {"c": "#a35cff", "emit": 2.5},
	"lamp_off": {"c": "#202228", "metal": 0.0, "rough": 0.6},     # luz apagada (peca da oficina quebrada)
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
