extends Node2D
## Visualizador de camadas (P13): troca angulo, liga/desliga pecas e muda o estado de dano.
## Teclas: setas/A-D = angulo, 1..9 = liga/desliga peca, Q/W/E = todas ok/amassada/quebrada, +/- = zoom.

var _truck: TruckView
var _zoom: int = 2
var _toggles: Dictionary = {}
var _label: Label


func _ready() -> void:
	scale = Vector2(2, 2)   # layout legado em 480x270 sobre a base 960x540
	var bg := ColorRect.new()
	bg.color = Color(0.0431, 0.0392, 0.0784)
	bg.size = Vector2(480, 270)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var road := ColorRect.new()
	road.color = Color(0.1, 0.1, 0.12)
	road.position = Vector2(0, 215)
	road.size = Vector2(480, 55)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(road)
	_truck = TruckView.new()
	_truck.position = Vector2(240, 225)
	_truck.scale = Vector2(_zoom, _zoom)
	add_child(_truck)
	_build_ui()
	_update_label()


func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _build_ui() -> void:
	_label = Label.new()
	_label.position = Vector2(6, 4)
	_label.add_theme_font_size_override("font_size", 10)
	add_child(_label)
	_button("<", Vector2(6, 236), Vector2(30, 28), func() -> void: _step(-1))
	_button(">", Vector2(444, 236), Vector2(30, 28), func() -> void: _step(1))
	var y := 24.0
	for id in _truck.part_ids():
		var cb := CheckBox.new()
		cb.text = String(id)
		cb.button_pressed = true
		cb.position = Vector2(6, y)
		cb.add_theme_font_size_override("font_size", 9)
		cb.toggled.connect(func(on: bool) -> void: _truck.set_part_enabled(id, on))
		add_child(cb)
		_toggles[id] = cb
		y += 18.0
	var x := 330.0
	for st in TruckView.STATES:
		_button(st, Vector2(x, 4), Vector2(48, 20), func() -> void: _truck.set_all_states(st))
		x += 50.0
	_button("+", Vector2(300, 4), Vector2(22, 20), func() -> void: _set_zoom(_zoom + 1))
	_button("-", Vector2(274, 4), Vector2(22, 20), func() -> void: _set_zoom(_zoom - 1))


func _step(d: int) -> void:
	_truck.set_angle_index(_truck.angle_index() + d)
	_update_label()


func _set_zoom(z: int) -> void:
	_zoom = clampi(z, 1, 3)
	_truck.scale = Vector2(_zoom, _zoom)


func _update_label() -> void:
	_label.text = "Angulo: %s   (setas)" % _truck.angle


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("steer_left"):
		_step(-1)
	elif event.is_action_pressed("steer_right"):
		_step(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: _truck.set_all_states("ok")
			KEY_W: _truck.set_all_states("dent")
			KEY_E: _truck.set_all_states("broken")
			KEY_EQUAL, KEY_KP_ADD: _set_zoom(_zoom + 1)
			KEY_MINUS, KEY_KP_SUBTRACT: _set_zoom(_zoom - 1)
			_:
				var i: int = event.keycode - KEY_1
				var ids: Array = _truck.part_ids()
				if i >= 0 and i < ids.size():
					var cb: CheckBox = _toggles[ids[i]]
					cb.button_pressed = not cb.button_pressed
