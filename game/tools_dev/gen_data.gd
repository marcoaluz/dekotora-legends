extends SceneTree
## Gera os .tres de game/data/ a partir das tabelas de docs/BALANCEAMENTO.md (P41).
## Uso: godot --headless --path game -s res://tools_dev/gen_data.gd
## Os .tres sao a fonte de verdade depois de gerados; rode de novo so para regenerar tudo.

# id, slot, zonas, peso, durabilidade, fama, preco, accessory_id, variante
const PARTS: Array = [
	# --- as 16 pecas da tabela "Pecas decorativas (MVP)" do BALANCEAMENTO
	["fb_basic", "front_bumper", ["front"], 120, 80, 5, 8000, "fb_standard_chrome", {"main": "steel"}],
	["fb_chrome_steps", "front_bumper", ["front"], 420, 220, 25, 45000, "fb_ornate_steps", {}],
	["fb_gold_wing", "front_bumper", ["front"], 560, 300, 40, 90000, "fb_ornate_steps", {"main": "paint_gold", "accent": "paint_gold"}],
	["visor_basic", "visor", ["front"], 40, 40, 5, 5000, "visor_sunshade", {"main": "paint_white"}],
	["visor_gold_lights", "visor", ["front"], 110, 70, 20, 30000, "visor_sunshade", {"main": "paint_blue", "accent": "lamp_yellow"}],
	["roof_lights_row", "roof_lights", ["roof"], 30, 20, 15, 12000, "roof_light_bar_rect", {}],
	["roof_lights_crown", "roof_lights", ["roof"], 70, 30, 30, 35000, "roof_round_lamps_set", {}],
	["skirt_chrome", "side_skirts", ["left", "right"], 300, 200, 15, 40000, "skirt_chrome_panel", {}],
	["skirt_light_bar", "side_skirts", ["left", "right"], 180, 90, 25, 38000, "skirt_lit_neon", {}],
	["andon_kanji", "andon", ["rear"], 60, 30, 15, 15000, "roof_sign_lightbox", {}],
	["andon_big_panel", "andon", ["rear"], 140, 50, 30, 42000, "rear_panel_frame", {"main": "chrome", "accent": "paint_red"}],
	["rb_basic", "rear_bumper", ["rear"], 100, 80, 3, 6000, "rb_decorative", {"main": "steel"}],
	["rb_chrome", "rear_bumper", ["rear"], 260, 180, 12, 28000, "rb_decorative", {}],
	["mural_waves", "mural", ["left", "right"], 0, 0, 20, 20000, "panel_japanese_theme", {}],
	["mural_lightning", "mural", ["left", "right"], 0, 0, 25, 25000, "side_panel_decor", {}],
	["hub_chrome", "hubcaps", ["wheels"], 40, 60, 8, 10000, "hubcap_decorative", {}],
	# --- acessorios extras da biblioteca 3D (valores PROPOSTOS por Claude; ajustar jogando)
	["grille_frame_chrome", "grille", ["front"], 60, 50, 8, 12000, "grille_frame_chrome", {}],
	["bumper_extension_lip", "front_lip", ["front"], 90, 60, 10, 14000, "bumper_extension_lip", {}],
	["aux_round_lamps_pair", "aux_lights", ["front"], 50, 30, 12, 15000, "aux_round_lamps_pair", {}],
	["front_trim_set", "front_trim", ["front"], 25, 20, 6, 6000, "front_trim_set", {}],
	["front_crest_ornament", "front_ornament", ["front"], 30, 25, 18, 20000, "front_crest_ornament", {}],
	["roof_marker_small_lamps", "roof_lights", ["roof"], 20, 15, 10, 8000, "roof_marker_small_lamps", {}],
	["antenna_decor_mount", "roof_ornament", ["roof"], 15, 10, 8, 5000, "antenna_decor_mount", {}],
	["roof_light_frame_halo", "roof_frame", ["roof"], 25, 15, 22, 22000, "roof_light_frame_halo", {}],
	["roof_torii_ornament", "body_ornament", ["roof"], 70, 40, 28, 30000, "roof_torii_ornament", {}],
	["fender_extension", "fenders", ["left", "right"], 110, 90, 12, 16000, "fender_extension", {}],
	["step_metal", "steps", ["left", "right"], 35, 40, 4, 4000, "step_metal", {}],
	["side_trim_set", "side_trim", ["left", "right"], 45, 30, 8, 7000, "side_trim_set", {}],
	["side_box_decor", "side_box", ["left", "right"], 150, 120, 10, 14000, "side_box_decor", {}],
	["side_ornament_wave", "side_ornament", ["left", "right"], 20, 0, 16, 15000, "side_ornament_wave", {}],
	["rear_lamp_cluster", "rear_lamps", ["rear"], 40, 30, 9, 9000, "rear_lamp_cluster", {}],
	["rear_plate_custom", "plate", ["rear"], 10, 15, 5, 3000, "rear_plate_custom", {}],
	["mudflap_designed", "mudflaps", ["rear"], 25, 25, 6, 4500, "mudflap_designed", {}],
	["rear_ornament_metal", "rear_ornament", ["rear"], 80, 60, 20, 24000, "rear_ornament_metal", {}],
]

