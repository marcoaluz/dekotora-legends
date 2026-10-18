class_name TouchControls
extends Control
## Botoes na tela para o celular: < > (esquerda), acelerar (grande), frear e Passing (direita).
## Multitoque: cada dedo guarda o botao em que comecou. Escreve em um LocalInput.
## Tamanho ajustavel por Settings.touch_scale; semitransparente para nao esconder a estrada.

const BTN_COLOR := Color(0.03, 0.04, 0.09, 0.42)     # vidro escuro (nao esconde a estrada)
const BTN_PRESSED := Color(1, 0.18, 0.53, 0.45)
const RING := Color(1, 1, 1, 0.45)

var target: LocalInput
var _buttons: Dictionary = {}      # nome -> {center: Vector2, radius: float}
var _fingers: Dictionary = {}      # indice do dedo -> nome do botao
var _labels: Dictionary = {"left": "", "right": "", "throttle": "GO", "brake": "FREIO", "passing": "P"}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_font = UiTheme.heading_font(true)
	get_viewport().size_changed.connect(layout)
	layout()


## Layout em unidades de 480 de altura 270 (o CanvasLayer pai escala 2x). A largura acompanha a tela
## (celular comprido = mais largo): os botoes da direita ficam presos na borda direita (T-138).
func layout() -> void:
	size = get_viewport_rect().size / 2.0 if is_inside_tree() else Vector2(480, 270)
	var s: float = Settings.touch_scale
	var w: float = size.x
	var h: float = size.y
	_buttons = {
		"left": {"center": Vector2(52, h - 50), "radius": 38.0 * s},
		"right": {"center": Vector2(146, h - 50), "radius": 38.0 * s},
		"throttle": {"center": Vector2(w - 55, h - 55), "radius": 40.0 * s},
		"brake": {"center": Vector2(w - 130, h - 32), "radius": 26.0 * s},
		"passing": {"center": Vector2(w - 48, h - 135), "radius": 24.0 * s},
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
		var on: bool = name in held
		draw_circle(c, r, BTN_PRESSED if on else BTN_COLOR)
		var ring: Color = UiTheme.PINK if name == "throttle" else (UiTheme.CYAN if name == "passing" else RING)
		draw_arc(c, r, 0.0, TAU, 40, ring if not on else Color.WHITE, 1.5 if name == "throttle" else 1.0, true)
		if name == "left" or name == "right":            # seta desenhada (chevron)
			var d: float = -1.0 if name == "left" else 1.0
			var k: float = r * 0.28
			draw_polyline(PackedVector2Array([c + Vector2(-d * k * 0.6, -k), c + Vector2(d * k * 0.6, 0), c + Vector2(-d * k * 0.6, k)]), Color(1, 1, 1, 0.9), 2.5, true)
			continue
		var text: String = _labels[name]
		var fs: int = 15 if name == "throttle" else 11
		var sz: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(_font, c + Vector2(-sz.x * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
