class_name EventHud
extends Control
## Track event warnings on the HUD (T-139), 480x270 layout like RaceHud (the CanvasLayer scales 2x):
##  - panel under the deadline: "ACIDENTE À FRENTE · 350 m", which lanes are closed (or which lane ends), the
##    works limit, the deadline allowance; red and blinking "SAIA DESTA FAIXA!" when the player's lane is closed ahead;
##  - "75 km/h! A CARGA ESTÁ SACUDINDO" beside the works above the limit (steel plates);
##  - "FAIXA FECHADA" beside the lane arrows when a lane change into a closed lane was refused.
## Everything comes from the simulation (TrackEvents, TruckSim): the same online (predicted truck) and offline.

signal alert_shown(kind: int)          # a new event entered the warning distance (sound / vibration)

const PANEL_W: float = 224.0
const KIND_COLORS: Array[Color] = [Color("#ff4b3e"), Color("#ff9a1a"), Color("#f5cc5a"), Color("#5ad1f5")]
const SECTION_SHOW_AFTER_M: float = 40.0   # T-153: the 2-lane warning stays until a little after the section begins
const BAD_COL := Color("#d1303f")

var sim: RaceSim
var player: int = 0
var _hf: Font
var _bf: Font
var _sb: StyleBoxFlat
var _shown: int = -1                    # index of the event whose alert is showing
var _shown_t: float = 0.0
var alert_cx: float = -1.0              # T-202: centre x / top of the warning panel (RaceHud layout; < 0 = old place)
var alert_top: float = 62.0
var refused_at := Vector2(-1, -1)       # T-202: centre top of the lane arrows ("lane closed" goes above them)


func bind(sim_: RaceSim, player_: int) -> void:
	sim = sim_
	player = player_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)
	_hf = UiTheme.heading_font(true)
	_bf = load(UiTheme.BODY_FONT) as Font
	_sb = UiTheme.box(Color(0.03, 0.04, 0.09, 0.72), Color(1, 1, 1, 0.12), 1, 5, 0)


## Event the player is approaching or inside (index), or -1.
func current_event() -> int:
	if sim == null or sim.trucks.is_empty() or sim.track.events.is_empty():
		return -1
	var t: TruckSim = sim.trucks[player]
	var nose: float = t.z + t.length
	var list: Array = sim.track.events.list
	for i in list.size():
		var ev: TrackEvents.Event = list[i]
		var until: float = ev.reopen_end() if ev.kind == TrackEvents.Kind.NARROW else ev.end_z()
		if ev.kind == TrackEvents.Kind.SECTION:
			until = ev.full_z() + SECTION_SHOW_AFTER_M
		if t.z <= until and ev.z - nose <= TrackEvents.WARN_M:
			return i
	return -1


## Lines of the warning panel for event `i` (title, detail).
func lines(i: int) -> PackedStringArray:
	var ev: TrackEvents.Event = sim.track.events.list[i]
	var title: String = Tr.t("hud.event." + TrackEvents.KIND_IDS[ev.kind])
	var lanes: String = Tr.t("hud.event.side.%d" % ev.lo) if ev.lo == ev.hi else Tr.t("hud.event.side.%d%d" % [ev.lo, ev.hi])
	var detail: String
	if ev.kind == TrackEvents.Kind.SECTION:
		detail = Tr.t("hud.event.section_detail", [roundi((ev.end_z() - ev.full_z()) / 10.0) * 10])
	elif ev.kind == TrackEvents.Kind.NARROW:
		detail = Tr.t("hud.event.lane_ends", [lanes])
	else:
		detail = Tr.t("hud.event.lane_closed" if ev.lo == ev.hi else "hud.event.lanes_closed", [lanes])
	if ev.kind == TrackEvents.Kind.WORKS:
		detail += "  ·  " + Tr.t("hud.event.limit", [int(TrackEvents.WORKS_LIMIT_KMH)])
	return PackedStringArray([title, detail])


