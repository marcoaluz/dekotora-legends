extends Node
## GameState (autoload): perfil do jogador (dinheiro, Fama, pecas, montagem, dano, progresso),
## save em user://profile.json (escrita atomica) e as contas da garagem (preco, reparo, pesos).
## Fase 6 em diante: o servidor passa a ser a fonte; este arquivo vira cache (docs/MULTIPLAYER.md).

signal profile_changed
## Acao de perfil feita (compra, reparo...). A rede escuta e repassa ao servidor quando online.
signal action_performed(action: String, arg: String)
var _mute_actions: bool = false


func _act(action: String, arg: String) -> void:
	if not _mute_actions:
		action_performed.emit(action, arg)

const SAVE_PATH := "user://profile.json"
const START_MONEY: int = 50000
const REPAIR_FACTOR: float = 0.5                 # reparo = preco x %dano x 0,5  (BALANCEAMENTO)
const REPAINT_FACTOR: float = 0.3                # murais riscados: repintar = 30% do preco
const SYSTEM_REPAIR_PRICE: Dictionary = {"engine": 30000, "steering": 20000}   # suposicao: ver DECISOES
const DEFAULT_PARTS: Array[String] = ["fb_basic", "rb_basic"]
const SAVE_VERSION: int = 1

var profile: Dictionary = {}
var save_path: String = SAVE_PATH               # o servidor usa user://profiles/<codigo>.json

# Preenchido pelo menu antes de iniciar uma corrida
var pending_route: RouteDef = null
var pending_contract: Dictionary = {}          # contrato aceito no Mercado (vazio = corrida sem contrato)
var last_result: Dictionary = {}

var _part_cache: Dictionary = {}


func _ready() -> void:
	load_profile()


# ---------------------------------------------------------------- perfil

func new_profile() -> void:
	profile = {
		"version": SAVE_VERSION,
		"money": START_MONEY,
		"fame": 0,
		"owned": {},                                   # id -> {dur, broken, scratch}
		"installed": {},                               # slot -> id
		"engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std",
		"jake_brake": false, "sport_tires": false,
		"owned_mech": {"eng_i6_std": true, "turbo_none": true, "exh_std": true},   # motores/turbos/escapes/upgrades comprados
		"systems": {"engine": 100.0, "steering": 100.0},
		"paint": "#e9eef5",
		"decals": [],                                  # adesivos: [{id, slot, x, y, size, color}]
		"light_pattern": "steady",
		"routes_done": {},                             # id -> {best_time, best_position}
		"player_code": _make_player_code(),
	}
	for id in DEFAULT_PARTS:
		var d: PartDef = part(id)
		if d != null:
			add_owned(d)
			profile["installed"][String(d.slot)] = id
	save_profile()
	profile_changed.emit()


func _make_player_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var letters: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code: String = ""
	for i in 8:
		code += letters[rng.randi_range(0, letters.length() - 1)]
	return code


func load_profile() -> void:
	if FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION:
			profile = parsed
			profile_changed.emit()
			return
	new_profile()


## Escrita atomica: grava num arquivo temporario e renomeia (nao corrompe se o app fechar no meio).
## Cada gravacao incrementa `rev` (usada para sincronizar perfil offline/online).
func save_profile() -> void:
	profile["rev"] = int(profile.get("rev", 0)) + 1
	var tmp: String = save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: nao consegui salvar o perfil em " + save_path)
		return
	f.store_string(JSON.stringify(profile, "	"))
	f.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir != null:
		if FileAccess.file_exists(save_path):
			dir.remove(save_path.get_file())
		dir.rename(tmp.get_file(), save_path.get_file())


## Usa o codigo de jogador de OUTRO aparelho: o perfil local vira "vazio" (rev 0) e, ao conectar,
## o servidor manda a garagem guardada para esse codigo (MULTIPLAYER.md: perfil unico celular/PC).
func adopt_player_code(code: String) -> void:
	new_profile()
	profile["player_code"] = code.strip_edges().to_upper()
	profile["rev"] = 0
	save_profile_cache_only()
	profile_changed.emit()


## Grava o perfil vindo do servidor sem incrementar `rev` (o servidor ja incrementou).
func save_profile_cache_only() -> void:
	var rev: int = int(profile.get("rev", 0))
	save_profile()
	profile["rev"] = rev


func money() -> int:
	return int(profile["money"])


