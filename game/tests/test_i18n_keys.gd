extends TestCase
## Textos-chave (T-138): o pt-BR.json carrega, nenhum texto esta vazio, toda chave citada no codigo existe e as
## familias montadas por codigo (pecas, encaixes, rotas, modelos, cabines, zonas, fundos do menu) tem texto.
## Chave ausente aparece na tela como "lobby.title" (Tr.t devolve a propria chave): este teste pega isso antes.

const I18N := "res://data/i18n/pt-BR.json"


func _dict() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(I18N))
	return parsed if parsed is Dictionary else {}


func _has(d: Dictionary, key: String) -> bool:
	return d.has(key) or (d.has(key + ".one") and d.has(key + ".many"))


func _scripts(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in DirAccess.get_directories_at(dir):
		_scripts(dir + sub + "/", out)


func test_json_loads_and_no_empty_text() -> void:
	var d: Dictionary = _dict()
	check(d.size() > 200, "pt-BR.json carrega (%d chaves)" % d.size())
	for k in d:
		check(String(d[k]).strip_edges() != "", "texto vazio: %s" % k)


## Toda string "prefixo.algo" no codigo, com um prefixo que o JSON usa, precisa existir (ex.: "lobby.title").
func test_every_key_in_code_exists() -> void:
	var d: Dictionary = _dict()
	var prefixes: Dictionary = {}
	for k in d:
		prefixes[String(k).get_slice(".", 0)] = true
	var re := RegEx.create_from_string("\"([a-z_]+(?:\\.[a-z_0-9]+)+)\"")
	var files: Array[String] = []
	_scripts("res://scripts/", files)
	var missing: PackedStringArray = []
	for f in files:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			var key: String = m.get_string(1)
			if key.ends_with("_"):                   # prefixo montado por codigo ("options.menu_bg_" + tipo): coberto abaixo
				continue
			if prefixes.has(key.get_slice(".", 0)) and not _has(d, key) and not key.get_extension() in ["gd", "tres", "png", "json", "glb", "tscn"]:
				missing.append("%s (%s)" % [key, f.get_file()])
	check(missing.is_empty(), "chaves usadas no codigo sem texto no pt-BR.json: %s" % ", ".join(missing))


## Familias montadas por codigo ("part." + id, "slot." + slot...): os dados reais precisam ter texto.
func test_data_families_have_text() -> void:
	var d: Dictionary = _dict()
	for f in DirAccess.get_files_at("res://data/parts/"):
		if f.ends_with(".tres"):
			var p: PartDef = load("res://data/parts/" + f) as PartDef
			check(_has(d, "part." + String(p.id)), "nome da peca: part.%s" % p.id)
			check(_has(d, "slot." + String(p.slot)), "nome do encaixe: slot.%s" % p.slot)
			for z in p.zones:
				check(_has(d, "zone." + z), "zona: zone.%s" % z)
	for f in DirAccess.get_files_at("res://data/routes/"):
		if f.ends_with(".tres"):
			var r: RouteDef = load("res://data/routes/" + f) as RouteDef
			check(_has(d, "route." + String(r.id)), "rota: route.%s" % r.id)
			check(_has(d, "scenery." + String(r.scenery)), "cenario: scenery.%s" % r.scenery)
	for f in DirAccess.get_files_at("res://data/rivals/"):
		if f.ends_with(".tres"):
			var rv: RivalDef = load("res://data/rivals/" + f) as RivalDef
			check(rv.display_name.strip_edges() != "", "rival %s tem nome" % rv.id)
	for b in ["canter", "leve", "base", "longo", "graneleira"]:
		check(_has(d, "body." + b), "modelo: body.%s" % b)
		check(_has(d, "body.desc." + b), "modelo: body.desc.%s" % b)
	for f in DirAccess.get_files_at("res://data/cargo/"):
		if f.ends_with(".tres"):
			var cg: CargoDef = load("res://data/cargo/" + f) as CargoDef
			check(_has(d, cg.display_key), "carga: %s" % cg.display_key)
	for k in ["reason.needs_box", "reason.needs_open", "reason.small_open", "market.needs.box", "market.needs.open",
			"garage.carries", "garage.carries.box", "garage.carries.open"]:
		check(_has(d, k), "carroceria x carga (T-145): %s" % k)
	for c in TruckNode.CABS:
		check(_has(d, "cab." + String(c)), "cabine: cab.%s" % c)
	for k in ["engine", "steering", "cargo"]:
		check(_has(d, "result.sys_" + k), "sistema no resultado: result.sys_%s" % k)
	for s in ["ok", "dent", "broken"]:
		check(_has(d, "part_state." + s), "estado da peca: part_state.%s" % s)
	for k in MenuBackdrop.KINDS:
		check(_has(d, "options.menu_bg_" + k), "fundo do menu: options.menu_bg_%s" % k)


## Tela de resultado: os 3 desfechos tem titulo proprio e frases sem chave crua nem "%" sobrando.
func test_result_texts_are_clear() -> void:
	var spec := RegEx.create_from_string("%[-+0-9.]*[dsf]")   # "%d"/"%s" que nao foi preenchido ("15% da carga" e legitimo)
	var titles: Dictionary = {}
	for kind in ["result", "result_lose", "result_timeout"]:
		var res: Dictionary = ResultScreen.demo_result(kind)
		var t: String = ResultText.title(res)
		titles[t] = true
		var all: Array[String] = [t]
		all.append_array(ResultText.lines(res))
		for line in all:
			check(line.strip_edges() != "", "%s: frase vazia" % kind)
			check(not line.contains("result.") and not line.contains("part_state."), "%s: chave crua na frase '%s'" % [kind, line])
			check(spec.search(line) == null, "%s: formato sobrando em '%s'" % [kind, line])
	check_eq(titles.size(), 3, "vitoria, derrota e tempo esgotado tem titulos diferentes")
	check_eq(ResultText.title(ResultScreen.demo_result("result")), "1º LUGAR", "titulo da vitoria")
	check(ResultText.lines(ResultScreen.demo_result("result_lose"))[0].contains("rival"), "derrota explica que o rival chegou antes")
	check(ResultText.lines(ResultScreen.demo_result("result_timeout"))[0].contains("prazo"), "tempo esgotado fala do prazo")
	check(ResultText.cargo_line(ResultScreen.demo_result("result"), true).contains("2 batidas"), "perda de carga diz quantas batidas")
	check_eq(ResultText.count(1, "result.hits"), "1 batida", "singular")
