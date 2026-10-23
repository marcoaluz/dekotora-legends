class_name SpeedGauge
extends Control
## T-202: analog speedometer of the race HUD (bottom right), our own drawing with the Art Truck Battle feel.
## Round dial 0-140 km/h (numbers every 20, ticks every 10, red band 130-140, stop pin at 150), needle with light
## inertia and tremor (GaugeNeedle), chrome bezel, backlit numbers (cool white by day, amber at night / in tunnels),
## centre cap with the gear letter, small digital speed inside, RPM ring, draft lamp, turbo and Passing arcs on the
## bezel, the safe speed of the curve ahead and the works limit as marks on the scale. Glass + reflection when
## `fancy` (PC). Drawn in local units (HudLayout.GAUGE square) and scaled as a whole. Only reads values.

const R: float = 42.0                       # outer radius (bezel)
const FACE_R: float = 38.0
const NUM_R: float = 24.5
const FACE_EDGE := Color("#04060c")
const FACE_MID := Color("#121827")
const RED_FROM_KMH: float = 130.0

# state written by RaceHud every frame
var target_kmh: float = 0.0
var speed_ms: float = 0.0
var rpm_frac: float = 0.0
var gear: int = 1
var amber: float = 0.0                      # 0 day .. 1 night / tunnel
var boost: float = 0.0
var passing_charge: float = 0.0
var passing_active: bool = false
var draft: float = 0.0
var jolted: bool = false
var curve_safe_kmh: float = -1.0            # safe speed of the curve ahead (shown only with a curve warning)
var limit_kmh: float = -1.0                 # works limit beside the truck / ahead
var fancy: bool = true
var needle := GaugeNeedle.new()
var _was_jolted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(HudLayout.GAUGE, HudLayout.GAUGE)


func _process(delta: float) -> void:
	needle.step(delta, target_kmh, jolted and not _was_jolted)
	_was_jolted = jolted
	queue_redraw()


func _draw() -> void:
	var c := Vector2(R, R)
	var back: Color = HudStyle.backlight(amber)
	draw_circle(c + Vector2(1.2, 2.0), R + 0.5, Color(0, 0, 0, 0.38))     # drop shadow
	_bezel(c)
	_face(c, back)
	_scale_marks(c, back)
	_rpm_ring(c, back)
	_bottom_readout(c, back)
	_needle(c)
	_cap(c, back)
	if fancy:
		_glass(c)


func _bezel(c: Vector2) -> void:
	draw_circle(c, R, HudStyle.CHROME_LO)
	var n: int = 28
	for i in n:                                      # chrome ring lit from the top left
		var a: float = TAU * i / n
		var lit: float = 0.5 + 0.5 * cos(a - deg_to_rad(225.0))
		draw_arc(c, R - 1.6, a, a + TAU / n + 0.01, 3, HudStyle.CHROME_LO.lerp(HudStyle.CHROME_HI, lit * lit), 3.0)
	draw_arc(c, FACE_R + 0.4, 0.0, TAU, 48, Color(0, 0, 0, 0.9), 1.0)
	# turbo (left) and Passing (right) arcs in the bottom gap of the bezel
	var g0: float = deg_to_rad(36.0)
	var g1: float = deg_to_rad(144.0)
	var mid: float = deg_to_rad(90.0)
	draw_arc(c, R - 1.6, mid + 0.06, g1, 10, Color(0, 0, 0, 0.55), 2.6)
	draw_arc(c, R - 1.6, g0, mid - 0.06, 10, Color(0, 0, 0, 0.55), 2.6)
	if boost > 0.01:
		draw_arc(c, R - 1.6, g1 - (g1 - mid - 0.06) * clampf(boost, 0.0, 1.0), g1, 10, HudStyle.CYAN, 2.2)
	if passing_charge > 0.01:
		var pc: Color = HudStyle.PINK if passing_active else HudStyle.GOLD
		draw_arc(c, R - 1.6, g0, g0 + (mid - 0.06 - g0) * clampf(passing_charge, 0.0, 1.0), 10, pc, 2.2)


