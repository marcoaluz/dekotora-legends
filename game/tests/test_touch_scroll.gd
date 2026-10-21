extends TestCase
## T-165: rolar listas arrastando o dedo sobre os cartoes/botoes (celular) sem perder o toque-para-selecionar.
## Simula o que o Android entrega: ScreenTouch/ScreenDrag de verdade + o clique/movimento de mouse emulado
## (device = DEVICE_ID_EMULATION), na mesma ordem do Input do Godot (mouse emulado primeiro).

const IN_TREE := true

const ORIGIN := Vector2(100, 100)
const ROW_H: float = 60.0

var _pressed: Array[int] = []


## Lista de 10 botoes (60 de altura) numa janela de rolagem de 300x200 presa na raiz.
func _make_list(touch: bool) -> ScrollContainer:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var sc: ScrollContainer = TouchScroll.new() if touch else ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.position = ORIGIN
	sc.size = Vector2(300, 200)
	root.add_child(sc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	for i in 10:
		var b := Button.new()
		b.text = "card %d" % i
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.pressed.connect(func() -> void: _pressed.append(i))
		box.add_child(b)
	_layout(sc)
	return sc


func _layout(sc: ScrollContainer) -> void:
	sc.get_minimum_size()                              # calcula o tamanho do conteudo (o motor faz isso no proximo quadro)
	sc.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var box: Container = sc.get_child(0) as Container
	box.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _push(ev: InputEvent) -> void:
	(Engine.get_main_loop() as SceneTree).root.push_input(ev, true)


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
	st.index = 0
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
		var sd := InputEventScreenDrag.new()
		sd.index = 0
		sd.position = p
		sd.relative = p - prev
		_push(sd)
		prev = p


## Centro do cartao `i` na tela (sem rolagem).
func _card(i: int) -> Vector2:
	return ORIGIN + Vector2(150, ROW_H * (i + 0.5))


func _with_touchscreen(body: Callable) -> void:
	var was: bool = Input.emulate_touch_from_mouse        # o ScrollContainer so rola pelo toque se ha tela de toque
	Input.emulate_touch_from_mouse = true
	body.call()
	Input.emulate_touch_from_mouse = was


func test_drag_on_card_scrolls_and_does_not_select() -> void:
	_with_touchscreen(func() -> void:
		var sc: ScrollContainer = _make_list(true)
		_pressed.clear()
		_touch(_card(2), true)
		_drag(_card(2), _card(2) + Vector2(0, -120), 12)
		_touch(_card(2) + Vector2(0, -120), false)
		check(sc.scroll_vertical > 60, "arrastar sobre um cartao rola a lista (rolou %d)" % sc.scroll_vertical)
		check(_pressed.is_empty(), "arrastar nao seleciona o cartao (selecionou %s)" % str(_pressed))
		sc.free())


func test_tap_on_card_still_selects() -> void:
	_with_touchscreen(func() -> void:
		var sc: ScrollContainer = _make_list(true)
		_pressed.clear()
		_touch(_card(1), true)
		_drag(_card(1), _card(1) + Vector2(3, 4), 2)      # dedo treme um pouco: ainda e um toque
		_touch(_card(1) + Vector2(3, 4), false)
		check_eq(_pressed, [1] as Array[int], "tocar seleciona o cartao tocado")
		check_eq(sc.scroll_vertical, 0, "toque com tremida nao rola")
		sc.free())


func test_plain_scroll_container_had_the_bug() -> void:
	# documenta a causa: com o ScrollContainer comum o botao (STOP) segura o arraste e a lista nao rola
	_with_touchscreen(func() -> void:
		var sc: ScrollContainer = _make_list(false)
		_touch(_card(2), true)
		_drag(_card(2), _card(2) + Vector2(0, -120), 12)
		_touch(_card(2) + Vector2(0, -120), false)
		check_eq(sc.scroll_vertical, 0, "ScrollContainer comum nao rola arrastando sobre botao")
		sc.free())


func test_children_added_later_let_touch_pass() -> void:
	var sc: ScrollContainer = _make_list(true)
	var box: Container = sc.get_child(0) as Container
	var late := PanelContainer.new()                   # telas redesenham a lista: cartao criado depois
	var inner := Button.new()
	late.add_child(inner)
	box.add_child(late)
	var slider := HSlider.new()                        # slider tem arraste proprio: continua STOP
	box.add_child(slider)
	check_eq(late.mouse_filter, Control.MOUSE_FILTER_PASS, "cartao novo passa o toque")
	check_eq(inner.mouse_filter, Control.MOUSE_FILTER_PASS, "botao dentro do cartao novo passa o toque")
	check_eq(slider.mouse_filter, Control.MOUSE_FILTER_STOP, "slider continua STOP")
	check_eq(sc.mouse_filter, Control.MOUSE_FILTER_STOP, "a lista segura o toque (nao vaza para tras)")
	check_eq(sc.scroll_deadzone, TouchScroll.DEADZONE, "zona morta do toque")
	sc.free()


func test_keyboard_and_gamepad_still_select() -> void:
	# teclado/controle: foco no cartao + "ui_accept" (Enter / botao A) continua selecionando.
	# (clique de mouse real nao da para simular sem janela; o botao recebe o clique igual, so passa o resto adiante)
	var sc: ScrollContainer = _make_list(true)
	_pressed.clear()
	var card: Control = sc.get_child(0).get_child(4) as Control
	card.grab_focus()
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_accept"
		ev.pressed = down
		_push(ev)
	check_eq(_pressed, [4] as Array[int], "ui_accept no cartao com foco seleciona")
	sc.free()
