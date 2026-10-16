extends TestCase
## Testes dos dados em Resources (P41): carregam, batem com o BALANCEAMENTO e apontam para modelos que existem.

const VALID_ZONES: Array[String] = ["front", "rear", "left", "right", "roof", "wheels"]


func _load_all(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(load(dir + f))
	return out


func test_all_parts_load_and_reference_existing_models() -> void:
	var catalog := AccessoryCatalog.new()
	catalog.reload()
	var parts: Array[Resource] = _load_all("res://data/parts/")
	check(parts.size() >= 34, "pecas carregadas (%d)" % parts.size())
	for r in parts:
		var p: PartDef = r as PartDef
		check(p != null, "e um PartDef")
		if p == null:
			continue
		check(String(p.id) != "" and String(p.slot) != "", "%s tem id e slot" % p.id)
		check(catalog.entry(p.accessory_id) != {}, "%s: acessorio %s existe no catalogo" % [p.id, p.accessory_id])
		if catalog.entry(p.accessory_id) != {}:
			check(ResourceLoader.exists(String(catalog.entry(p.accessory_id)["model"])), "%s: arquivo .glb existe" % p.id)
		for z in p.zones:
			check(z in VALID_ZONES, "%s: zona valida (%s)" % [p.id, z])
		check(p.price > 0 and p.weight_kg >= 0.0, "%s: preco e peso coerentes" % p.id)


func test_balance_table_values() -> void:
	var fb: PartDef = load("res://data/parts/fb_chrome_steps.tres") as PartDef
	check_eq(int(fb.weight_kg), 420, "fb_chrome_steps peso")
	check_eq(int(fb.durability), 220, "fb_chrome_steps durabilidade")
	check_eq(fb.fame, 25, "fb_chrome_steps fama")
	check_eq(fb.price, 45000, "fb_chrome_steps preco")
	var gold: PartDef = load("res://data/parts/fb_gold_wing.tres") as PartDef
	check_eq(gold.price, 90000, "fb_gold_wing preco")
	var mural: PartDef = load("res://data/parts/mural_waves.tres") as PartDef
	check_near(mural.durability, 0.0, 0.001, "mural nao tem durabilidade")


func test_engines_turbos_exhausts_upgrades() -> void:
	var v8: EngineDef = load("res://data/engines/eng_v8.tres") as EngineDef
	check_near(v8.max_torque_nm, 2200.0, 0.1, "V8 torque")
	check_near(v8.weight_kg, 300.0, 0.1, "V8 peso extra")
	var twin: TurboDef = load("res://data/engines/turbo_twin.tres") as TurboDef
	check_near(twin.torque_gain, 0.30, 0.0001, "turbo duplo +30%")
	check_near(twin.lag_s, 1.1, 0.0001, "turbo duplo atraso")
	var ex: ExhaustDef = load("res://data/engines/exh_straight.tres") as ExhaustDef
	check_eq(ex.fame, 10, "escape direto +10 Fama")
	var jake: UpgradeDef = load("res://data/upgrades/jake_brake.tres") as UpgradeDef
	check_near(jake.value, 0.35, 0.0001, "freio-motor +35%")


func test_routes_build_tracks_and_rivals_exist() -> void:
	var routes: Array[Resource] = _load_all("res://data/routes/")
	check_eq(routes.size(), 3, "3 trechos de Kanto")
	var freights: Array[int] = []
	for r in routes:
		var rd: RouteDef = r as RouteDef
		freights.append(rd.freight)
		var t: Track = rd.build_track()
		check(t.length_m > 2500.0, "%s gera pista (%.0f m)" % [rd.id, t.length_m])
		var rival: RivalDef = load("res://data/rivals/%s.tres" % rd.rival_id) as RivalDef
		check(rival != null, "%s: rival %s existe" % [rd.id, rd.rival_id])
	freights.sort()
	check_eq(freights, [20000, 30000, 45000], "fretes do BALANCEAMENTO")
	var boss: RivalDef = load("res://data/rivals/boss_kanto.tres") as RivalDef
	check(boss.boss, "rival do trecho 3 e o chefe")


func test_rival_parts_exist() -> void:
	for r in _load_all("res://data/rivals/"):
		var rv: RivalDef = r as RivalDef
		for pid in rv.part_ids:
			check(ResourceLoader.exists("res://data/parts/%s.tres" % pid), "%s: peca %s existe" % [rv.id, pid])


func test_part_to_sim_part() -> void:
	var p: PartDef = load("res://data/parts/skirt_chrome.tres") as PartDef
	var sp: Dictionary = p.to_sim_part()
	check_eq(String(sp["id"]), "skirt_chrome", "id")
	check("left" in sp["zones"] and "right" in sp["zones"], "zonas laterais")
	check_near(float(sp["max"]), 200.0, 0.001, "durabilidade 200")