func _face(c: Vector2, back: Color) -> void:
	for i in 6:                                      # radial gradient: dark rim, lighter middle
		var f: float = float(i) / 5.0
		draw_circle(c, FACE_R - f * 26.0, FACE_EDGE.lerp(FACE_MID, f))
	var a0: float = GaugeNeedle.angle_for(0.0)
	var a1: float = GaugeNeedle.angle_for(GaugeNeedle.SCALE_MAX_KMH)
	draw_arc(c, NUM_R + 4.0, a0, a1, 40, Color(back, 0.07 + 0.05 * amber), 11.0)   # light behind the numbers
	draw_arc(c, FACE_R - 0.6, 0.0, TAU, 48, Color(back, 0.10 + 0.12 * amber), 1.2)


func _scale_marks(c: Vector2, back: Color) -> void:
	draw_arc(c, 35.4, GaugeNeedle.angle_for(RED_FROM_KMH), GaugeNeedle.angle_for(GaugeNeedle.SCALE_MAX_KMH), 6,
			Color(HudStyle.BAD_COL, 0.9), 2.4)
	var v: int = 0
	while v <= int(GaugeNeedle.SCALE_MAX_KMH):
		var d: Vector2 = Vector2.from_angle(GaugeNeedle.angle_for(float(v)))
		if v % 20 == 0:
			draw_line(c + d * 36.0, c + d * 30.6, back, 1.5)
			HudStyle.num(self, c + d * NUM_R + Vector2(-10.0, 3.0), str(v), 8, back, HORIZONTAL_ALIGNMENT_CENTER, 20.0)
		else:
			draw_line(c + d * 36.0, c + d * 33.0, Color(back, 0.75), 1.0)
		v += 10
	var pin: Vector2 = c + Vector2.from_angle(GaugeNeedle.angle_for(GaugeNeedle.STOP_KMH - 1.0)) * 34.0
	draw_circle(pin, 1.3, HudStyle.CHROME_MID)
	if curve_safe_kmh > 0.0 and curve_safe_kmh < GaugeNeedle.STOP_KMH:      # amber wedge = safe speed of the curve
		var ca: float = GaugeNeedle.angle_for(curve_safe_kmh)
		var dc := Vector2.from_angle(ca)
		var pc := Vector2.from_angle(ca + PI * 0.5)
		draw_colored_polygon(PackedVector2Array([c + dc * 31.0, c + dc * 37.6 + pc * 2.6, c + dc * 37.6 - pc * 2.6]), HudStyle.WARN_COL)
	if limit_kmh > 0.0:                              # works limit: red tick across the scale
		var dl := Vector2.from_angle(GaugeNeedle.angle_for(limit_kmh))
		draw_line(c + dl * 29.0, c + dl * 37.6, HudStyle.BAD_COL, 2.2)


func _rpm_ring(c: Vector2, back: Color) -> void:
	var a0: float = GaugeNeedle.angle_for(0.0)
	var span: float = deg_to_rad(GaugeNeedle.SWEEP_DEG)
	draw_arc(c, 17.5, a0, a0 + span, 32, Color(1, 1, 1, 0.07), 1.8)
	draw_arc(c, 17.5, a0 + span * 0.88, a0 + span, 6, Color(HudStyle.BAD_COL, 0.45), 1.8)
	var f: float = clampf(rpm_frac, 0.0, 1.0)
	if f > 0.01:
		draw_arc(c, 17.5, a0, a0 + span * f, 32, HudStyle.PINK if f > 0.88 else Color(HudStyle.CYAN, 0.85), 1.8)
	var dcol: Color = HudStyle.CYAN if draft > 0.1 else Color(back, 0.13)       # draft lamp
	HudStyle.lbl(self, c + Vector2(-16.0, -10.0), Tr.t("hud.draft"), 6, dcol, HORIZONTAL_ALIGNMENT_CENTER, 32.0)


