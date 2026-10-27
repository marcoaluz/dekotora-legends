class_name TruckConfig
extends RefCounted
## Descricao serializavel de um caminhao (pecas com dano, motor, turbo, escape, sistemas) e a
## funcao que aplica isso a um TruckSim. Usada pelo perfil local (GameState) e pelo servidor
## (que monta os caminhoes dos jogadores a partir do que o perfil manda).
##
## descritor = {
##   "parts": [{"id": "fb_basic", "dur": 80.0, "broken": false}, ...],   # da mais externa para a interna
##   "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std", "jake": false,
##   "systems": {"engine": 100.0, "steering": 100.0},
##   "body": "base"      # BodyDef (data/bodies/): massa vazia, comprimento, agilidade, torque; sem = caminhao padrao
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
	var body: BodyDef = BodyDef.find(String(desc.get("body", "base")))
	t.base_mass = body.base_mass_kg if body != null else TruckSim.BASE_MASS
	t.length = body.length_m if body != null else Collision.LEN
	t.agility = body.agility if body != null else 1.0
	t.engine.body_torque = body.torque_mult if body != null else 1.0
	var default_cargo: float = body.default_cargo_kg if body != null else TruckSim.DEFAULT_CARGO
	t.set_mass(weight + (eng.weight_kg if eng != null else 0.0), float(desc.get("cargo_kg", default_cargo)))
	t.cargo_fragility = float(desc.get("cargo_fragility", 1.0))
	t.style_points = int(desc.get("style_points", 0))
	t.cargo_trait = String(desc.get("cargo_trait", "normal"))
	t.cargo_penalty = 0.0
	var sys: Dictionary = desc.get("systems", {})
	t.systems["engine"] = float(sys.get("engine", 100.0))
	t.systems["steering"] = float(sys.get("steering", 100.0))
	t.systems["cargo"] = 100.0
	t.refresh_damage_effects()


## T-231: pecas da oficina que os bots sorteiam (para-choque traseiro com lanternas sempre; foguete em 1 de 3).
const BOT_REAR: Array[String] = ["rb_square_row", "rb_round_twin", "rb_square_grid", "rb_neon_rows", "rb_target", "rb_bullet"]
const BOT_ROCKET: Array[String] = ["rocket_round", "rocket_neon_dash", "rocket_led"]
## T-232: pinturas que os bots sorteiam (mural em 1 de 2, traseira em 1 de 2, teto em 1 de 4). Peso 0: so visual.
const BOT_MURAL: Array[String] = ["mural_nami_fuji", "mural_koi", "mural_tora_take", "mural_hoo", "mural_kabuki", "mural_men"]
const BOT_REAR_PAINT: Array[String] = ["rearpaint_koi", "rearpaint_noh", "rearpaint_kitsune", "rearpaint_tengu", "rearpaint_oni"]
const BOT_ROOF_PAINT: Array[String] = ["roofpaint_01", "roofpaint_03", "roofpaint_06", "roofpaint_09"]
## T-233: para-choque da frente (sempre; 1 em 5 fica com o basico), saia em 1 de 2, retrovisor em 1 de 3.
const BOT_FRONT: Array[String] = ["fb_fan_plate", "fb_fan_amber", "fb_fan_red", "fb_fan_stripe", "fb_box_amber", "fb_smooth_chrome"]
const BOT_SKIRT: Array[String] = ["skirt_neon_twin", "skirt_neon_dash", "skirt_chrome_rails", "skirt_neon_green"]
const BOT_MIRROR: Array[String] = ["mirror_stay_l", "mirror_stay_frame", "mirror_stay_truss"]


## Pecas de um bot pela semente (mesma semente = mesmas pecas no servidor e em todos os clientes).
static func bot_part_ids(seed_: int) -> Array[String]:
	var k: int = absi(seed_)
	var out: Array[String] = ["fb_basic" if k % 5 == 4 else BOT_FRONT[(k / 5) % BOT_FRONT.size()], BOT_REAR[k % BOT_REAR.size()]]
	if (k / 3) % 2 == 0:
		out.append(BOT_SKIRT[(k / 6) % BOT_SKIRT.size()])
	if k % 3 == 1:
		out.append(BOT_MIRROR[(k / 3) % BOT_MIRROR.size()])
	if k % 3 == 0:
		out.append(BOT_ROCKET[(k / 3) % BOT_ROCKET.size()])
	if k % 2 == 0:
		out.append(BOT_MURAL[(k / 2) % BOT_MURAL.size()])
	if (k / 2) % 2 == 0:
		out.append(BOT_REAR_PAINT[(k / 4) % BOT_REAR_PAINT.size()])
	if k % 4 == 1:
		out.append(BOT_ROOF_PAINT[(k / 4) % BOT_ROOF_PAINT.size()])
	return out


## Descritor de bot com as pecas sorteadas pela semente (T-231).
static func bot_descriptor(seed_: int) -> Dictionary:
	var d: Dictionary = basic_descriptor()
	var parts: Array = []
	for id in bot_part_ids(seed_):
		parts.append({"id": id})
	d["parts"] = parts
	return d


## Caminhao basico de bot (para-choques simples).
static func basic_descriptor() -> Dictionary:
	return {"parts": [{"id": "fb_basic"}, {"id": "rb_basic"}], "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std", "jake": false,
		"systems": {"engine": 100.0, "steering": 100.0}}
