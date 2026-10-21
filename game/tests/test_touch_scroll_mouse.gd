extends TestCase
## T-177: lista com TouchScroll no PC e no celular.
## Causa do defeito: o botao da garagem redesenha a lista no proprio clique (o botao sai da arvore no meio do
## "soltar"). O "soltar" nunca chegava ao ScrollContainer, que ficava preso em "arrastando": depois disso a lista
## seguia a seta do mouse SEM botao apertado e a roda do mouse era desfeita no movimento seguinte.

const IN_TREE := true

const ORIGIN := Vector2(100, 100)
const ROW_H: float = 60.0

var _pressed: Array[int] = []
var _box: VBoxContainer


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Lista de 10 botoes; `rebuild` = cada clique apaga e recria os botoes (como o _refresh da garagem).
func _make_list(rebuild: bool) -> TouchScroll:
	var sc := TouchScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.position = ORIGIN
	sc.size = Vector2(300, 200)
	_root().add_child(sc)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_box)
	_fill(sc, rebuild)
	return sc


func _fill(sc: ScrollContainer, rebuild: bool) -> void:
	for n in _box.get_children():
		_box.remove_child(n)
		n.queue_free()
	for i in 10:
		var b := Button.new()
		b.text = "slot %d" % i
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.pressed.connect(func() -> void:
			_pressed.append(i)
			if rebuild:
				_fill(sc, rebuild))
		_box.add_child(b)
	_layout(sc)


func _layout(sc: ScrollContainer) -> void:
	sc.get_minimum_size()
	sc.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_box.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _push(ev: InputEvent) -> void:
	_root().push_input(ev, true)


## Clique de mouse de verdade (PC); `emulated` = mouse emulado do toque (Android).
func _button(pos: Vector2, pressed: bool, emulated: bool = false) -> void:
	var mb := InputEventMouseButton.new()
	if emulated:
		mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	mb.position = pos
	mb.global_position = pos
	_push(mb)
	if emulated:
		var st := InputEventScreenTouch.new()
		st.pressed = pressed
		st.position = pos
		_push(st)


## Mouse andando de `from` a `to`; `held` = com o botao esquerdo apertado.
func _move(from: Vector2, to: Vector2, steps: int, held: bool, emulated: bool = false) -> void:
	var prev: Vector2 = from
	for k in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(k) / float(steps))
		var mm := InputEventMouseMotion.new()
		if emulated:
			mm.device = InputEvent.DEVICE_ID_EMULATION
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		mm.position = p
		mm.global_position = p
		mm.relative = p - prev
		_push(mm)
		if emulated:
			var sd := InputEventScreenDrag.new()
			sd.position = p
			sd.relative = p - prev
			_push(sd)
		prev = p


func _wheel(pos: Vector2, down: bool) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		mb.pressed = pressed
		mb.factor = 1.0
		mb.position = pos
		mb.global_position = pos
		_push(mb)


func _row(i: int) -> Vector2:
	return ORIGIN + Vector2(150, ROW_H * (i + 0.5))


func _with_touchscreen(body: Callable) -> void:
	var was: bool = Input.emulate_touch_from_mouse        # igual ao project.godot (emulate_touch_from_mouse=true)
	Input.emulate_touch_from_mouse = true
	body.call()
	Input.emulate_touch_from_mouse = was


func test_click_that_rebuilds_list_does_not_glue_list_to_mouse() -> void:
	_with_touchscreen(func() -> void:
		var sc: TouchScroll = _make_list(true)
		_pressed.clear()
		_button(_row(1), true)
		_button(_row(1), false)                           # o botao some no meio deste "soltar"
		check_eq(_pressed, [1] as Array[int], "o clique selecionou")
		var before: int = sc.scroll_vertical
		_move(_row(1), _row(1) + Vector2(0, -150), 10, false)   # mouse sem botao
		check_eq(sc.scroll_vertical, before, "mouse sem botao nao move a lista (estava em %d, foi a %d)" % [before, sc.scroll_vertical])
		_move(_row(1) + Vector2(0, -150), _row(1) + Vector2(0, 100), 10, false)
		check_eq(sc.scroll_vertical, before, "mouse sem botao nao move a lista, nem para baixo")
		sc.free())


