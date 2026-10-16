class_name UiTheme
extends RefCounted
## Tema visual dos menus: neon sobre noite (paleta do jogo). Cria StyleBoxFlat por codigo para ficar
## versionado. Base 960x540. Use `UiTheme.make()` e aplique em um Control raiz (`theme = ...`).

const NIGHT := Color("#0b0a14")
const PANEL_BG := Color(0.06, 0.05, 0.14, 0.88)
const PANEL_EDGE := Color("#3c3a73")
const PINK := Color("#ff2e88")
const CYAN := Color("#21e6ff")
const GOLD := Color("#f5cc5a")
const TEXT := Color("#e9eef5")
const TEXT_DIM := Color("#9aa3c0")
const GOOD := Color("#3fb26f")
const WARN := Color("#f5cc5a")
const BAD := Color("#d1303f")

static var _cached: Theme


static func box(bg: Color, border: Color = PANEL_EDGE, border_w: int = 2, radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func make() -> Theme:
	if _cached != null:
		return _cached
	var t := Theme.new()
	t.set_default_font_size(18)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.6))
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.09, 0.22, 0.95), PANEL_EDGE))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.12, 0.32, 0.98), CYAN))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.08, 0.2, 1.0), PINK))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.07, 0.12, 0.8), Color(0.2, 0.2, 0.3)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2))
	t.set_stylebox("panel", "PanelContainer", box(PANEL_BG, PANEL_EDGE, 2, 8, 12))
	t.set_stylebox("panel", "Panel", box(PANEL_BG, PANEL_EDGE, 2, 8, 12))
	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.04, 0.1), PANEL_EDGE))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_icon("grabber", "HSlider", null)
	_cached = t
	return t


## Botao padrao com altura minima boa para o dedo.
static func button(text: String, min_size: Vector2 = Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	return b


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
