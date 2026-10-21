class_name FreecamTouch
extends Control
## Touch controls of the explorer camera (T-181): left stick = move, right stick = look, SOBE / DESCE held next to
## the right stick and a 4x toggle. Multi-touch: every finger keeps the zone it started in (like TouchControls),
## so you can move, look and climb at the same time. The camera reads `move`, `look`, `vertical` and `fast`.

const STICK_R: float = 72.0
const KNOB_R: float = 28.0
const DEADZONE: float = 0.12
const BTN_SIZE: Vector2 = Vector2(78, 58)
const GLASS := Color(0.03, 0.04, 0.09, 0.42)
const PRESSED := Color(1, 0.18, 0.53, 0.45)
const RING := Color(1, 1, 1, 0.45)

var move: Vector2 = Vector2.ZERO         # -1..+1 (x right, y down on screen = backwards)
var look: Vector2 = Vector2.ZERO
var vertical: float = 0.0                # +1 up, -1 down
var fast: bool = false
var _fingers: Dictionary = {}            # finger index -> zone name
var _knob: Dictionary = {}               # zone name -> local finger position
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.heading_font(true)


func _zones() -> Dictionary:
	var w: float = size.x
	var h: float = size.y
	var m: float = STICK_R + 30.0
	return {
		"move": Rect2(Vector2(m, h - m) - Vector2.ONE * STICK_R, Vector2.ONE * STICK_R * 2.0),
		"look": Rect2(Vector2(w - m, h - m) - Vector2.ONE * STICK_R, Vector2.ONE * STICK_R * 2.0),
		"up": Rect2(Vector2(w - m * 2.0 - BTN_SIZE.x - 10.0, h - 30.0 - BTN_SIZE.y * 2.0 - 10.0), BTN_SIZE),
		"down": Rect2(Vector2(w - m * 2.0 - BTN_SIZE.x - 10.0, h - 30.0 - BTN_SIZE.y), BTN_SIZE),
		"fast": Rect2(Vector2(m * 2.0 + 10.0, h - 30.0 - BTN_SIZE.y), BTN_SIZE),
	}


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			var z: String = _zone_at(t.position, false)
			if z == "fast":
				fast = not fast
			elif z != "":
				_fingers[t.index] = z
				_knob[z] = t.position
		else:
			var z2: String = String(_fingers.get(t.index, ""))
			_fingers.erase(t.index)
			_knob.erase(z2)
		_apply()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = make_input_local(event) as InputEventScreenDrag
		var z3: String = String(_fingers.get(d.index, ""))
		if z3 == "move" or z3 == "look":
			_knob[z3] = d.position                     # a stick keeps its finger even outside the circle
		elif z3 != "" and _zone_at(d.position, true) != z3:
			_fingers.erase(d.index)                     # slid off SOBE/DESCE: release
			_knob.erase(z3)
		_apply()


func _zone_at(p: Vector2, strict: bool) -> String:
	var zs: Dictionary = _zones()
	for z in zs:
		var r: Rect2 = zs[z]
		if (r if strict else r.grow(14.0)).has_point(p):
			return z
	return ""


func _apply() -> void:
	var zs: Dictionary = _zones()
	move = _stick(zs["move"], "move")
	look = _stick(zs["look"], "look")
	var held: Array = _fingers.values()
	vertical = (1.0 if "up" in held else 0.0) - (1.0 if "down" in held else 0.0)
	queue_redraw()


func _stick(r: Rect2, zone: String) -> Vector2:
	if not _knob.has(zone):
		return Vector2.ZERO
	var v: Vector2 = ((_knob[zone] as Vector2) - r.get_center()) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	return Vector2.ZERO if v.length() < DEADZONE else v


func _draw() -> void:
	var zs: Dictionary = _zones()
	for z in ["move", "look"]:
		var r: Rect2 = zs[z]
		draw_circle(r.get_center(), STICK_R, GLASS)
		draw_arc(r.get_center(), STICK_R, 0.0, TAU, 48, RING, 2.0)
		var v: Vector2 = move if z == "move" else look
		draw_circle(r.get_center() + v * (STICK_R - KNOB_R), KNOB_R, PRESSED if v != Vector2.ZERO else Color(1, 1, 1, 0.3))
	var held: Array = _fingers.values()
	for z in ["up", "down", "fast"]:
		var r2: Rect2 = zs[z]
		var on: bool = (z in held) or (z == "fast" and fast)
		draw_rect(r2, PRESSED if on else GLASS)
		draw_rect(r2, RING, false, 2.0)
		var text: String = Tr.t("freecam.touch_" + z)
		var fs: int = 18
		var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, r2.get_center() + Vector2(-tw / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
