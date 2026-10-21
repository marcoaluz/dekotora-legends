extends TestCase
## T-177: aba DECORACAO da garagem. Secoes PECAS / PINTURA / LUZES / ADESIVOS numa barra fixa (fora da rolagem),
## encaixes logo no topo da secao PECAS, todos alcancaveis arrastando a lista, e a previa da peca so no toque
## parado (arrastar sobre o cartao nao abre previa).

const IN_TREE := true


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _open_garage() -> Node:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["money"] = 200000
	var scene: Node = (load("res://scenes/garage/garage.tscn") as PackedScene).instantiate()
	_root().add_child(scene)
	scene._set_tab("parts")
	_settle(scene)
	return scene


## O motor arruma os containers no proximo quadro; aqui forca o layout (de cima para baixo, algumas passadas).
func _settle(n: Node) -> void:
	for pass_i in 3:
		_sort(n)


func _sort(n: Node) -> void:
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_sort(c)


func _slot_buttons(box: Node) -> Array[Button]:
	var out: Array[Button] = []
	for b in box.find_children("Slot_*", "Button", true, false):
		out.append(b as Button)
	return out


func _inside_scroll(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _push(ev: InputEvent) -> void:
	_root().push_input(ev, true)


## Toque do Android: clique de mouse emulado + ScreenTouch.
func _touch(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	mb.position = pos
	mb.global_position = pos
	_push(mb)
	var st := InputEventScreenTouch.new()
	st.pressed = pressed
	st.position = pos
	_push(st)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	var prev: Vector2 = from
	for k in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(k) / float(steps))
		var mm := InputEventMouseMotion.new()
		mm.device = InputEvent.DEVICE_ID_EMULATION
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.position = p
		mm.global_position = p
		mm.relative = p - prev
		_push(mm)
		prev = p


func test_sections_bar_is_fixed_and_slots_come_first() -> void:
	var scene: Node = _open_garage()
	var gs: Node = _gs()
	var bar: HBoxContainer = scene._deco_bar
	check(bar.visible, "barra de secoes aparece na DECORACAO")
	check(not _inside_scroll(bar), "a barra fica fora da rolagem (sempre a mao)")
	check_eq(bar.get_child_count(), GarageDecoNav.SECTIONS.size(), "PECAS, PINTURA, LUZES, ADESIVOS")
	var left: VBoxContainer = scene._left
	check(left.get_child(0) is Label and left.get_child(1) is GridContainer, "PECAS: primeiro grupo de encaixes logo no topo")
	var slots: Array[Button] = _slot_buttons(left)
	check_eq(slots.size(), gs.slots().size(), "todos os encaixes estao na lista")
	for s in gs.slots():
		check(GarageDecoNav.area_of(String(s)) != "other", "encaixe %s tem lugar no caminhao" % s)
	scene._pick_slot("grille")
	check_eq(scene._slot, "grille", "tocar no encaixe abre as pecas")
	check(scene._right.find_child("PreviewTag", true, false) != null or gs.parts_for_slot("grille").is_empty()
			or scene._right.get_child_count() > 1, "painel direito mostra as pecas do encaixe")
	scene._set_deco("paint")
	check_eq(scene._slot, "", "trocar de secao fecha o encaixe")
	check(_slot_buttons(scene._left).is_empty(), "PINTURA nao mostra os encaixes")
	check(scene._left.find_children("*", "GridContainer", true, false).size() > 0, "PINTURA mostra as cores")
	scene._set_deco("decals")
	check(scene._left.get_child_count() > 2, "ADESIVOS mostra os cartoes de adesivo")
	scene._set_tab("mech")
	check(not scene._deco_bar.visible, "barra some fora da DECORACAO")
	scene._set_tab("parts")
	check_eq(scene._deco, "parts", "voltar a DECORACAO abre em PECAS")
	scene.free()


func test_touch_drag_reaches_last_slot() -> void:
	var scene: Node = _open_garage()
	var sc: ScrollContainer = scene._left.get_parent() as ScrollContainer
	check(sc is TouchScroll, "lista da esquerda rola pelo toque")
	var slots: Array[Button] = _slot_buttons(scene._left)
	var last: Button = slots[slots.size() - 1]
	var vis := Rect2(sc.global_position, sc.size)
	var start: Vector2 = vis.get_center()
	for k in 12:                                          # passadas de dedo de baixo para cima
		_touch(start, true)
		_drag(start, start + Vector2(0, -vis.size.y * 0.4), 8)
		_touch(start + Vector2(0, -vis.size.y * 0.4), false)
	var max_v: int = int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
	check(max_v > 0, "a lista e maior que a tela (da para testar a rolagem)")
	check_eq(sc.scroll_vertical, max_v, "arrastando chega ao fim da lista")
	_settle(scene)
	check(vis.grow(1.0).encloses(last.get_global_rect()), "o ultimo encaixe (%s) fica inteiro na tela" % last.name)
	check_eq(scene._slot, "", "arrastar nao abriu nenhum encaixe")
	scene.free()


func test_drag_over_part_card_does_not_preview_but_tap_does() -> void:
	var scene: Node = _open_garage()
	scene._pick_slot("front_bumper")
	_settle(scene)
	var card: Control = null
	for id in scene.shop.preview_cards:
		card = scene.shop.preview_cards[id]
		break
	check(card != null, "encaixe com cartao de peca para previa")
	if card == null:
		scene.free()
		return
	var r: Rect2 = card.get_global_rect()
	var p: Vector2 = r.position + Vector2(r.size.x * 0.5, 14)   # no titulo do cartao (fora dos botoes)
	_touch(p, true)
	_drag(p, p + Vector2(0, -40), 6)
	_touch(p + Vector2(0, -40), false)
	check(not scene.preview.active(), "arrastar sobre o cartao nao abre a previa")
	_settle(scene)
	r = card.get_global_rect()
	p = r.position + Vector2(r.size.x * 0.5, 14)
	(scene._right.get_parent() as TouchScroll)._stop()   # o embalo do arraste terminou
	_touch(p, true)
	_touch(p, false)
	check(scene.preview.active(), "toque parado no cartao abre a previa")
	scene.free()
