class_name GarageDecals
extends RefCounted
## Secao ADESIVOS da aba DECORACAO da garagem (separada do GarageShop na T-138): um cartao por lugar
## (esquerda, direita, traseira, cabine) com adesivo, posicao, tamanho e cor. Grava no perfil pelo GameState.

var gs: Node
var live_decals: Callable      # func(decals: Array) -> void: mostra os adesivos no caminhao sem reconstruir a tela
var focus_view: Callable       # func(view: String) -> void: enquadra o caminhao no lugar do adesivo


func _init(gs_: Node, live_decals_: Callable, focus_view_: Callable) -> void:
	gs = gs_
	live_decals = live_decals_
	focus_view = focus_view_


const DECAL_VIEW: Dictionary = {"side_l": "side", "side_r": "side", "rear": "rear", "cab": "front"}


## Secao ADESIVOS da aba DECORACAO: um cartao por lugar (esq., dir., traseira, cabine) com adesivo, posicao, tamanho e cor.
func build(box: VBoxContainer) -> void:
	box.add_child(UiKit.heading(Tr.t("garage.decals").to_upper(), 18, UiTheme.PINK))
	box.add_child(GarageShop.wl(Tr.t("garage.decals_hint") % [StyleCatalog.DECAL_POINTS], 12, UiTheme.TEXT_DIM))
	var options: Array[String] = [""]
	options.append_array(DecalCatalog.ids())
	for slot in DecalCatalog.SLOTS:
		_decal_card(box, slot, options)


## Nome do adesivo para a tela: do pt-BR.json ("decal.<id>") ou, para PNG do proprio jogador (user://decals/),
## o nome do arquivo sem "_" ("meu_logo" -> "Meu Logo"). Nunca mostra o id cru.
static func decal_name(id: String) -> String:
	var key: String = "decal." + id
	var t: String = Tr.t(key)
	return t if t != key else id.replace("_", " ").replace(".", " ").capitalize()


func _commit_decals(decals: Array) -> void:
	gs.profile["decals"] = decals
	gs.save_profile()
	gs.profile_changed.emit()


func _decal_card(box: VBoxContainer, slot: String, options: Array[String]) -> void:
	var decals: Array = gs.profile.get("decals", []) as Array
	var idx: int = DecalCatalog.find(decals, slot)
	var cur: Dictionary = decals[idx] if idx >= 0 else {}
	var cur_id: String = String(cur.get("id", ""))
	var cv: Array = GarageShop.card(UiTheme.PINK if idx >= 0 else Color(1, 1, 1, 0.1))
	var v: VBoxContainer = cv[1]
	v.add_child(GarageShop.wl("%s: %s" % [Tr.t("decal.slot." + slot), decal_name(cur_id) if cur_id != "" else "— " + Tr.t("garage.empty")], 16, UiTheme.GOLD if idx >= 0 else UiTheme.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for dir in [-1, 1]:
		var b: Button = GarageShop.small_button("◀" if dir < 0 else "▶", 60)
		b.pressed.connect(func() -> void:
			var n: int = options.size()
			var pick: String = options[(options.find(cur_id) + dir + n) % n]
			var list: Array = (gs.profile.get("decals", []) as Array).duplicate(true)
			var i2: int = DecalCatalog.find(list, slot)
			if pick == "":
				if i2 >= 0:
					list.remove_at(i2)
			elif i2 >= 0:
				(list[i2] as Dictionary)["id"] = pick
			else:
				list.append(DecalCatalog.make(pick, slot))
			AudioBus.play_ui("ui_select")
			if focus_view.is_valid():
				focus_view.call(String(DECAL_VIEW[slot]))
			_commit_decals(list))
		row.add_child(b)
	if idx < 0:
		box.add_child(cv[0])
		return
	for spec in [["x", "garage.decal_x", -1.0, 1.0], ["y", "garage.decal_y", -1.0, 1.0], ["size", "garage.decal_size", 0.15, 1.1]]:
		var key: String = String(spec[0])
		v.add_child(GarageShop.wl(Tr.t(String(spec[1])), 12, UiTheme.TEXT_DIM))
		var sl := HSlider.new()
		sl.min_value = float(spec[2])
		sl.max_value = float(spec[3])
		sl.step = 0.02
		sl.value = float(cur.get(key, 0.0))
		sl.custom_minimum_size = Vector2(0, 22)
		sl.value_changed.connect(func(val: float) -> void:
			var list: Array = gs.profile.get("decals", []) as Array
			var i3: int = DecalCatalog.find(list, slot)
			if i3 >= 0:
				(list[i3] as Dictionary)[key] = val
				if live_decals.is_valid():
					live_decals.call(list))
		sl.drag_ended.connect(func(_changed: bool) -> void: _commit_decals(gs.profile.get("decals", []) as Array))
		v.add_child(sl)
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 5)
	colors.add_theme_constant_override("v_separation", 5)
	v.add_child(colors)
	for hex in DecalCatalog.COLORS:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(28, 28)
		var on: bool = String(cur.get("color", "#ffffff")).to_lower() == String(hex)
		cb.add_theme_stylebox_override("normal", UiTheme.box(Color(String(hex)), UiTheme.GOLD if on else Color(1, 1, 1, 0.3), 3 if on else 1, 6, 0))
		cb.add_theme_stylebox_override("hover", UiTheme.box(Color(String(hex)).lightened(0.2), UiTheme.PINK, 2, 6, 0))
		cb.pressed.connect(func() -> void:
			var list: Array = (gs.profile.get("decals", []) as Array).duplicate(true)
			var i4: int = DecalCatalog.find(list, slot)
			if i4 >= 0:
				(list[i4] as Dictionary)["color"] = String(hex)
				_commit_decals(list))
		colors.add_child(cb)
	box.add_child(cv[0])
