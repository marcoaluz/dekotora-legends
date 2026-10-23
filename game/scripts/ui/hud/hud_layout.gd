class_name HudLayout
extends RefCounted
## T-202: where each piece of the race HUD goes, in HUD units (the CanvasLayer scales 2x: 480x270 on a 16:9 PC,
## 600x270 on a 20:9 phone). Pure: give it the HUD size, the safe-area insets (notch), the touch flag, the wanted
## scale (DPI) and the touch buttons (TouchControls.button_layout); it fills the fields below. Tested headless.
##  PC:    radar on the left edge, position + camera icon top left, clocks top right, cluster bottom right
##         (arrows + lamps above the gauge, the 5 status segments below), like the original.
##  Phone: same pieces, bigger (DPI), inside the safe area; the cluster sits between the thumbs: gauge just left of
##         the brake button, arrows/lamps + segments beside it under the truck; nothing under a button.

const GAUGE: float = 84.0                  # gauge diameter with the bezel (local units)
const STRIP := Vector2(100, 24)            # arrows + lamps + lane dots
const SEG := Vector2(116, 17)              # 5 status segments + labels
const CLOCKS := Vector2(152, 72)
const POS := Vector2(74, 36)
const CAM := Vector2(26, 17)               # RaceCamButton.ICON_SIZE
const RADAR_W: float = 16.0
const MIRROR := Vector2(144, 42)           # RearMirror.RECT_SIZE
const EVENT_W: float = 224.0               # EventHud.PANEL_W
const NOTICE_W: float = 260.0
const M: float = 6.0                       # margin from the screen / safe-area edge
const GAP: float = 3.0
const TRUCK_HALF_W: float = 32.0           # the player's truck on screen (standard camera): centre column ...
const TRUCK_BOTTOM: float = 0.74           # ... down to this fraction of the height
const MIN_SCALE: float = 0.55

var size := Vector2(480, 270)
var inset_l: float = 0.0
var inset_t: float = 0.0
var inset_r: float = 0.0
var inset_b: float = 0.0
var touch: bool = false
var want_scale: float = 1.0
var buttons: Dictionary = {}               # TouchControls.button_layout(...) (touch only)

# results
var s: float = 1.0                         # top panels and radar
var clocks_s: float = 1.0
var cluster_s: float = 1.0
var pos_at := Vector2.ZERO
var cam_at := Vector2.ZERO
var radar := Rect2()
var clocks_at := Vector2.ZERO
var gauge_at := Vector2.ZERO
var strip_at := Vector2.ZERO
var seg_at := Vector2.ZERO
var mirror_top: float = M
var event_cx: float = 240.0
var event_top: float = 54.0
var notice_y: float = 78.0
var refused_at := Vector2.ZERO
var curve_y: float = 122.0


## Wanted HUD scale from the screen: 1 on a PC; on a touch screen it grows when the screen is physically small
## (a 6,5" phone is ~2,7" tall in landscape: x1,25). `px_h` = screen height in pixels (landscape), `dpi` = its DPI.
static func scale_for(touch_: bool, px_h: float, dpi: float) -> float:
	if not touch_ or dpi <= 0.0 or px_h <= 0.0:
		return 1.0
	var inches: float = px_h / dpi
	return clampf(3.4 / inches, 1.0, 1.25)


func compute() -> HudLayout:
	var w: float = size.x
	var h: float = size.y
	s = clampf(want_scale, MIN_SCALE, 1.6)
	pos_at = Vector2(inset_l + M, inset_t + M)
	cam_at = Vector2(pos_at.x, pos_at.y + POS.y * s + 4.0)
	mirror_top = inset_t + M
	_place_clocks(w)
	if touch:
		_place_cluster_touch(w, h)
	else:
		_place_cluster_pc(w, h)
	var r_top: float = cam_at.y + CAM.y * s + 6.0
	var r_bottom: float = h - inset_b - 10.0
	if not touch:
		r_bottom = minf(r_bottom, h - inset_b - M)
	var rx := Vector2(inset_l + M + 2.0, inset_l + M + 2.0 + RADAR_W * s)
	r_bottom = minf(r_bottom, _free_bottom(rx.x, rx.y, r_top, r_bottom))
	radar = Rect2(rx.x, r_top, RADAR_W * s, maxf(r_bottom - r_top, 20.0))
	# warnings in the middle: event panel under the mirror, moved left if it would touch the clocks
	event_top = mirror_top + MIRROR.y + 6.0
	var clocks_left: float = clocks_at.x
	event_cx = w * 0.5
	if event_cx + EVENT_W * 0.5 > clocks_left - 4.0 and event_top < clocks_at.y + CLOCKS.y * clocks_s:
		event_cx = maxf(clocks_left - 4.0 - EVENT_W * 0.5, inset_l + M + CAM.x * s + 6.0 + EVENT_W * 0.5)
	notice_y = event_top
	if w * 0.5 + NOTICE_W * 0.5 > clocks_left - 4.0:
		notice_y = maxf(notice_y, clocks_at.y + CLOCKS.y * clocks_s + 6.0)
	refused_at = strip_at + Vector2(STRIP.x * 0.5, -2.0) * cluster_s
	curve_y = h * 0.45
	return self


