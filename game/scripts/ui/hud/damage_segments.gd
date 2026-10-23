class_name DamageSegments
extends Control
## T-202: row of 5 segments under the gauge with the CURRENT state of the truck: front, left side, right side, rear,
## cargo/box. Green = ok, yellow = damaged, red = critical, dark = destroyed (HudStatus, from the per-part damage).
## Mouse over (PC) or a tap (phone) shows the detail of that segment (parts left, the system behind it). A segment
## that gets worse flashes for a moment. Local size HudLayout.SEG, scaled as a whole.

const SEG_GAP: float = 2.0
const SEG_H: float = 7.0
const PIN_S: float = 3.0                    # a tap keeps the detail this long
const FLASH_S: float = 1.2
const POP_W: float = 108.0

var truck: TruckSim
var hovered: int = -1
var pinned: int = -1
var _pin_t: float = 0.0
var _last: Array[int] = []
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = HudLayout.SEG
	mouse_exited.connect(func() -> void: hovered = -1)


func seg_width() -> float:
	return (HudLayout.SEG.x - SEG_GAP * 4.0) / 5.0


## Segment under local x, or -1.
func index_at(p: Vector2) -> int:
	if p.y < -3.0 or p.y > size.y + 3.0 or p.x < 0.0 or p.x > size.x:
		return -1
	return clampi(int(p.x / (seg_width() + SEG_GAP)), 0, 4)


## Segment whose detail is showing (-1 none).
func shown() -> int:
	return pinned if pinned >= 0 else hovered


func _gui_input(event: InputEvent) -> void:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		hovered = index_at(mm.position)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton      # a tap arrives as an emulated click
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		tap(index_at(mb.position))
		accept_event()


## Second finger on the screen (the 1st finger is emulated as the mouse, see _gui_input).
func _input(event: InputEvent) -> void:
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st == null or not st.pressed or st.index == 0 or not is_visible_in_tree():
		return
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * st.position
	if Rect2(Vector2.ZERO, size).has_point(local):
		tap(index_at(local))


## Keeps the detail of `i` open (debug screenshots, --hud-demo).
func pin(i: int) -> void:
	pinned = i
	_pin_t = PIN_S


func tap(i: int) -> void:
	if i < 0:
		return
	pinned = -1 if pinned == i else i
	_pin_t = PIN_S


func _process(delta: float) -> void:
	if pinned >= 0:
		_pin_t -= delta
		if _pin_t <= 0.0:
			pinned = -1
	if truck != null:
		var lv: Array[int] = HudStatus.levels(truck)
		for i in lv.size():
			if i < _last.size() and lv[i] > _last[i]:
				_flash[i] = FLASH_S
			_flash[i] = maxf(_flash[i] - delta, 0.0)
		_last = lv
	queue_redraw()


func _draw() -> void:
	if truck == null:
		return
	var sw: float = seg_width()
	var blink: bool = int(Time.get_ticks_msec() / 120) % 2 == 0
	draw_rect(Rect2(-2.0, -1.0, size.x + 4.0, size.y + 2.0), Color(0.01, 0.015, 0.035, 0.42))   # labels readable on white lines
	for i in 5:
		var seg: String = HudStatus.SEGMENTS[i]
		var lv: int = HudStatus.level(truck, seg)
		var r := Rect2(i * (sw + SEG_GAP), 1.0, sw, SEG_H)
		var col: Color = HudStyle.level_color(lv)
		draw_rect(r.grow(0.8), Color(0, 0, 0, 0.55))
		if lv == HudStatus.Level.DESTROYED:
			draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
			draw_line(r.position + Vector2(2, SEG_H - 1.5), r.end - Vector2(2, SEG_H - 1.5), Color(1, 1, 1, 0.16), 1.0)
		else:
			if _flash[i] > 0.0 and blink:
				col = Color.WHITE
			draw_rect(r, Color(col, 0.22))
			var fill: float = clampf(HudStatus.value(truck, seg), 0.08, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), col)
			draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.35), 1.0)
		if i == shown():
			draw_rect(r.grow(1.4), Color.WHITE, false, 1.0)
		var txt: String = Tr.t("hud.seg." + seg)          # centred by hand: a width limit would cut "FRENTE"
		var tw: float = HudStyle.text_width(txt, 6, false)
		var lp := Vector2(r.get_center().x - tw * 0.5, 15.5)
		HudStyle.lbl(self, lp + Vector2(0.5, 0.6), txt, 6, Color(0, 0, 0, 0.7))
		HudStyle.lbl(self, lp, txt, 6, Color(1, 1, 1, 0.85))
	if shown() >= 0:
		_popup(shown())


## Detail box above the row (inside the HUD: it opens to the left from the segment).
func _popup(i: int) -> void:
	var lines: PackedStringArray = HudStatus.detail(truck, HudStatus.SEGMENTS[i])
	var h: float = 6.0 + 9.0 * lines.size()
	var sx: float = i * (seg_width() + SEG_GAP) + seg_width() * 0.5
	var x: float = clampf(sx - POP_W * 0.5, minf(0.0, size.x - POP_W), maxf(0.0, size.x - POP_W))   # never past the row
	var r := Rect2(x, -h - 4.0, POP_W, h)
	var lv: int = HudStatus.level(truck, HudStatus.SEGMENTS[i])
	draw_rect(r, Color(0.01, 0.015, 0.035, 0.6))         # nearly opaque: it opens over the gauge
	HudStyle.panel(self, r, HudStyle.level_color(lv) if lv != HudStatus.Level.DESTROYED else Color(1, 1, 1, 0.4))
	for k in lines.size():
		var col: Color = Color.WHITE if k == 0 else Color(1, 1, 1, 0.82)
		if k == 1:
			col = HudStyle.level_color(lv) if lv != HudStatus.Level.DESTROYED else Color(1, 1, 1, 0.6)
		HudStyle.num(self, Vector2(r.position.x + 6.0, r.position.y + 10.0 + 9.0 * k), lines[k], 8 if k == 0 else 7, col)