func fame() -> int:
	return int(profile["fame"])


# ---------------------------------------------------------------- catalogo de dados

func part(id: String) -> PartDef:
	if not _part_cache.has(id):
		var path: String = "res://data/parts/%s.tres" % id
		_part_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _part_cache[id]


func all_parts() -> Array[PartDef]:
	var out: Array[PartDef] = []
	for f in DirAccess.get_files_at("res://data/parts/"):
		if f.ends_with(".tres"):
			var d: PartDef = part(f.get_basename())
			if d != null:
				out.append(d)
	out.sort_custom(func(a: PartDef, b: PartDef) -> bool: return a.price < b.price)
	return out


func parts_for_slot(slot: String) -> Array[PartDef]:
	var out: Array[PartDef] = []
	for d in all_parts():
		if String(d.slot) == slot:
			out.append(d)
	return out


const SLOT_ORDER: Array[String] = ["front_bumper", "front_lip", "grille", "front_trim", "front_ornament", "aux_lights", "visor",
	"roof_lights", "roof_frame", "roof_ornament", "andon", "body_ornament", "side_skirts", "fenders", "steps", "side_trim",
	"side_box", "side_ornament", "mural", "hubcaps", "rear_bumper", "rear_lamps", "plate", "mudflaps", "rear_ornament"]