func clocks_rect() -> Rect2:
	return Rect2(clocks_at, CLOCKS * clocks_s)


func gauge_rect() -> Rect2:
	return Rect2(gauge_at, Vector2(GAUGE, GAUGE) * cluster_s)


func strip_rect() -> Rect2:
	return Rect2(strip_at, STRIP * cluster_s)


func seg_rect() -> Rect2:
	return Rect2(seg_at, SEG * cluster_s)


func mirror_rect() -> Rect2:
	return Rect2(size.x * 0.5 - MIRROR.x * 0.5, mirror_top, MIRROR.x, MIRROR.y)


## Rects that must stay clear of the touch buttons (tests).
func cluster_rects() -> Array[Rect2]:
	return [gauge_rect(), strip_rect(), seg_rect()]


func _place_clocks(w: float) -> void:
	clocks_s = s
	var mr: Rect2 = Rect2(w * 0.5 - MIRROR.x * 0.5, mirror_top, MIRROR.x, MIRROR.y)
	while true:
		clocks_at = Vector2(w - inset_r - M - CLOCKS.x * clocks_s, inset_t + M)
		var r := Rect2(clocks_at, CLOCKS * clocks_s)
		if (not r.grow(2.0).intersects(mr) and _clear(r)) or clocks_s <= MIN_SCALE:
			break
		clocks_s -= 0.05


func _place_cluster_pc(w: float, h: float) -> void:
	cluster_s = s
	var cs: float = cluster_s
	var right: float = w - inset_r - M
	var bottom: float = h - inset_b - M
	var bw: float = maxf(STRIP.x, SEG.x) * cs
	seg_at = Vector2(right - SEG.x * cs, bottom - SEG.y * cs)
	gauge_at = Vector2(right - bw * 0.5 - GAUGE * cs * 0.5, seg_at.y - GAP * cs - GAUGE * cs)
	strip_at = Vector2(right - STRIP.x * cs, gauge_at.y - GAP * cs - STRIP.y * cs)


## Gauge right next to the brake button, arrows/lamps over the segments on its left, everything clear of the
## buttons; the gauge stays right of the truck and the column under it. Shrinks until it fits.
func _place_cluster_touch(w: float, h: float) -> void:
	var strict: bool = true
	cluster_s = s
	while true:
		_arrange_touch(w, h, cluster_s)
		if _touch_ok(w, h, strict):
			return
		cluster_s -= 0.05
		if cluster_s < 0.7 and strict:
			strict = false                                # narrow screen: may cover the truck a little
			cluster_s = s
		elif cluster_s < MIN_SCALE:
			cluster_s = MIN_SCALE
			_arrange_touch(w, h, cluster_s)
			return


func _arrange_touch(w: float, h: float, cs: float) -> void:
	var right: float = w - inset_r - M
	for name in ["brake", "throttle"]:
		if buttons.has(name):
			var b: Dictionary = buttons[name]
			var c: Vector2 = b["center"]
			right = minf(right, c.x - float(b["radius"]) * TouchControls.HIT_MUL - 4.0)
	var bottom: float = h - inset_b - 4.0
	gauge_at = Vector2(right - GAUGE * cs, bottom - GAUGE * cs)
	var col_right: float = gauge_at.x - 4.0 * cs
	seg_at = Vector2(col_right - SEG.x * cs, bottom - SEG.y * cs)
	strip_at = Vector2(col_right - STRIP.x * cs, seg_at.y - GAP * cs - STRIP.y * cs)


func _touch_ok(w: float, h: float, strict: bool) -> bool:
	for r in cluster_rects():
		if not _clear(r) or r.position.x < inset_l + M:
			return false
	if not strict:
		return true
	var truck := Rect2(w * 0.5 - TRUCK_HALF_W, 0.0, TRUCK_HALF_W * 2.0, h * TRUCK_BOTTOM)
	for r in cluster_rects():
		if r.intersects(truck):
			return false
	return true


## True if `r` touches no touch button (hit circles).
func _clear(r: Rect2) -> bool:
	for name in buttons:
		var b: Dictionary = buttons[name]
		if _circle_hits_rect(b["center"], float(b["radius"]) * TouchControls.HIT_MUL, r):
			return false
	return true


## Lowest y the column x0..x1 can reach going down from `top` without entering a button.
func _free_bottom(x0: float, x1: float, top: float, bottom: float) -> float:
	var out: float = bottom
	for name in buttons:
		var b: Dictionary = buttons[name]
		var c: Vector2 = b["center"]
		var rr: float = float(b["radius"]) * TouchControls.HIT_MUL
		var dx: float = 0.0 if c.x >= x0 and c.x <= x1 else minf(absf(c.x - x0), absf(c.x - x1))
		if dx >= rr:
			continue
		var y_top: float = c.y - sqrt(rr * rr - dx * dx)
		if y_top > top:
			out = minf(out, y_top - 6.0)
	return out


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return q.distance_to(c) < r