func _bottom_readout(c: Vector2, back: Color) -> void:
	var kmh: int = roundi(speed_ms * 3.6)
	var col: Color = HudStyle.BAD_COL if jolted else Color.WHITE.lerp(back, 0.35)
	HudStyle.num(self, c + Vector2(-16.0, 23.0), str(kmh), 11, col, HORIZONTAL_ALIGNMENT_CENTER, 32.0)
	HudStyle.lbl(self, c + Vector2(-16.0, 29.5), "km/h", 6, Color(back, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 32.0)
	var tp: Vector2 = c + Vector2.from_angle(deg_to_rad(126.0)) * 33.0          # letters by the bezel arcs
	var pp: Vector2 = c + Vector2.from_angle(deg_to_rad(54.0)) * 33.0
	HudStyle.lbl(self, tp + Vector2(-4.0, 2.0), Tr.t("hud.turbo_short"), 6, Color(HudStyle.CYAN, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 8.0)
	HudStyle.lbl(self, pp + Vector2(-4.0, 2.0), Tr.t("hud.passing_short"), 6, Color(HudStyle.GOLD, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 8.0)


func _needle(c: Vector2) -> void:
	var a: float = GaugeNeedle.angle_for(needle.shown(rpm_frac))
	var d := Vector2.from_angle(a)
	var p := Vector2(-d.y, d.x)
	var tip: Vector2 = c + d * 33.0
	draw_colored_polygon(PackedVector2Array([tip + d * 1.0, c + p * 3.4, c - d * 8.0, c - p * 3.4]), Color(HudStyle.NEEDLE, 0.22))
	draw_colored_polygon(PackedVector2Array([tip, c + p * 1.9 - d * 1.0, c - d * 7.0 + p * 1.1, c - d * 7.0 - p * 1.1, c - p * 1.9 - d * 1.0]), HudStyle.NEEDLE)
	draw_line(c + d * 2.0, tip - d * 1.0, Color(1, 0.8, 0.6, 0.7), 0.6)


func _cap(c: Vector2, back: Color) -> void:
	draw_circle(c + Vector2(0.4, 0.8), 9.6, Color(0, 0, 0, 0.5))
	draw_circle(c, 9.2, HudStyle.CHROME_LO)
	var n: int = 16
	for i in n:
		var a: float = TAU * i / n
		var lit: float = 0.5 + 0.5 * cos(a - deg_to_rad(225.0))
		draw_arc(c, 8.4, a, a + TAU / n + 0.02, 2, HudStyle.CHROME_LO.lerp(HudStyle.CHROME_HI, lit), 1.6)
	draw_circle(c, 7.4, Color("#0b0e16"))
	var ring: Color = HudStyle.PINK if passing_active else Color(back, 0.35)
	draw_arc(c, 7.4, 0.0, TAU, 24, ring, 0.8)
	HudStyle.num(self, c + Vector2(-8.0, 4.0), GaugeNeedle.cap_letter(speed_ms, gear), 11, back, HORIZONTAL_ALIGNMENT_CENTER, 16.0)


## Glass: faint sheen over the face, a crescent reflection on the top left and a small highlight.
func _glass(c: Vector2) -> void:
	draw_circle(c, FACE_R, Color(1, 1, 1, 0.025))
	var outer := PackedVector2Array()
	var cols := PackedColorArray()
	var n: int = 14
	for i in n + 1:
		var a: float = deg_to_rad(192.0 + 118.0 * i / n)
		outer.append(c + Vector2.from_angle(a) * (FACE_R - 1.5))
		cols.append(Color(1, 1, 1, 0.16 * sin(PI * i / n) + 0.02))
	for i in range(n, -1, -1):
		var a2: float = deg_to_rad(192.0 + 118.0 * i / n)
		outer.append(c + Vector2(4.0, 7.0) + Vector2.from_angle(a2) * (FACE_R - 6.0))
		cols.append(Color(1, 1, 1, 0.0))
	draw_polygon(outer, cols)
	draw_circle(c + Vector2(-17.0, -21.0), 1.6, Color(1, 1, 1, 0.35))
	draw_arc(c, FACE_R - 2.0, deg_to_rad(20.0), deg_to_rad(70.0), 10, Color(1, 1, 1, 0.07), 1.2)