func _process(delta: float) -> void:
	var i: int = current_event()
	if i != _shown:
		_shown = i
		_shown_t = 0.0
		if i >= 0:
			alert_shown.emit(sim.track.events.list[i].kind)
	_shown_t += delta
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.trucks.is_empty():
		return
	var t: TruckSim = sim.trucks[player]
	var w: float = size.x
	var blink: bool = int(Time.get_ticks_msec() / 180) % 2 == 0
	if _shown >= 0:
		_draw_alert(t, w, blink)
	_draw_plates(t, w, blink)
	if t.lane_refused_t > 0.0:
		var x: float = w * 0.5 + float(t.lane_refused_dir) * 58.0
		var y: float = size.y - 92.0
		if refused_at.x >= 0.0:
			x = refused_at.x + float(t.lane_refused_dir) * 24.0
			y = refused_at.y - 15.0
		var r := Rect2(x - 34, y, 68, 13)
		draw_style_box(_sb, r)
		draw_rect(Rect2(r.position.x, r.position.y + 2, 2, r.size.y - 4), BAD_COL)
		_text(Vector2(r.position.x, r.position.y + 10), Tr.t("hud.event.refused"), 9, BAD_COL if blink else Color.WHITE, r.size.x)


func _draw_alert(t: TruckSim, w: float, blink: bool) -> void:
	var ev: TrackEvents.Event = sim.track.events.list[_shown]
	var col: Color = KIND_COLORS[ev.kind]
	var nose: float = t.z + t.length
	var danger: bool = sim.track.events.lane_blocked_between(t.lane, t.z, nose + 220.0) and t.z < ev.end_z()
	var lns: PackedStringArray = lines(_shown)
	var h: float = 36.0 if danger else 26.0
	var cx: float = alert_cx if alert_cx >= 0.0 else w * 0.5
	var r := Rect2(cx - PANEL_W * 0.5, alert_top, PANEL_W, h)
	draw_style_box(_sb, r)
	var edge: Color = (BAD_COL if blink else Color.WHITE) if danger else col
	draw_rect(Rect2(r.position.x, r.position.y + 3, 3, r.size.y - 6), edge)
	# hazard diamond with "!"
	var c := Vector2(r.position.x + 14, r.position.y + 13)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]), col)
	draw_rect(Rect2(c.x - 1, c.y - 4.5, 2, 5), Color.BLACK)
	draw_rect(Rect2(c.x - 1, c.y + 2, 2, 2), Color.BLACK)
	var dist: float = ev.z - nose
	var dtxt: String = ("%d m" % int(maxf(dist, 0.0))) if dist > 0.0 else Tr.t("hud.event.now")
	_heading(Vector2(r.position.x + 26, r.position.y + 12), lns[0], 11, col)
	_heading(Vector2(r.position.x, r.position.y + 12), dtxt, 11, Color.WHITE, r.size.x - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(r.position.x + 26, r.position.y + 22), lns[1], 8, Color(1, 1, 1, 0.85))
	if danger:
		var merge: bool = ev.kind == TrackEvents.Kind.NARROW or ev.kind == TrackEvents.Kind.SECTION
		var msg: String = Tr.t("hud.event.merge" if merge else "hud.event.leave_lane")
		_heading(Vector2(r.position.x, r.position.y + 33), msg, 10, BAD_COL if blink else Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var extra: float = ev.allowance()
	if extra > 0.0 and _shown_t < 5.0 and sim.deadline > 0.0:
		var cr := Rect2(r.end.x - 62, r.end.y + 2, 62, 11)
		draw_style_box(_sb, cr)
		_text(Vector2(cr.position.x, cr.position.y + 8.5), Tr.t("hud.event.deadline", [int(extra)]), 7, Color("#3fb26f"), cr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Beside the works above the limit: speed in red, "the cargo is shaking".
func _draw_plates(t: TruckSim, w: float, blink: bool) -> void:
	var lim: float = sim.track.events.limit_at(t.z, t.z + t.length)
	if is_inf(lim) or t.speed <= lim + TrackEvents.LIMIT_TOL_KMH / 3.6:
		return
	var cx: float = alert_cx if alert_cx >= 0.0 else w * 0.5
	var r := Rect2(cx - 90, alert_top + 42.0, 180, 15)
	draw_style_box(_sb, r)
	draw_rect(Rect2(r.position.x, r.position.y + 2, 3, r.size.y - 4), BAD_COL)
	_heading(Vector2(r.position.x, r.position.y + 12), Tr.t("hud.event.plates", [roundi(t.speed * 3.6)]), 10,
		BAD_COL if blink else Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _heading(pos: Vector2, s: String, px: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_hf, pos + Vector2(0.6, 0.8), s, align, width, px, Color(0, 0, 0, 0.55))
	draw_string(_hf, pos, s, align, width, px, col)


func _text(pos: Vector2, s: String, px: int, col: Color, width: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_bf, pos, s, align, width, px, col)
