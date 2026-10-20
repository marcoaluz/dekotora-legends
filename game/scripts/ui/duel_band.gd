class_name DuelBand
extends Control
## Overlay of the face-to-face opening (T-156), drawn in the HUD's 480x270 layout (parent CanvasLayer scale 2):
## TV letterbox, place caption, the band of each driver (crest, driver, truck, destaque, short taunt typed in),
## the Japanese-style VS banner (red ink splash, gold VS, 対決) and the "tap to skip" hint.
## Only drawing: DuelIntro tells which phase is on screen.

const PINK := Color("#ff2e88")
const GOLD := Color("#f5cc5a")
const CYAN := Color("#21e6ff")
const INK := Color("#c8102e")
const BAR_H: float = 22.0

## {driver, truck, crest, color, destaque, line}: [0] = player (left), [1] = rival (right).
var cards: Array[Dictionary] = []
var place: String = ""
var phase: String = ""
var progress: float = 0.0
var letterbox: float = 0.0          # 0..1 (slides in/out)
var skip_hint: bool = true
var waiting: String = ""            # online after a skip: "the start is in N s"
var _hf: Font
var _bf: Font
var _jf: Font
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)
	_hf = UiTheme.heading_font(true)
	_bf = load(UiTheme.BODY_FONT) as Font
	_jf = load("res://assets/fonts/NotoSansJP.ttf") as Font


