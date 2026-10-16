class_name UiTheme
extends RefCounted
## Tema visual dos menus: neon sobre noite (paleta do jogo). Cria StyleBoxFlat por codigo para ficar
## versionado. Base 960x540. Use `UiTheme.make()` e aplique em um Control raiz (`theme = ...`).

const NIGHT := Color("#0b0a14")
const NAVY := Color("#0d1426")                   # base: azul-marinho
const GRAPHITE := Color("#1b1f2a")               # base: grafite
const PANEL_BG := Color(0.05, 0.06, 0.11, 0.86)  # vidro escuro (transparencia moderada)
const PANEL_EDGE := Color(1, 1, 1, 0.1)
const HEADING_FONT := "res://assets/fonts/Rajdhani-Bold.ttf"
const HEADING_FONT_SEMI := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const BODY_FONT := "res://assets/fonts/ui_font.tres"
const PINK := Color("#ff2e88")
const CYAN := Color("#21e6ff")
const GOLD := Color("#f5cc5a")
const TEXT := Color("#e9eef5")
const TEXT_DIM := Color("#9aa3c0")
const GOOD := Color("#3fb26f")
const WARN := Color("#f5cc5a")
const BAD := Color("#d1303f")

static var _cached: Theme
static var _fonts: Dictionary = {}


## Fonte de titulos/botoes/numeros (Rajdhani) com reserva Noto Sans JP para japones e simbolos.
## `skew` inclina (logo); `bold` = Bold, senao SemiBold.
static func heading_font(bold: bool = true, skew: float = 0.0) -> Font:
	var key: String = "%s_%.2f" % [bold, skew]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = load(HEADING_FONT if bold else HEADING_FONT_SEMI) as Font
	fv.fallbacks = [load(BODY_FONT) as Font]
	if skew != 0.0:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(skew, 1), Vector2.ZERO)
	_fonts[key] = fv
	return fv


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


static func _disc(d: int, col: Color, ring: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: float = (d - 1) / 2.0
	for y in d:
		for x in d:
			var r: float = Vector2(x - c, y - c).length()
			var a: float = clampf(c + 0.5 - r, 0.0, 1.0)
			var col_px: Color = col
			if ring.a > 0.0 and r > c - 2.5:
				col_px = ring
			img.set_pixel(x, y, Color(col_px.r, col_px.g, col_px.b, col_px.a * a))
	return ImageTexture.create_from_image(img)


## Interruptor (pilula) 56x28: desligado = escuro; ligado = ciano com bolinha branca.
static func _switch(on: bool) -> ImageTexture:
	var w: int = 56
	var h: int = 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var fill: Color = Color("#1d9fb8") if on else Color(0.16, 0.16, 0.26)
	var kx: float = w - h / 2.0 if on else h / 2.0
	for y in h:
		for x in w:
			var cx: float = clampf(float(x), h / 2.0, w - h / 2.0)
			var d: float = Vector2(x - cx, y - (h - 1) / 2.0).length()
			var a: float = clampf(h / 2.0 + 0.5 - d, 0.0, 1.0)
			var col: Color = fill
			var kd: float = Vector2(x - kx, y - (h - 1) / 2.0).length()
			if kd < h / 2.0 - 3.0:
				col = Color.WHITE if on else Color(0.7, 0.72, 0.85)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


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
	t.set_font_size("font_size", "Button", 22)
	t.set_font("font", "Button", heading_font(false))
	t.set_font("font", "OptionButton", heading_font(false))
	t.set_font("font", "CheckButton", load(BODY_FONT) as Font)
	t.set_constant("h_separation", "Button", 12)
	t.set_constant("icon_max_width", "Button", 26)
	t.set_color("icon_normal_color", "Button", Color(1, 1, 1, 0.85))
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", PINK)
	t.set_color("icon_focus_color", "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.1, 0.2, 0.82), Color(1, 1, 1, 0.14), 1, 10))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.15, 0.3, 0.92), CYAN, 1, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.26, 0.08, 0.2, 1.0), PINK, 1, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.07, 0.12, 0.7), Color(1, 1, 1, 0.06), 1, 10))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2, 10))
	t.set_stylebox("panel", "PanelContainer", box(PANEL_BG, Color(1, 1, 1, 0.12), 1, 16, 14))
	t.set_stylebox("panel", "Panel", box(PANEL_BG, Color(1, 1, 1, 0.12), 1, 16, 14))
	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.04, 0.1, 0.9), Color(1, 1, 1, 0.16), 1, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.04, 0.1, 0.9), CYAN, 1, 10))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	# sliders: trilho fino + parte preenchida + bolinha visivel
	var track: StyleBoxFlat = box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 4, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill: StyleBoxFlat = box(CYAN, Color(0, 0, 0, 0), 0, 4, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	for sl in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", sl, track)
		t.set_stylebox("grabber_area", sl, fill)
		t.set_stylebox("grabber_area_highlight", sl, fill)
		t.set_icon("grabber", sl, _disc(30, Color.WHITE, CYAN))
		t.set_icon("grabber_highlight", sl, _disc(34, Color.WHITE, PINK))
		t.set_icon("grabber_disabled", sl, _disc(30, Color(0.5, 0.5, 0.6)))
	# interruptores
	for cb in ["CheckButton"]:
		t.set_icon("checked", cb, _switch(true))
		t.set_icon("unchecked", cb, _switch(false))
		t.set_icon("checked_disabled", cb, _switch(true))
		t.set_icon("unchecked_disabled", cb, _switch(false))
		t.set_stylebox("normal", cb, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("hover", cb, box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("pressed", cb, box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_stylebox("hover_pressed", cb, box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 6, 6))
		t.set_constant("h_separation", cb, 14)
	# listas suspensas e menu popup
	t.set_stylebox("panel", "PopupMenu", box(Color(0.06, 0.06, 0.14, 0.98), Color(1, 1, 1, 0.2), 1, 10, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.16, 0.2, 0.36), CYAN, 0, 6, 6))
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_constant("v_separation", "PopupMenu", 10)
	# barra de rolagem fina
	var sb_track: StyleBoxFlat = box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4, 0)
	var sb_grab: StyleBoxFlat = box(Color(1, 1, 1, 0.3), Color(0, 0, 0, 0), 0, 4, 0)
	var sb_grab_h: StyleBoxFlat = box(CYAN, Color(0, 0, 0, 0), 0, 4, 0)
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, sb_track)
		t.set_stylebox("grabber", sc, sb_grab)
		t.set_stylebox("grabber_highlight", sc, sb_grab_h)
		t.set_stylebox("grabber_pressed", sc, sb_grab_h)
	_cached = t
	return t


## Botao de menu principal: sem caixa, texto grande a esquerda; ao passar o mouse/foco aparece a barra rosa.
static func menu_button(text: String, min_size: Vector2 = Vector2(320, 54)) -> Button:
	var b: Button = button(text, min_size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	var flat: StyleBoxFlat = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 18)
	var hov: StyleBoxFlat = box(Color(1, 1, 1, 0.08), PINK, 0, 6, 18)
	hov.border_width_left = 4
	var prs: StyleBoxFlat = box(Color(1, 0.18, 0.53, 0.2), PINK, 0, 6, 18)
	prs.border_width_left = 4
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("pressed", prs)
	return b


## Botao padrao com altura minima boa para o dedo.
static func button(text: String, min_size: Vector2 = Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: AudioBus.play_ui("ui_back" if text == Tr.t("menu.back") else "ui_select"))
	return b


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