## Slots na ordem logica do caminhao (frente -> teto -> laterais -> traseira).
func slots() -> Array[String]:
	var seen: Array[String] = []
	for d in all_parts():
		if String(d.slot) not in seen:
			seen.append(String(d.slot))
	seen.sort_custom(func(a: String, b: String) -> bool:
		var ia: int = SLOT_ORDER.find(a)
		var ib: int = SLOT_ORDER.find(b)
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	return seen


# ---------------------------------------------------------------- pecas possuidas

func owns(id: String) -> bool:
	return (profile["owned"] as Dictionary).has(id)


func add_owned(d: PartDef) -> void:
	(profile["owned"] as Dictionary)[String(d.id)] = {"dur": d.durability, "broken": false, "scratch": 0.0}


func can_buy(d: PartDef) -> String:
	if owns(String(d.id)):
		return "ja possui"
	if fame() < d.fame_required:
		return "precisa de %d Fama" % d.fame_required
	if money() < d.price:
		return "dinheiro insuficiente"
	return ""


func buy(d: PartDef) -> bool:
	if can_buy(d) != "":
		return false
	profile["money"] = money() - d.price
	add_owned(d)
	save_profile()
	_act("buy_part", String(d.id))
	profile_changed.emit()
	return true


func installed_id(slot: String) -> String:
	return String((profile["installed"] as Dictionary).get(slot, ""))


func install(id: String) -> bool:
	var d: PartDef = part(id)
	if d == null or not owns(id):
		return false
	(profile["installed"] as Dictionary)[String(d.slot)] = id
	save_profile()
	_act("install", id)
	profile_changed.emit()
	return true


func uninstall(slot: String) -> void:
	(profile["installed"] as Dictionary).erase(slot)
	save_profile()
	_act("uninstall", slot)
	profile_changed.emit()


func sell(id: String) -> void:
	var d: PartDef = part(id)
	if d == null or not owns(id):
		return
	profile["money"] = money() + int(float(d.price) * 0.5)      # revenda a 50%
	(profile["owned"] as Dictionary).erase(id)
	if installed_id(String(d.slot)) == id:
		(profile["installed"] as Dictionary).erase(String(d.slot))
	save_profile()
	_act("sell", id)
	profile_changed.emit()


## Perfil de demonstracao (capturas de tela, loja): caminhao cheio de pecas, dinheiro e Fama de sobra.
func apply_demo_profile() -> void:
	new_profile()
	profile["money"] = 900000
	profile["fame"] = 500
	for id in ["fb_gold_wing", "visor_gold_lights", "roof_lights_crown", "skirt_light_bar", "andon_kanji", "rb_chrome", "mural_lightning", "hub_chrome",
			"grille_frame_chrome", "aux_round_lamps_pair", "front_crest_ornament", "roof_torii_ornament", "fender_extension", "side_ornament_wave", "rear_lamp_cluster", "mudflap_designed"]:
		var d: PartDef = part(id)
		if d != null and buy(d):
			install(id)
	profile["engine"] = "eng_v8"
	profile["turbo"] = "turbo_twin"


## Buzina da primeira peca instalada que traga uma; senao a buzina de ar basica.
func installed_horn() -> String:
	for d in installed_part_defs():
		if d.horn != "":
			return d.horn
	return "horn_air_basic"


# ---------------------------------------------------------------- montagem -> simulacao

func installed_part_defs() -> Array[PartDef]:
	var out: Array[PartDef] = []
	for slot in profile["installed"]:
		var d: PartDef = part(String(profile["installed"][slot]))
		if d != null:
			out.append(d)
	return out


## Lista de pecas para TruckSim.set_loadout, com o DANO atual (durabilidade e quebra) do perfil.
## Ordem: da mais externa para a interna (para-choques primeiro, teto por ultimo).
func build_sim_loadout() -> Array[Dictionary]:
	var defs: Array[PartDef] = installed_part_defs()
	var order: Array[String] = ["front_bumper", "rear_bumper", "side_skirts", "fenders", "front_lip", "grille", "visor"]
	defs.sort_custom(func(a: PartDef, b: PartDef) -> bool:
		var ia: int = order.find(String(a.slot))
		var ib: int = order.find(String(b.slot))
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	var out: Array[Dictionary] = []
	for d in defs:
		var sp: Dictionary = d.to_sim_part()
		var own: Dictionary = profile["owned"][String(d.id)]
		sp["dur"] = float(own["dur"])
		sp["broken"] = bool(own["broken"])
		out.append(sp)
	return out


## Tipos de item mecanico: kind -> pasta e chave do perfil
const MECH_KINDS: Dictionary = {
	"engine": {"dir": "res://data/engines/", "key": "engine", "ids": ["eng_i6_std", "eng_i6_tuned", "eng_v8"]},
	"turbo": {"dir": "res://data/engines/", "key": "turbo", "ids": ["turbo_none", "turbo_single", "turbo_twin"]},
	"exhaust": {"dir": "res://data/engines/", "key": "exhaust", "ids": ["exh_std", "exh_straight"]},
	"upgrade": {"dir": "res://data/upgrades/", "key": "", "ids": ["jake_brake", "tires_sport"]},
}


func mech_def(id: String) -> Resource:
	for kind in MECH_KINDS:
		if id in MECH_KINDS[kind]["ids"]:
			return load("%s%s.tres" % [MECH_KINDS[kind]["dir"], id])
	return null


func mech_kind(id: String) -> String:
	for kind in MECH_KINDS:
		if id in MECH_KINDS[kind]["ids"]:
			return kind
	return ""


func owns_mech(id: String) -> bool:
	return (profile["owned_mech"] as Dictionary).has(id)


func mech_installed(id: String) -> bool:
	match mech_kind(id):
		"engine", "turbo", "exhaust":
			return String(profile[MECH_KINDS[mech_kind(id)]["key"]]) == id
		"upgrade":
			return bool(profile["jake_brake"]) if id == "jake_brake" else bool(profile["sport_tires"])
	return false


func can_buy_mech(id: String) -> String:
	var d: Resource = mech_def(id)
	if d == null:
		return "indisponivel"
	if owns_mech(id):
		return "ja possui"
	if money() < int(d.get("price")):
		return "dinheiro insuficiente"
	return ""


func buy_mech(id: String) -> bool:
	if can_buy_mech(id) != "":
		return false
	profile["money"] = money() - int(mech_def(id).get("price"))
	(profile["owned_mech"] as Dictionary)[id] = true
	save_profile()
	_act("buy_mech", id)
	profile_changed.emit()
	return true


## Instala (ou liga) um item mecanico ja comprado. Upgrades alternam ligado/desligado.
func install_mech(id: String) -> bool:
	if not owns_mech(id):
		return false
	match mech_kind(id):
		"engine", "turbo", "exhaust":
			profile[MECH_KINDS[mech_kind(id)]["key"]] = id
		"upgrade":
			if id == "jake_brake":
				profile["jake_brake"] = not bool(profile["jake_brake"])
			else:
				profile["sport_tires"] = not bool(profile["sport_tires"])
	save_profile()
	_act("install_mech", id)
	profile_changed.emit()
	return true


## Estatisticas de uma montagem hipotetica sem alterar o perfil. changes: {"install": part_id,
## "uninstall": slot, "engine": id, "turbo": id, "exhaust": id, "jake_brake": bool}.
func preview(changes: Dictionary) -> Dictionary:
	var backup: Dictionary = profile
	profile = backup.duplicate(true)
	if changes.has("install"):
		var d: PartDef = part(String(changes["install"]))
		if d != null:
			if not owns(String(d.id)):
				add_owned(d)
			(profile["installed"] as Dictionary)[String(d.slot)] = String(d.id)
	if changes.has("uninstall"):
		(profile["installed"] as Dictionary).erase(String(changes["uninstall"]))
	for k in ["engine", "turbo", "exhaust"]:
		if changes.has(k):
			profile[k] = changes[k]
	if changes.has("jake_brake"):
		profile["jake_brake"] = changes["jake_brake"]
	if changes.has("paint"):
		profile["paint"] = changes["paint"]
	if changes.has("decals"):
		profile["decals"] = changes["decals"]
	var out: Dictionary = {"mass": total_mass(), "zero100": estimate_zero_to_100(), "rating": total_fame_rating()}
	profile = backup
	return out


## Descritor do caminhao do jogador (para TruckConfig.apply e para o servidor).
func truck_descriptor() -> Dictionary:
	var parts: Array = []
	for d in installed_part_defs():
		var own: Dictionary = profile["owned"][String(d.id)]
		parts.append({"id": String(d.id), "dur": float(own["dur"]), "broken": bool(own["broken"])})
	return {
		"parts": parts, "engine": profile["engine"], "turbo": profile["turbo"], "exhaust": profile["exhaust"],
		"jake": bool(profile["jake_brake"]), "paint": profile.get("paint", "#e9eef5"), "style_points": style_points(),
		"body": String(profile.get("body", "base")),
		"systems": {"engine": float(profile["systems"]["engine"]), "steering": float(profile["systems"]["steering"])},
	}.merged(Contracts.sim_fields(pending_contract))


func configure_truck(t: TruckSim) -> void:
	TruckConfig.apply(t, truck_descriptor())


## Protecao por zona das pecas instaladas: {zona: [durabilidade atual, durabilidade maxima]}.
func zone_protection() -> Dictionary:
	var out: Dictionary = {"front": [0.0, 0.0], "rear": [0.0, 0.0], "left": [0.0, 0.0], "right": [0.0, 0.0]}
	for d in installed_part_defs():
		if d.durability <= 0.0:
			continue
		var own: Dictionary = profile["owned"][String(d.id)]
		var cur: float = 0.0 if bool(own["broken"]) else float(own["dur"])
		for z in d.zones:
			if out.has(String(z)):
				out[String(z)][0] += cur
				out[String(z)][1] += d.durability
	return out


## Pontos de destaque da pintura e dos adesivos (StyleCatalog).
func style_points() -> int:
	return StyleCatalog.paint_points(String(profile.get("paint", "#e9eef5"))) + StyleCatalog.decal_points(profile.get("decals", []) as Array)


## Nota de DESTAQUE: pecas instaladas e inteiras (inclui murais e calotas) + escape + pintura + adesivos.
func destaque() -> int:
	return total_fame_rating()


## (nome antigo) mesma coisa que destaque().
func total_fame_rating() -> int:
	var f: int = style_points()
	for d in installed_part_defs():
		var own: Dictionary = profile["owned"][String(d.id)]
		if not bool(own["broken"]):
			f += roundi(float(d.fame) * (1.0 - clampf(float(own.get("scratch", 0.0)), 0.0, 1.0)))
	var exh: ExhaustDef = load("res://data/engines/%s.tres" % profile["exhaust"]) as ExhaustDef
	if exh != null:
		f += exh.fame
	return f


## Tempo estimado de 0 a 100 km/h (s) da montagem atual, rodando a propria simulacao numa reta.
func estimate_zero_to_100() -> float:
	var t := TruckSim.new()
	configure_truck(t)
	var track := Track.new()
	track.add_section(8000.0, 0.0)
	var cmd := Commands.make(0.0, 1.0, 0.0)
	var time: float = 0.0
	while t.speed < 100.0 / 3.6 and time < 90.0:
		t.step(RaceSim.FIXED_DT, cmd, track)
		time += RaceSim.FIXED_DT
	return time


func total_mass() -> float:
	var t := TruckSim.new()
	configure_truck(t)
	return t.mass


# ---------------------------------------------------------------- reparo (P43)

func part_repair_cost(id: String) -> int:
	var d: PartDef = part(id)
	if d == null or not owns(id):
		return 0
	var own: Dictionary = profile["owned"][id]
	if d.durability <= 0.0:                                  # mural: repintar
		return roundi(float(d.price) * REPAINT_FACTOR * clampf(float(own["scratch"]), 0.0, 1.0))
	var missing: float = 1.0 - float(own["dur"]) / d.durability
	if bool(own["broken"]):
		missing = 1.0
	return roundi(float(d.price) * missing * REPAIR_FACTOR)


func system_repair_cost(system: String) -> int:
	var health: float = float(profile["systems"][system])
	return roundi(float(SYSTEM_REPAIR_PRICE[system]) * (1.0 - health / 100.0))


func total_repair_cost() -> int:
	var c: int = 0
	for id in profile["owned"]:
		c += part_repair_cost(String(id))
	for s in SYSTEM_REPAIR_PRICE:
		c += system_repair_cost(String(s))
	return c


func repair_part(id: String) -> bool:
	var c: int = part_repair_cost(id)
	if c <= 0 or money() < c:
		return false
	var d: PartDef = part(id)
	profile["money"] = money() - c
	profile["owned"][id] = {"dur": d.durability, "broken": false, "scratch": 0.0}
	save_profile()
	_act("repair_part", id)
	profile_changed.emit()
	return true


func repair_system(system: String) -> bool:
	var c: int = system_repair_cost(system)
	if c <= 0 or money() < c:
		return false
	profile["money"] = money() - c
	profile["systems"][system] = 100.0
	save_profile()
	_act("repair_system", system)
	profile_changed.emit()
	return true


## Repara tudo o que o dinheiro permitir, do mais barato ao mais caro. Devolve o total gasto.
func repair_all() -> int:
	var spent: int = 0
	_mute_actions = true
	var items: Array = []
	for id in profile["owned"]:
		var c: int = part_repair_cost(String(id))
		if c > 0:
			items.append({"kind": "part", "id": String(id), "cost": c})
	for s in SYSTEM_REPAIR_PRICE:
		var c2: int = system_repair_cost(String(s))
		if c2 > 0:
			items.append({"kind": "system", "id": String(s), "cost": c2})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["cost"]) < int(b["cost"]))
	for it in items:
		if money() < int(it["cost"]):
			continue
		var ok: bool = repair_part(String(it["id"])) if it["kind"] == "part" else repair_system(String(it["id"]))
		if ok:
			spent += int(it["cost"])
	_mute_actions = false
	if spent > 0:
		_act("repair_all", "")
	return spent