# id, peso extra, torque, rpm de corte, preco
const ENGINES: Array = [
	["eng_i6_std", 0, 1400, 2400, 0],
	["eng_i6_tuned", 80, 1750, 2600, 60000],
	["eng_v8", 300, 2200, 2500, 150000],
]
# id, ganho, rpm minimo, atraso, preco
const TURBOS: Array = [
	["turbo_none", 0.0, 0.0, 0.0, 0],
	["turbo_single", 0.18, 1500.0, 0.8, 40000],
	["turbo_twin", 0.30, 1300.0, 1.1, 85000],
]
# id, bonus torque, fama, preco
const EXHAUSTS: Array = [
	["exh_std", 0.0, 0, 0],
	["exh_straight", 0.03, 10, 18000],
]
# id, efeito, valor, efeito colateral, valor, preco
const UPGRADES: Array = [
	["jake_brake", "engine_brake", 0.35, "", 0.0, 25000],
	["tires_sport", "grip", 0.12, "tire_wear", 0.10, 30000],
]


## Pecas que trazem buzina propria (som em audio/sfx/truck/)
const HORNS: Dictionary = {
	"fb_gold_wing": "horn_musical_1", "front_crest_ornament": "horn_musical_2",
	"roof_lights_crown": "horn_musical_1", "andon_big_panel": "horn_musical_2", "aux_round_lamps_pair": "horn_air_basic",
}


func _fame_required(price: int) -> int:
	if price < 15000:
		return 0
	if price < 30000:
		return 20
	if price < 50000:
		return 60
	return 120


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("falha ao salvar %s (%d)" % [path, err])


func _initialize() -> void:
	for p in PARTS:
		var d := PartDef.new()
		d.id = StringName(p[0])
		d.display_key = "part." + String(p[0])
		d.slot = StringName(p[1])
		d.zones = PackedStringArray(p[2])
		d.weight_kg = float(p[3])
		d.durability = float(p[4])
		d.fame = int(p[5])
		d.price = int(p[6])
		d.fame_required = _fame_required(int(p[6]))
		d.accessory_id = String(p[7])
		d.variant = p[8]
		d.horn = String(HORNS.get(String(p[0]), ""))
		_save(d, "res://data/parts/%s.tres" % p[0])
	for e in ENGINES:
		var d := EngineDef.new()
		d.id = StringName(e[0])
		d.display_key = "engine." + String(e[0])
		d.weight_kg = float(e[1])
		d.max_torque_nm = float(e[2])
		d.redline_rpm = float(e[3])
		d.price = int(e[4])
		d.sound_set = String(e[0])
		_save(d, "res://data/engines/%s.tres" % e[0])
	for t in TURBOS:
		var d := TurboDef.new()
		d.id = StringName(t[0])
		d.display_key = "turbo." + String(t[0])
		d.torque_gain = float(t[1])
		d.min_rpm = float(t[2])
		d.lag_s = float(t[3])
		d.price = int(t[4])
		_save(d, "res://data/engines/%s.tres" % t[0])
	for x in EXHAUSTS:
		var d := ExhaustDef.new()
		d.id = StringName(x[0])
		d.display_key = "exhaust." + String(x[0])
		d.torque_bonus = float(x[1])
		d.fame = int(x[2])
		d.price = int(x[3])
		_save(d, "res://data/engines/%s.tres" % x[0])
	for u in UPGRADES:
		var d := UpgradeDef.new()
		d.id = StringName(u[0])
		d.display_key = "upgrade." + String(u[0])
		d.effect = StringName(u[1])
		d.value = float(u[2])
		d.side_effect = StringName(u[3])
		d.side_value = float(u[4])
		d.price = int(u[5])
		_save(d, "res://data/upgrades/%s.tres" % u[0])
	_gen_rivals_and_routes()
	print("OK gen_data")
	quit()


