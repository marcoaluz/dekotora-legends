class_name DuelBand
extends Control
## Overlay of the duel opening (T-156, redone in T-204), drawn in the HUD's 480x270 layout (parent CanvasLayer scale
## 2): fade from black, TV letterbox, the title 対決 slamming in, the bands of both drivers at the bottom (portrait,
## driver, truck, destaque), the lightning bolt with its single flash (or the soft violet glow with "reduce flashes"),
## the "tap to skip" hint and, online after a skip, "the start is in N s". Only drawing: DuelIntro feeds the clock.

const PINK := Color("#ff2e88")
const GOLD := Color("#f5cc5a")
const CYAN := Color("#21e6ff")
const BAR_H: float = 16.0
const BUST_BASE := "res://assets/textures/people/bust_base.png"      # T-186 (build_t186_props.py)
const BUST_SHIRT := "res://assets/textures/people/bust_shirt.png"
const TITLE_TEX := "res://assets/textures/duel/title_taiketsu.png"   # T-204 (tools_dev/make_duel_art.gd)
const NAME_SIZES: Array[int] = [16, 13, 11]                          # fixed sizes only (one glyph cache each)

## {driver, truck, crest, color, destaque, line}: [0] = player (left), [1] = rival (right).
var cards: Array[Dictionary] = []
var phase: String = ""              # "" = nothing of the opening on screen
var t_intro: float = 0.0            # intro clock (DuelPlan curves)
var reduced: bool = false           # "reduce flashes": no white flash
var bolt_from: Vector2 = Vector2.ZERO
var bolt_to: Vector2 = Vector2.ZERO
var letterbox: float = 0.0          # 0..1 (slides in/out)
var skip_hint: bool = true
var waiting: String = ""            # online after a skip: "the start is in N s"
var _hf: Font
var _bf: Font
var _jf: Font
var _bust_base: Texture2D
var _bust_shirt: Texture2D
var _title: Texture2D
var _bolt: Array[PackedVector2Array] = []
var _bolt_key: Vector4 = Vector4.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # the title texture is scaled
	_hf = UiTheme.heading_font(true)
	_bf = load(UiTheme.BODY_FONT) as Font
	_jf = load("res://assets/fonts/NotoSansJP.ttf") as Font
	if ResourceLoader.exists(TITLE_TEX):
		_title = load(TITLE_TEX) as Texture2D


func _process(_delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size / 2.0
	if size != want:
		size = want
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if phase != "":
		_bolt_layer(w, h)
		_title_layer(w, h)
		var slide: float = DuelPlan.bands_in(t_intro)
		if slide > 0.0:
			_band(0, slide, w, h)
			_band(1, slide, w, h)
	if letterbox > 0.0:
		var bh: float = BAR_H * letterbox
		draw_rect(Rect2(0, 0, w, bh), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, h - bh, w, bh), Color(0, 0, 0, 0.92))
		if skip_hint:
			_text(_bf, Vector2(0, h - bh + 12), Tr.t("intro.skip"), 9, Color(1, 1, 1, 0.6 * letterbox), HORIZONTAL_ALIGNMENT_RIGHT, w - 12)
	if phase != "":
		var soft: float = DuelPlan.soft_alpha(t_intro, reduced)
		if soft > 0.0:                                             # "reduce flashes": violet glow, never white
			draw_rect(Rect2(0, 0, w, h), Color(0.45, 0.3, 0.75, soft))
		var flash: float = DuelPlan.flash_alpha(t_intro, reduced)
		if flash > 0.0:                                            # ONE flash of 0.15 s at the strike
			draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, flash))
		var black: float = DuelPlan.black_alpha(t_intro)
		if black > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, black))
	if waiting != "":
		_shadowed(_hf, Vector2(0, h * 0.5), waiting, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)