## Peca quebrada: comprar uma nova custa o preco cheio (alternativa ao reparo).
func buy_new_replacement(id: String) -> bool:
	var d: PartDef = part(id)
	if d == null or money() < d.price:
		return false
	profile["money"] = money() - d.price
	profile["owned"][id] = {"dur": d.durability, "broken": false, "scratch": 0.0}
	save_profile()
	_act("buy_new", id)
	profile_changed.emit()
	return true


## Executa uma acao de perfil pelo nome (o servidor usa isto para validar compras/reparos online).
func apply_action(action: String, arg: String) -> bool:
	match action:
		"buy_part":
			var d: PartDef = part(arg)
			return d != null and buy(d)
		"install":
			return install(arg)
		"uninstall":
			uninstall(arg)
			return true
		"sell":
			sell(arg)
			return true
		"buy_mech":
			return buy_mech(arg)
		"install_mech":
			return install_mech(arg)
		"repair_part":
			return repair_part(arg)
		"repair_system":
			return repair_system(arg)
		"repair_all":
			return repair_all() > 0
		"buy_new":
			return buy_new_replacement(arg)
	return false


# ---------------------------------------------------------------- resultado da corrida

## Aplica o resultado: dinheiro, Fama, dano persistente (pecas e sistemas) e progresso da rota.
func apply_race_result(res: Dictionary, route_id: String, truck: TruckSim) -> void:
	profile["money"] = money() + int(res["pay"])
	profile["fame"] = fame() + int(res["fame"])
	for p in truck.loadout:
		var id: String = String(p["id"])
		if owns(id):
			var own: Dictionary = profile["owned"][id]
			own["dur"] = float(p["dur"])
			own["broken"] = bool(p["broken"])
	profile["systems"]["engine"] = float(truck.systems["engine"])
	profile["systems"]["steering"] = float(truck.systems["steering"])
	for d in installed_part_defs():          # murais (sem durabilidade) riscam a cada batida lateral
		if d.durability <= 0.0:
			var own2: Dictionary = profile["owned"][String(d.id)]
			own2["scratch"] = minf(float(own2["scratch"]) + 0.1 * float(truck.side_hits), 1.0)
	if route_id != "":
		var rec: Dictionary = (profile["routes_done"] as Dictionary).get(route_id, {})
		var t: float = float(res["time"])
		var won: bool = String(res.get("outcome", "win")) == "win"
		if won and (rec.is_empty() or t < float(rec.get("best_time", 1e9))):
			rec["best_time"] = t
		rec["best_position"] = mini(int(rec.get("best_position", 9)), int(res["position"]))
		if won:
			rec["won"] = true
		(profile["routes_done"] as Dictionary)[route_id] = rec
	if not pending_contract.is_empty() and String(res.get("outcome", "win")) != "win":
		pending_contract = {}                     # derrota: o contrato continua no quadro para tentar de novo
	if not pending_contract.is_empty():           # contrato concluido: historico + quadro novo
		var c: Dictionary = pending_contract.duplicate()
		c["paid"] = int(res["pay"])
		c["position"] = int(res["position"])
		var hist: Array = contracts_state()["done"]
		hist.push_front(c)
		if hist.size() > 10:
			hist.resize(10)
		refresh_contracts(false)
		pending_contract = {}
	last_result = res
	save_profile()
	profile_changed.emit()