func _gen_rivals_and_routes() -> void:
	# Rivais (nomes PROVISORIOS: decisao aberta do Marco em docs/GDD "rivais de Kanto")
	var rivals: Array = [
		["rival_coast", "Trovao Rosa", 0, Color("#ff6fb1"), ["fb_basic", "rb_basic"], false],
		["rival_urban", "Dragao de Aco", 1, Color("#3a73d6"), ["fb_chrome_steps", "roof_lights_row", "rb_basic"], false],
		["rival_mountain", "Lua Cromada", 1, Color("#3fb26f"), ["fb_chrome_steps", "skirt_chrome", "rb_chrome"], false],
		["boss_kanto", "Imperador da Estrada", 2, Color("#f5cc5a"), ["fb_gold_wing", "skirt_chrome", "rb_chrome", "roof_lights_crown", "andon_kanji"], true],
	]
	for r in rivals:
		var d := RivalDef.new()
		d.id = StringName(r[0])
		d.display_name = String(r[1])
		d.difficulty = int(r[2])
		d.paint = r[3]
		d.part_ids = PackedStringArray(r[4])
		d.boss = bool(r[5])
		d.taunt_key = "rival.%s.taunt" % r[0]
		_save(d, "res://data/rivals/%s.tres" % r[0])
	# Rotas de Kanto (3 trechos). Frete do BALANCEAMENTO: 20.000 / 30.000 / 45.000
	var routes: Array = [
		["kanto_1_coast", 20000, "coast", "rival_coast", 0, 0,
			[{"length": 500.0, "curve": 0.0}, {"length": 350.0, "curve": -0.5}, {"length": 400.0, "curve": 0.0},
			 {"length": 350.0, "curve": 0.6}, {"length": 300.0, "curve": 0.0, "hill": 0.03}, {"length": 300.0, "curve": 0.0, "hill": -0.03},
			 {"length": 400.0, "curve": -0.4}, {"length": 400.0, "curve": 0.0}]],
		["kanto_2_viaduct", 30000, "city", "rival_urban", 1, 20,
			[{"length": 400.0, "curve": 0.0}, {"length": 300.0, "curve": 0.9}, {"length": 250.0, "curve": -0.9},
			 {"length": 400.0, "curve": 0.0, "hill": 0.04}, {"length": 300.0, "curve": 1.0}, {"length": 300.0, "curve": -1.1},
			 {"length": 300.0, "curve": 0.0, "hill": -0.04}, {"length": 500.0, "curve": 0.3}]],
		["kanto_3_mountain", 45000, "mountain", "boss_kanto", 1, 60,
			[{"length": 350.0, "curve": 0.0, "hill": 0.03}, {"length": 300.0, "curve": 1.2, "hill": 0.05}, {"length": 250.0, "curve": -1.3, "hill": 0.04},
			 {"length": 300.0, "curve": 1.4}, {"length": 250.0, "curve": -1.0, "hill": -0.05}, {"length": 300.0, "curve": 1.2, "hill": -0.04},
			 {"length": 300.0, "curve": -1.5}, {"length": 350.0, "curve": 0.5, "hill": 0.02}, {"length": 400.0, "curve": 0.0}]],
	]
	for rt in routes:
		var d := RouteDef.new()
		d.id = StringName(rt[0])
		d.display_key = "route." + String(rt[0])
		d.freight = int(rt[1])
		d.scenery = StringName(rt[2])
		d.rival_id = StringName(rt[3])
		d.traffic = int(rt[4])
		d.fame_required = int(rt[5])
		var secs: Array[Dictionary] = []
		for s in rt[6]:
			secs.append(s)
		d.sections = secs
		_save(d, "res://data/routes/%s.tres" % rt[0])