func _text(f: Font, p: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(f, p, s, align, width, sz, col)


func _shadowed(f: Font, p: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(f, p + Vector2(0.8, 1.0), s, align, width, sz, Color(0, 0, 0, col.a * 0.7))
	draw_string(f, p, s, align, width, sz, col)


# ---------------------------------------------------------------- title 対決

func _title_layer(w: float, h: float) -> void:
	var st: Vector2 = DuelPlan.title_state(t_intro)
	if st.y <= 0.0 or _title == null:
		return
	var tw: float = minf(w * 0.3, 175.0)
	var th: float = tw * float(_title.get_height()) / float(_title.get_width())
	var c := Vector2(w * 0.5, h * 0.36)
	var d: float = t_intro - DuelPlan.phase_start("title")
	if d > 0.16 and d < 0.34 and not reduced:                     # the drum hit shakes the title a little
		c += Vector2(sin(d * 120.0), cos(d * 97.0)) * 2.0 * (1.0 - (d - 0.16) / 0.18)
	draw_set_transform(c, 0.0, Vector2(st.x, st.x))
	draw_texture_rect(_title, Rect2(-tw * 0.5, -th * 0.5, tw, th), false, Color(1, 1, 1, st.y))
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- lightning

func _bolt_layer(_w: float, _h: float) -> void:
	var bs: Vector2 = DuelPlan.bolt_state(t_intro, reduced)
	if bs.y <= 0.0:
		return
	var key := Vector4(bolt_from.x, bolt_from.y, bolt_to.x, bolt_to.y)
	if key.distance_to(_bolt_key) > 2.0 or _bolt.is_empty():         # the camera barely moves: rebuild only if needed
		_bolt = DuelBolt.paths(bolt_from, bolt_to)
		_bolt_key = key
	var lum: float = bs.y
	for i in _bolt.size():
		var line: PackedVector2Array = DuelBolt.grown(_bolt[i], bs.x if i == 0 else clampf((bs.x - 0.6) / 0.4, 0.0, 1.0))
		if line.size() < 2:
			continue
		var k: float = 1.0 if i == 0 else 0.55
		draw_polyline(line, Color(0.55, 0.35, 1.0, 0.22 * lum), 13.0 * k, true)
		draw_polyline(line, Color(0.8, 0.7, 1.0, 0.55 * lum), 5.0 * k, true)
		draw_polyline(line, Color(1, 1, 1, lum), 2.0 * k, true)
	if bs.x >= 1.0:                                                # glow where it hits the ground
		for r in [26.0, 16.0, 8.0]:
			draw_circle(bolt_to, r, Color(0.8, 0.7, 1.0, 0.18 * lum))


# ---------------------------------------------------------------- driver bands

## Band of card `i` (0 = player, bottom left; 1 = rival, bottom right). `slide` 0..1 = out..in place.
func _band(i: int, slide: float, w: float, h: float) -> void:
	if i >= cards.size():
		return
	var c: Dictionary = cards[i]
	var right: bool = i == 1
	var accent: Color = GOLD if right else PINK
	var bw: float = minf(190.0, w * 0.5 - 22.0)
	var x0: float = (w - bw - 10.0) if right else 10.0
	var off: float = (bw + 20.0) * (1.0 - slide)
	x0 += off if right else -off
	var r := Rect2(x0, h - BAR_H - 46.0, bw, 42)
	var skew: float = 9.0                                                           # slanted ribbon (parallelogram)
	var poly := PackedVector2Array([r.position + Vector2(skew, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(skew, 0), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(poly, Color(0.03, 0.02, 0.07, 0.84))
	draw_polyline(PackedVector2Array([poly[0], poly[1]]), accent, 2.0)
	draw_rect(Rect2(r.position.x + (r.size.x - 4.0 if right else 0.0), r.position.y + 5, 4, r.size.y - 10), accent)
	var col: Color = c.get("color", Color.WHITE)
	var pc := Vector2(r.end.x - 25.0, r.position.y + 21.0) if right else Vector2(r.position.x + 25.0, r.position.y + 21.0)
	_crest(pc, 15.0, col, String(c.get("crest", "")), accent, right)
	var tx: float = r.position.x + (14.0 if right else 48.0)
	var tw: float = bw - 62.0
	var al: int = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var name: String = String(c.get("driver", ""))
	_shadowed(_hf, Vector2(tx, r.position.y + 16), name, _name_size(name, tw), Color.WHITE, al, tw)
	_text(_jf, Vector2(tx, r.position.y + 27), String(c.get("truck", "")), 9, accent.lerp(Color.WHITE, 0.45), al, tw)
	var dest: String = "%s %d" % [Tr.t("intro.destaque"), int(c.get("destaque", 0))]
	_text(_bf, Vector2(tx, r.position.y + 37), dest, 8, CYAN, al, tw)


## Biggest of the fixed name sizes that fits `width`.
func _name_size(s: String, width: float) -> int:
	for sz in NAME_SIZES:
		if _hf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= width:
			return sz
	return NAME_SIZES[NAME_SIZES.size() - 1]


## Portrait square: T-186 the driver (bust of the standing man of the scenery library, PeopleKit) in a shirt of the
## truck's paint, facing the other band, with the crest kanji as a small badge; without the art, the crest circle.
func _crest(c: Vector2, r: float, col: Color, kanji: String, edge: Color, right: bool = false) -> void:
	var sq := Rect2(c - Vector2(r + 3, r + 3), Vector2(r + 3, r + 3) * 2.0)
	draw_rect(sq, Color(0, 0, 0, 0.6))
	if _bust_base == null and ResourceLoader.exists(BUST_BASE) and ResourceLoader.exists(BUST_SHIRT):
		_bust_base = load(BUST_BASE) as Texture2D
		_bust_shirt = load(BUST_SHIRT) as Texture2D
	if _bust_base != null:
		draw_rect(sq.grow(-1.0), col.darkened(0.55).lerp(Color(0.1, 0.1, 0.16), 0.4))
		var flip: bool = not right                          # the player (left) looks to the right
		draw_set_transform(sq.get_center(), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		var art := Rect2(-sq.size * 0.5 + Vector2(1, 1), sq.size - Vector2(2, 2))
		draw_texture_rect(_bust_base, art, false)
		draw_texture_rect(_bust_shirt, art, false, col.lerp(Color.WHITE, 0.08))
		DuelBust.features(self, art, col.lerp(Color.WHITE, 0.08))   # T-199: face, headband, collar (was a mannequin)
		draw_set_transform(Vector2.ZERO)
		draw_rect(sq, edge, false, 1.5)
		var b := Vector2(sq.position.x + 6.0, sq.end.y - 6.0) if right else Vector2(sq.end.x - 6.0, sq.end.y - 6.0)
		draw_circle(b, 6.0, col.darkened(0.15))
		draw_arc(b, 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 1.0)
		if kanji != "":
			_text(_jf, b + Vector2(-6.0, 3.5), kanji, 9, Color(0.08, 0.06, 0.1) if col.get_luminance() > 0.6 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 12.0)
		return
	draw_rect(sq, edge, false, 1.5)
	draw_circle(c, r, col.darkened(0.15))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 1.2)
	if kanji != "":
		var lum: float = col.get_luminance()
		_text(_jf, c + Vector2(-r, 7.0), kanji, 20, Color(0.08, 0.06, 0.1) if lum > 0.6 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
