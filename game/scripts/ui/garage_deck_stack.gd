class_name GarageDeckStack
extends RefCounted
## Garagem (T-215): secao "2o NIVEL (EM CIMA)" no encaixe do deque. So aparece com um deque instalado que aceita peca em
## cima (caixa ou canhoes) e so lista as pecas que CABEM em cima dele neste caminhao (GameState.stack_candidates, mesma
## conta do teste de encaixe). Comprar, por em cima e tirar de cima.


static func build(box: VBoxContainer, gs: Node, flash: Callable) -> void:
	var low: String = gs.installed_id(DeckStack.LOWER_SLOT)
	if low == "" or gs.part(low) == null:
		return
	box.add_child(UiKit.heading(Tr.t("garage.stack_title"), 18, UiTheme.PINK))
	if not DeckStack.accepts_top(gs.part(low).accessory_id):
		box.add_child(GarageShop.wl(Tr.t("garage.stack_no_base"), 13, UiTheme.TEXT_DIM))
		return
	var cands: Array[PartDef] = gs.stack_candidates()
	if cands.is_empty():
		box.add_child(GarageShop.wl(Tr.t("garage.stack_none"), 13, UiTheme.TEXT_DIM))
		return
	box.add_child(GarageShop.wl(Tr.t("garage.stack_hint"), 13, UiTheme.TEXT_DIM))
	var top: String = gs.top_id() if gs.stack_ok() else ""
	var list := VBoxContainer.new()
	list.name = "StackCandidates"
	box.add_child(list)
	for d in cands:
		var id: String = String(d.id)
		var on: bool = id == top
		var cv: Array = GarageShop.card(UiTheme.PINK if on else Color(1, 1, 1, 0.1))
		var v: VBoxContainer = cv[1]
		v.add_child(GarageShop.wl(Tr.t("part." + id) + ("  ✔" if on else ""), 16, UiTheme.GOLD if on else UiTheme.TEXT))
		var row := HBoxContainer.new()
		v.add_child(row)
		if not gs.owns(id):
			var b: Button = GarageShop.small_button("%s  %s" % [Tr.t("garage.buy"), Tr.yen(d.price)], 150)
			b.disabled = gs.can_buy(d) != ""
			b.pressed.connect(func() -> void:
				if gs.buy(d):
					AudioBus.play_ui("ui_buy")
					flash.call(Tr.t("garage.bought", [Tr.t("part." + id)]))
				else:
					AudioBus.play_ui("ui_error"))
			row.add_child(b)
		elif on:
			var rm: Button = GarageShop.small_button(Tr.t("garage.stack_remove"), 150)
			rm.pressed.connect(func() -> void:
				AudioBus.play_ui("ui_select")
				gs.uninstall(DeckStack.SLOT))
			row.add_child(rm)
		else:
			var put: Button = GarageShop.small_button(Tr.t("garage.stack_put"), 150)
			put.name = "Put_" + id
			put.pressed.connect(func() -> void:
				if gs.install_top(id):
					AudioBus.play_ui("ui_select")
				else:
					AudioBus.play_ui("ui_error"))
			row.add_child(put)
		list.add_child(cv[0])