func route_unlocked(r: RouteDef) -> bool:
	return fame() >= r.fame_required


func route_won(id: String) -> bool:
	return bool(((profile["routes_done"] as Dictionary).get(id, {}) as Dictionary).get("won", false))


# ---------------------------------------------------------------- contratos (Mercado de fretes)

## Estado salvo dos contratos: {"seed", "list", "done"} (cria se o perfil e antigo).
func contracts_state() -> Dictionary:
	if not profile.has("contracts") or not (profile["contracts"] is Dictionary):
		profile["contracts"] = {"seed": randi() % 1000000, "list": [], "done": []}
	return profile["contracts"]


## Quadro atual (gera se estiver vazio).
func contract_board() -> Array:
	var st: Dictionary = contracts_state()
	if (st["list"] as Array).is_empty():
		refresh_contracts(false)
	return st["list"]


## Sorteia um quadro novo (nova semente). `save` = gravar ja.
func refresh_contracts(save: bool = true) -> void:
	var st: Dictionary = contracts_state()
	st["seed"] = (int(st["seed"]) * 1103515245 + 12345) % 2147483647
	st["list"] = Contracts.generate(int(st["seed"]), FreightMarket.all_routes(), route_unlocked, String(profile.get("body", "base")))
	if save:
		save_profile()
		profile_changed.emit()