func _process(delta: float) -> void:
	_t += delta
	var want: Vector2 = get_viewport_rect().size / 2.0
	if size != want:
		size = want
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if letterbox > 0.0:
		var bh: float = BAR_H * letterbox
		draw_rect(Rect2(0, 0, w, bh), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, h - bh, w, bh), Color(0, 0, 0, 0.92))
		if phase == "face" and place != "":
			_text(_bf, Vector2(12, bh - 7), place, 10, Color(1, 1, 1, 0.85 * letterbox))
		if skip_hint:
			_text(_bf, Vector2(0, h - bh + 14), Tr.t("intro.skip"), 9, Color(1, 1, 1, 0.6 * letterbox), HORIZONTAL_ALIGNMENT_RIGHT, w - 12)
	if waiting != "":
		_shadowed(_hf, Vector2(0, h * 0.5), waiting, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	match phase:
		"player":
			_band(0, progress, w, h)
		"rival":
			_band(1, progress, w, h)
		"vs":
			_vs(progress, w, h)


func _text(f: Font, p: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(f, p, s, align, width, sz, col)


func _shadowed(f: Font, p: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(f, p + Vector2(0.8, 1.0), s, align, width, sz, Color(0, 0, 0, col.a * 0.7))
	draw_string(f, p, s, align, width, sz, col)


## Band of card `i` (0 = player from the left, 1 = rival from the right): slides in, holds, the line types in.
func _band(i: int, p: float, w: float, h: float) -> void:
	if i >= cards.size():
		return
	var c: Dictionary = cards[i]
	var right: bool = i == 1
	var accent: Color = GOLD if right else PINK
	var bw: float = minf(300.0, w * 0.66)
	var slide: float = 1.0 - pow(1.0 - clampf(p / 0.18, 0.0, 1.0), 3.0)           # ease out
	var out: float = clampf((p - 0.92) / 0.08, 0.0, 1.0)                            # quick exit at the end
	var x0: float = (w - bw - 14.0) if right else 14.0
	var off: float = (bw + 20.0) * (1.0 - slide + out)
	x0 += off if right else -off
	var y0: float = h - BAR_H - 76.0
	var r := Rect2(x0, y0, bw, 68)
	var skew: float = 10.0                                                          # slanted ribbon (parallelogram)
	var poly := PackedVector2Array([r.position + Vector2(skew, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(skew, 0), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(poly, Color(0.03, 0.04, 0.09, 0.82))
	draw_polyline(PackedVector2Array([poly[0], poly[1]]), accent, 2.0)
	draw_rect(Rect2(r.position.x + (r.size.x - 4.0 if right else 0.0), r.position.y + 6, 4, r.size.y - 12), accent)
	var col: Color = c.get("color", Color.WHITE)
	var pc := Vector2(r.end.x - 34.0, r.position.y + 29.0) if right else Vector2(r.position.x + 34.0, r.position.y + 29.0)
	_crest(pc, 22.0, col, String(c.get("crest", "")), accent)
	var tx: float = r.position.x + (14.0 if right else 64.0)
	var tw: float = bw - 80.0
	var al: int = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	_shadowed(_hf, Vector2(tx, r.position.y + 19), String(c.get("driver", "")), 18, Color.WHITE, al, tw)
	_text(_jf, Vector2(tx, r.position.y + 31), String(c.get("truck", "")), 9, accent.lerp(Color.WHITE, 0.45), al, tw)
	var dest: String = "%s %d" % [Tr.t("intro.destaque"), int(c.get("destaque", 0))]
	_text(_bf, Vector2(tx, r.position.y + 42), dest, 8, CYAN, al, tw)
	var line: String = "“" + String(c.get("line", "")) + "”"
	var shown: int = int(clampf((p - 0.2) / 0.45, 0.0, 1.0) * float(line.length()))   # typed in
	var rows: PackedStringArray = wrap_lines(line, tw, 10)
	var used: int = 0
	for k in rows.size():
		var part: String = rows[k].substr(0, clampi(shown - used, 0, rows[k].length()))
		used += rows[k].length() + 1
		if part != "":
			_shadowed(_bf, Vector2(tx, r.position.y + 54 + 11.0 * float(k)), part, 10, Color(1, 1, 1, 0.95), al, tw)


## Breaks `text` into at most 2 lines that fit `width` (the band's taunt).
func wrap_lines(text: String, width: float, font_size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur: String = ""
	for word in text.split(" "):
		var tryit: String = word if cur == "" else cur + " " + word
		if cur != "" and _bf.get_string_size(tryit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and out.size() < 1:
			out.append(cur)
			cur = word
		else:
			cur = tryit
	out.append(cur)
	return out


## Crest in the portrait square: circle in the truck's paint with its kanji (no portrait art exists yet).
func _crest(c: Vector2, r: float, col: Color, kanji: String, edge: Color) -> void:
	draw_rect(Rect2(c - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(c - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2.0), edge, false, 1.5)
	draw_circle(c, r, col.darkened(0.15))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 1.2)
	draw_arc(c, r - 3.0, 0.0, TAU, 40, Color(0, 0, 0, 0.35), 1.0)
	if kanji != "":
		var lum: float = col.get_luminance()
		_text(_jf, c + Vector2(-r, 9.0), kanji, 26, Color(0.08, 0.06, 0.1) if lum > 0.6 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


## VS banner between the two trucks: red ink splash, gold VS hitting in (taiko), 対決 vertical, both names under.
func _vs(p: float, w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.44)
	var hit: float = clampf(p / 0.14, 0.0, 1.0)
	var k: float = lerpf(2.4, 1.0, 1.0 - pow(1.0 - hit, 3.0)) * (1.0 + 0.03 * sin(_t * 18.0) * (1.0 - hit))
	var fade: float = 1.0 - clampf((p - 0.88) / 0.12, 0.0, 1.0)
	var pts := PackedVector2Array()
	for n in 36:                                                                     # jagged brush edge
		var a: float = float(n) / 36.0 * TAU
		var rr: float = 46.0 * k * (1.0 + 0.13 * sin(a * 7.0 + 1.3) + 0.07 * sin(a * 13.0) + 0.05 * cos(a * 23.0))
		pts.append(c + Vector2(cos(a), sin(a) * 0.78) * rr)
	draw_colored_polygon(pts, Color(INK.r, INK.g, INK.b, 0.9 * fade))
	for s in 6:                                                                      # ink drops
		var a2: float = float(s) * 1.07 + 0.4
		draw_circle(c + Vector2(cos(a2), sin(a2) * 0.8) * 62.0 * k, (3.0 + float(s % 3)) * k, Color(INK.r, INK.g, INK.b, 0.85 * fade))
	var vs_size: int = int(54.0 * k)
	for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		_text(_hf, c + Vector2(-60.0, 18.0 * k) + o, "VS", vs_size, Color(0, 0, 0, fade), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	_text(_hf, c + Vector2(-60.0, 18.0 * k), "VS", vs_size, Color(GOLD.r, GOLD.g, GOLD.b, fade), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	for ch in 2:                                                                     # 対決 ("showdown"), vertical, left of VS
		var cp: Vector2 = c + Vector2(-66.0 * k, -10.0 + 22.0 * float(ch) * k)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_text(_jf, cp + o, "対決"[ch], int(18.0 * k), Color(0, 0, 0, fade))
		_text(_jf, cp, "対決"[ch], int(18.0 * k), Color(1, 1, 1, fade))
	if hit < 1.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.35 * (1.0 - hit)))             # flash on the drum hit
	if cards.size() >= 2:
		var y: float = c.y + 70.0
		_shadowed(_hf, Vector2(0, y), String(cards[0].get("driver", "")), 16, Color(PINK.r, PINK.g, PINK.b, fade), HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5 - 30.0)
		_shadowed(_hf, Vector2(w * 0.5 + 30.0, y), String(cards[1].get("driver", "")), 16, Color(GOLD.r, GOLD.g, GOLD.b, fade))
