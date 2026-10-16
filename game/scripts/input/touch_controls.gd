class_name TouchControls
extends Control
## Botoes na tela para o celular: < > (esquerda), acelerar (grande), frear e Passing (direita).
## Multitoque: cada dedo guarda o botao em que comecou. Escreve em um LocalInput.
## Tamanho ajustavel por Settings.touch_scale; semitransparente para nao esconder a estrada.

const BTN_COLOR := Color(1, 1, 1, 0.22)
const BTN_PRESSED := Color(1, 0.18, 0.53, 0.45)

var target: LocalInput
var _buttons: Dictionary = {}      # nome -> {center: Vector2, radius: float}
var _fingers: Dictionary = {}      # indice do dedo -> nome do botao
var _labels: Dictionary = {"left": "<", "right": ">", "throttle": "GO", "brake": "FREIO", "passing": "P"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)
	layout()


func layout() -> void:
	var s: float = Settings.touch_scale
	_buttons = {
		"left": {"center": Vector2(46, 228), "radius": 30.0 * s},
		"right": {"center": Vector2(118, 228), "radius": 30.0 * s},
		"throttle": {"center": Vector2(425, 215), "radius": 40.0 * s},
		"brake": {"center": Vector2(350, 238), "radius": 26.0 * s},
		"passing": {"center": Vector2(432, 135), "radius": 24.0 * s},
	}
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			var b: String = _hit(t.position)
			if b != "":
				_fingers[t.index] = b
		else:
			_fingers.erase(t.index)
		_apply()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = make_input_local(event) as InputEventScreenDrag
		var b2: String = _hit(d.position)
		if b2 != "":
			_fingers[d.index] = b2
		else:
			_fingers.erase(d.index)
		_apply()


func _hit(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = 1e9
	for name in _buttons:
		var d: float = p.distance_to(_buttons[name]["center"])
		if d <= float(_buttons[name]["radius"]) * 1.25 and d < best_d:
			best = name
			best_d = d
	return best


func _apply() -> void:
	if target == null:
		return
	var held: Array = _fingers.values()
	target.touch_steer = (1.0 if "right" in held else 0.0) - (1.0 if "left" in held else 0.0)
	target.touch_throttle = 1.0 if "throttle" in held else 0.0
	target.touch_brake = 1.0 if "brake" in held else 0.0
	target.touch_passing = "passing" in held
	queue_redraw()


func _draw() -> void:
	var held: Array = _fingers.values()
	for name in _buttons:
		var c: Vector2 = _buttons[name]["center"]
		var r: float = _buttons[name]["radius"]
		draw_circle(c, r, BTN_PRESSED if name in held else BTN_COLOR)
		draw_arc(c, r, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0)
		var font: Font = ThemeDB.fallback_font
		var text: String = _labels[name]
		var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, c + Vector2(-sz.x * 0.5, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