func capacity_t() -> float:
	return Contracts.capacity_t(String(profile.get("body", "base")))


## Motivo para nao poder aceitar ("" = pode).
func contract_block_reason(c: Dictionary) -> String:
	if float(c["weight_t"]) > capacity_t():
		return "BAÚ PEQUENO"
	if not bool(rival_refusal(String(c.get("route", ""))).get("ok", true)):
		return "RIVAL RECUSA"
	return ""


## O rival do trecho aceita o desafio? Exige Fama e destaque minimos. Devolve {ok, name, line, min_fame, min_destaque}.
## `line` e a fala curta de recusa (vazia se aceitou).
func rival_refusal(route_id: String) -> Dictionary:
	var rd: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef if ResourceLoader.exists("res://data/routes/%s.tres" % route_id) else null
	if rd == null or String(rd.rival_id) == "":
		return {"ok": true}
	var rv: RivalDef = load("res://data/rivals/%s.tres" % rd.rival_id) as RivalDef
	if rv == null:
		return {"ok": true}
	var ok: bool = fame() >= rv.min_fame and destaque() >= rv.min_destaque
	return {"ok": ok, "name": rv.display_name, "min_fame": rv.min_fame, "min_destaque": rv.min_destaque,
		"line": "" if ok else Tr.t(rv.refuse_key) if rv.refuse_key != "" else "..."}


## Aceita o contrato: a proxima corrida usa o trecho, o valor e a carga dele.
func accept_contract(c: Dictionary) -> void:
	pending_contract = c.duplicate()
	pending_route = load("res://data/routes/%s.tres" % c["route"]) as RouteDef
