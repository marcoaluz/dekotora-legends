class_name TruckConfig
extends RefCounted
## Descricao serializavel de um caminhao (pecas com dano, motor, turbo, escape, sistemas) e a
## funcao que aplica isso a um TruckSim. Usada pelo perfil local (GameState) e pelo servidor
## (que monta os caminhoes dos jogadores a partir do que o perfil manda).
##
## descritor = {
##   "parts": [{"id": "fb_basic", "dur": 80.0, "broken": false}, ...],   # da mais externa para a interna
##   "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std", "jake": false,
##   "systems": {"engine": 100.0, "steering": 100.0}
## }

const OUTER_ORDER: Array[String] = ["front_bumper", "rear_bumper", "side_skirts", "fenders", "front_lip", "grille", "visor"]


static func part_def(id: String) -> PartDef:
	var path: String = "res://data/parts/%s.tres" % id
	return load(path) as PartDef if ResourceLoader.exists(path) else null


## Aplica o descritor a um TruckSim (massa, motor, pecas e dano). A carga sempre comeca nova.
static func apply(t: TruckSim, desc: Dictionary) -> void:
	var loadout: Array[Dictionary] = []
	var weight: float = 0.0
	var defs: Array = []
	for p in desc.get("parts", []):
		var d: PartDef = part_def(String(p["id"]))
		if d != null:
			defs.append({"def": d, "state": p})
	defs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia: int = OUTER_ORDER.find(String((a["def"] as PartDef).slot))
		var ib: int = OUTER_ORDER.find(String((b["def"] as PartDef).slot))
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	for entry in defs:
		var d: PartDef = entry["def"]
		var st: Dictionary = entry["state"]
		var sp: Dictionary = d.to_sim_part()
		sp["dur"] = float(st.get("dur", d.durability))
		sp["broken"] = bool(st.get("broken", false))
		if not bool(sp["broken"]):
			weight += float(sp["weight"])
		loadout.append(sp)
	t.loadout = loadout
	var eng: EngineDef = load("res://data/engines/%s.tres" % desc.get("engine", "eng_i6_std")) as EngineDef
	var tur: TurboDef = load("res://data/engines/%s.tres" % desc.get("turbo", "turbo_none")) as TurboDef
	var exh: ExhaustDef = load("res://data/engines/%s.tres" % desc.get("exhaust", "exh_std")) as ExhaustDef
	t.engine.configure(eng, tur, exh, bool(desc.get("jake", false)))
	t.set_mass(weight + (eng.weight_kg if eng != null else 0.0), float(desc.get("cargo_kg", TruckSim.DEFAULT_CARGO)))
	t.cargo_fragility = float(desc.get("cargo_fragility", 1.0))
	t.style_points = int(desc.get("style_points", 0))
	t.cargo_trait = String(desc.get("cargo_trait", "normal"))
	t.cargo_penalty = 0.0
	var sys: Dictionary = desc.get("systems", {})
	t.systems["engine"] = float(sys.get("engine", 100.0))
	t.systems["steering"] = float(sys.get("steering", 100.0))
	t.systems["cargo"] = 100.0
	t.refresh_damage_effects()


## Caminhao basico de bot (para-choques simples).
static func basic_descriptor() -> Dictionary:
	return {"parts": [{"id": "fb_basic"}, {"id": "rb_basic"}], "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std", "jake": false,
		"systems": {"engine": 100.0, "steering": 100.0}}
