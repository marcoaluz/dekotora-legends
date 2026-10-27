class_name TouchControls
extends Control
## Botoes na tela para o celular: < > (esquerda) com a BUZINA entre eles e acima (como no original: seta · buzina · seta),
## acelerar (grande), frear e Passing (direita). A buzina fica do lado do polegar esquerdo, porque o direito segura o acelerador.
## Multitoque: cada dedo guarda o botao em que comecou. Escreve em um LocalInput.
## Tamanho ajustavel por Settings.touch_scale; semitransparente para nao esconder a estrada.
## T-241: botao OLHAR (olho, acima e a direita da seta direita): segurar = olhar para tras; deslizar o dedo para a
## esquerda/direita = olhar para aquele lado; soltar = volta. So a camera (escreve LocalInput.touch_look).

const BTN_COLOR := Color(0.03, 0.04, 0.09, 0.42)     # vidro escuro (nao esconde a estrada)
const BTN_PRESSED := Color(1, 0.18, 0.53, 0.45)
const RING := Color(1, 1, 1, 0.45)
const HIT_MUL: float = 1.25                         # hit area = radius x this (fat fingers)

var target: LocalInput
var _buttons: Dictionary = {}      # nome -> {center: Vector2, radius: float}
var _fingers: Dictionary = {}      # indice do dedo -> nome do botao
var _labels: Dictionary = {"left": "", "right": "", "throttle": "GO", "brake": "FREIO", "passing": "P", "horn": "BUZINA"}
var _font: Font
var _look_finger: int = -1         # T-241: finger holding the eye button (it never becomes another button)
var _look_from := Vector2.ZERO     # where that finger pressed
var _look_dir: int = 0             # RaceLook.Dir chosen by the slide
var _eye: Texture2D
var _short: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_font = UiTheme.heading_font(true)
	_labels["horn"] = Tr.t("touch.horn")
	_eye = UiKit.icon("eye")
	for id in ["back", "left", "right"]:
		_short[id] = Tr.t("look.short_" + id)
	get_viewport().size_changed.connect(layout)
	layout()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="):                    # T-241 screenshots: eye button shown held
			_look_dir = RaceLook.dir_from_id(arg.substr(7))
			if _look_dir != RaceLook.Dir.NONE:
				_look_finger = 99
				_fingers[99] = "look"


## Layout em unidades de 480 de altura 270 (o CanvasLayer pai escala 2x). A largura acompanha a tela
## (celular comprido = mais largo): os botoes da direita ficam presos na borda direita (T-138).
func layout() -> void:
	size = get_viewport_rect().size / 2.0 if is_inside_tree() else Vector2(480, 270)
	_buttons = button_layout(size, Settings.touch_scale)
	queue_redraw()


## Button geometry for a HUD of `hud_size` units and button scale `s` (T-202: the race HUD uses it to keep the
## gauge and the radar away from the thumbs). The hit area of each button is `radius * HIT_MUL`.
static func button_layout(hud_size: Vector2, s: float) -> Dictionary:
	var w: float = hud_size.x
	var h: float = hud_size.y
	return {
		"left": {"center": Vector2(52, h - 50), "radius": 38.0 * s},
		"right": {"center": Vector2(146, h - 50), "radius": 38.0 * s},
		"throttle": {"center": Vector2(w - 55, h - 55), "radius": 40.0 * s},
		"brake": {"center": Vector2(w - 130, h - 32), "radius": 26.0 * s},
		"passing": {"center": Vector2(w - 48, h - 135), "radius": 24.0 * s},
		"horn": {"center": Vector2(99, h - 50 - 70.0 * s), "radius": 22.0 * s},     # T-144: entre e acima das setas
		"look": {"center": Vector2(146 + 46.0 * s, h - 50 - 70.0 * s), "radius": 20.0 * s},   # T-241: acima/direita da seta >
	}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			var b: String = _hit(t.position, true)
			if b == "look":
				_look_finger = t.index
				_look_from = t.position
				_look_dir = RaceLook.Dir.BACK
			if b != "":
				_fingers[t.index] = b
		else:
			_fingers.erase(t.index)
			if t.index == _look_finger:
				_look_finger = -1
				_look_dir = RaceLook.Dir.NONE
		_apply()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = make_input_local(event) as InputEventScreenDrag
		if d.index == _look_finger:                    # T-241: the slide picks the side; it stays the eye button
			_look_dir = RaceLook.touch_dir(d.position.x - _look_from.x, float(_buttons["look"]["radius"]), _look_dir)
			_apply()
			return
		var b2: String = _hit(d.position, false)
		if b2 != "":
			_fingers[d.index] = b2
		else:
			_fingers.erase(d.index)
		_apply()


## Button under `p` (the eye button only when a finger lands on it: sliding into it does nothing).
func _hit(p: Vector2, allow_look: bool) -> String:
	var best: String = ""
	var best_d: float = 1e9
	for name in _buttons:
		if name == "look" and not allow_look:
			continue
		var d: float = p.distance_to(_buttons[name]["center"])
		if d <= float(_buttons[name]["radius"]) * HIT_MUL and d < best_d:
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
	target.touch_horn = "horn" in held
	target.touch_look = _look_dir if _look_finger >= 0 else RaceLook.Dir.NONE
	queue_redraw()


func _draw() -> void:
	var held: Array = _fingers.values()
	for name in _buttons:
		var c: Vector2 = _buttons[name]["center"]
		var r: float = _buttons[name]["radius"]
		var on: bool = name in held
		draw_circle(c, r, BTN_PRESSED if on else BTN_COLOR)
		var ring: Color = UiTheme.PINK if name == "throttle" else (UiTheme.CYAN if name == "passing" else (UiTheme.GOLD if name == "horn" else RING))
		draw_arc(c, r, 0.0, TAU, 40, ring if not on else Color.WHITE, 1.5 if name == "throttle" else 1.0, true)
		if name == "look":
			_draw_look(c, r, on)
			continue
		if name == "left" or name == "right":            # seta desenhada (chevron)
			var d: float = -1.0 if name == "left" else 1.0
			var k: float = r * 0.28
			draw_polyline(PackedVector2Array([c + Vector2(-d * k * 0.6, -k), c + Vector2(d * k * 0.6, 0), c + Vector2(-d * k * 0.6, k)]), Color(1, 1, 1, 0.9), 2.5, true)
			continue
		var text: String = _labels[name]
		var fs: int = 15 if name == "throttle" else (8 if name == "horn" else 11)
		var sz: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(_font, c + Vector2(-sz.x * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))


## T-241: eye icon; while held, the three choices around it (left · back above · right), the chosen one lit.
func _draw_look(c: Vector2, r: float, on: bool) -> void:
	if _eye != null:
		var k: float = r * 1.1
		draw_texture_rect(_eye, Rect2(c - Vector2(k, k) * 0.5, Vector2(k, k)), false, Color(1, 1, 1, 0.92))
	if not on:
		return
	var spots: Dictionary = {"left": c + Vector2(-r - 16.0, 0), "back": c + Vector2(0, -r - 9.0), "right": c + Vector2(r + 16.0, 0)}
	for id in spots:
		var lit: bool = RaceLook.IDS[_look_dir] == id
		var text: String = String(_short.get(id, id))
		var sz: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var p: Vector2 = spots[id]
		draw_rect(Rect2(p - Vector2(sz.x * 0.5 + 3.0, 6.5), Vector2(sz.x + 6.0, 12.0)), BTN_PRESSED if lit else BTN_COLOR)
		draw_string(_font, p + Vector2(-sz.x * 0.5, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color.WHITE if lit else Color(1, 1, 1, 0.6))