func test_wheel_scrolls_and_sticks() -> void:
	_with_touchscreen(func() -> void:
		var sc: TouchScroll = _make_list(true)
		_button(_row(1), true)
		_button(_row(1), false)
		_wheel(_row(1), true)
		_wheel(_row(1), true)
		var after_wheel: int = sc.scroll_vertical
		check(after_wheel > 0, "a roda do mouse rola a lista (rolou %d)" % after_wheel)
		_move(_row(1), _row(2), 4, false)
		check_eq(sc.scroll_vertical, after_wheel, "mexer o mouse depois da roda nao desfaz a rolagem")
		_wheel(_row(1), false)
		check(sc.scroll_vertical < after_wheel, "roda para cima volta")
		sc.free())


func test_mouse_drag_with_button_scrolls_and_does_not_click() -> void:
	_with_touchscreen(func() -> void:
		var sc: TouchScroll = _make_list(true)
		_pressed.clear()
		_button(_row(2), true)
		_move(_row(2), _row(2) + Vector2(0, -130), 10, true)
		_button(_row(2) + Vector2(0, -130), false)
		check(sc.scroll_vertical > 80, "arrastar com o botao apertado rola (rolou %d)" % sc.scroll_vertical)
		check(_pressed.is_empty(), "arrastar nao clica (clicou %s)" % str(_pressed))
		var held: int = sc.scroll_vertical
		_move(_row(2), _row(2) + Vector2(0, 120), 8, false)
		check_eq(sc.scroll_vertical, held, "depois de soltar, o mouse sem botao nao mexe a lista")
		sc.free())


func test_mouse_drag_works_without_touchscreen() -> void:
	var was: bool = Input.emulate_touch_from_mouse        # PC sem tela de toque: arrastar tambem rola
	Input.emulate_touch_from_mouse = false
	var sc: TouchScroll = _make_list(false)
	_button(_row(2), true)
	_move(_row(2), _row(2) + Vector2(0, -100), 8, true)
	_button(_row(2) + Vector2(0, -100), false)
	check(sc.scroll_vertical > 50, "arrastar com o mouse rola mesmo sem tela de toque (rolou %d)" % sc.scroll_vertical)
	Input.emulate_touch_from_mouse = was
	sc.free()


func test_touch_reaches_end_of_long_list() -> void:
	# celular: varias passadas de dedo levam ate o ultimo item, mesmo com toques no meio que redesenham a lista
	_with_touchscreen(func() -> void:
		var sc: TouchScroll = _make_list(true)
		_pressed.clear()
		_button(_row(0), true, true)
		_button(_row(0), false, true)                     # toque que redesenha a lista
		for k in 6:
			_button(_row(2), true, true)
			_move(_row(2), _row(2) + Vector2(0, -110), 8, true, true)
			_button(_row(2) + Vector2(0, -110), false, true)
		var max_v: int = int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
		check_eq(sc.scroll_vertical, max_v, "chega ao fim da lista")
		_layout(sc)                                       # o motor reposiciona os itens no proximo quadro
		check_eq(_pressed, [0] as Array[int], "so o toque parado selecionou")
		var last: Control = _box.get_child(9) as Control
		var vis := Rect2(sc.global_position, sc.size)
		check(vis.encloses(last.get_global_rect()), "o ultimo item fica inteiro na tela")
		sc.free())


func test_tap_after_scroll_selects_the_item_under_finger() -> void:
	_with_touchscreen(func() -> void:
		var sc: TouchScroll = _make_list(false)
		_button(_row(2), true, true)
		_move(_row(2), _row(2) + Vector2(0, -120), 8, true, true)
		_button(_row(2) + Vector2(0, -120), false, true)
		for k in 120:                                     # 2 s: o embalo do dedo termina
			sc._process(1.0 / 60.0)
		check(not sc.scrolling(), "o embalo para sozinho")
		var off: int = sc.scroll_vertical
		_layout(sc)
		_pressed.clear()
		var p: Vector2 = _row(1)
		_button(p, true, true)
		_button(p, false, true)
		var expect: int = int((p.y - ORIGIN.y + off) / ROW_H)
		check_eq(_pressed, [expect] as Array[int], "toque rapido seleciona o item que esta sob o dedo")
		sc.free())
