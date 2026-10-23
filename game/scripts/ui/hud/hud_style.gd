class_name HudStyle
extends RefCounted
## T-202: shared look of the race HUD (Art Truck Battle feel, our own drawing). Colours, the gauge backlight that
## follows the time of day (cool white by day, amber at night and in tunnels), glass panels and text helpers.
## Every component draws in its own local units and is scaled as a whole (HudLayout), so the font sizes here are
## fixed (each new font size would create a new glyph cache).

const PINK := Color("#ff2e88")
const CYAN := Color("#21e6ff")
const GOLD := Color("#f5cc5a")
const LABEL := Color(1, 1, 1, 0.66)
const OK_COL := Color("#38d46a")
const WARN_COL := Color("#f5cc5a")
const BAD_COL := Color("#ff3b3b")
const OFF_COL := Color(1, 1, 1, 0.10)
const ARROW_ON := Color("#3cff7a")         # green turn arrows, like the original
const ARROW_OFF := Color(0.24, 0.42, 0.30, 0.55)
const LAMP_OFF := Color(1, 1, 1, 0.16)
const BACK_DAY := Color("#dff2ff")         # gauge backlight by day (cool white)
const BACK_NIGHT := Color("#ffa53a")       # ... at night and in tunnels (amber)
const NEEDLE := Color("#ff4a1c")
const KANJI := Color("#ff7a3d")            # clock labels (orange-red, like the original)
const PANEL_BG := Color(0.02, 0.03, 0.07, 0.62)
const PANEL_EDGE := Color(1, 1, 1, 0.16)
const CHROME_HI := Color("#f4f7ff")
const CHROME_MID := Color("#8a93a8")
const CHROME_LO := Color("#262a36")

static var _hf: Font
static var _bf: Font


static func heading() -> Font:
	if _hf == null:
		_hf = UiTheme.heading_font(true)
	return _hf


static func body() -> Font:
	if _bf == null:
		_bf = load(UiTheme.BODY_FONT) as Font
	return _bf


## Backlight colour for `amber` 0 (day) .. 1 (night / tunnel).
static func backlight(amber: float) -> Color:
	return BACK_DAY.lerp(BACK_NIGHT, clampf(amber, 0.0, 1.0))


## Colour of a damage level (HudStatus.Level).
static func level_color(level: int) -> Color:
	match level:
		HudStatus.Level.OK:
			return OK_COL
		HudStatus.Level.DAMAGED:
			return WARN_COL
		HudStatus.Level.CRITICAL:
			return BAD_COL
	return OFF_COL


## Dark glass panel with a thin chrome edge and a light line on top (reflection).
static func panel(ci: CanvasItem, r: Rect2, accent: Color = Color(0, 0, 0, 0)) -> void:
	ci.draw_rect(r, PANEL_BG)
	ci.draw_rect(r, PANEL_EDGE, false, 1.0)
	ci.draw_line(r.position + Vector2(2, 1), Vector2(r.end.x - 2, r.position.y + 1), Color(1, 1, 1, 0.14), 1.0)
	if accent.a > 0.0:
		ci.draw_rect(Rect2(r.position.x, r.position.y + 3, 2, r.size.y - 6), accent)


## Heading text (Rajdhani) with a soft shadow.
static func num(ci: CanvasItem, pos: Vector2, text: String, px: int, col: Color = Color.WHITE,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(heading(), pos + Vector2(0.5, 0.7), text, align, width, px, Color(0, 0, 0, 0.6 * col.a))
	ci.draw_string(heading(), pos, text, align, width, px, col)


## Small label (Noto, also Japanese).
static func lbl(ci: CanvasItem, pos: Vector2, text: String, px: int = 7, col: Color = LABEL,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(body(), pos, text, align, width, px, col)


static func text_width(text: String, px: int, heading_font: bool = true) -> float:
	return (heading() if heading_font else body()).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## Soft glow behind a lit lamp: two translucent discs.
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r * 1.9, Color(col, 0.10 * col.a))
	ci.draw_circle(c, r * 1.3, Color(col, 0.18 * col.a))


## "M:SS" clock.
static func clock(seconds: float) -> String:
	var s: int = int(ceil(maxf(seconds, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]
