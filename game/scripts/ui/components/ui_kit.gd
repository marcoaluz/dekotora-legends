class_name UiKit
extends RefCounted
## Componentes de interface reutilizaveis (identidade visual "premium"): logo, titulos de tela com icone,
## botoes de navegacao com icone, botao principal rosa, botao VOLTAR, chip de saldo, linha de ficha tecnica.
## Cores e fontes vem de UiTheme. Icones: res://assets/ui/icons/<nome>.svg (Lucide, brancos).

const ICON_DIR := "res://assets/ui/icons/"


static func icon(name: String) -> Texture2D:
	var path: String = ICON_DIR + name + ".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Texto com a fonte de titulos (Rajdhani).
static func heading(text: String, size: int = 28, color: Color = UiTheme.TEXT, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.heading_font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _icon_rect(name: String, size: float, color: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon(name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.modulate = color
	return tr


## Logo do jogo: nome inclinado em branco/rosa, faixa rosa, subtitulo ciano e slogan.
static func logo(scale: float = 1.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(-10 * scale))
	var words: PackedStringArray = Tr.t("game.title").split(" ")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(14 * scale))
	for i in words.size():
		var l := Label.new()
		l.text = words[i]
		l.add_theme_font_override("font", UiTheme.heading_font(true, -0.22))
		l.add_theme_font_size_override("font_size", int(64 * scale))
		l.add_theme_color_override("font_color", Color.WHITE if i == 0 else UiTheme.PINK)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_y", 3)
		row.add_child(l)
	v.add_child(row)
	var sub := Label.new()
	sub.text = Tr.t("game.subtitle").to_upper()
	sub.add_theme_font_override("font", UiTheme.heading_font(true, -0.22))
	sub.add_theme_font_size_override("font_size", int(22 * scale))
	sub.add_theme_color_override("font_color", UiTheme.CYAN)
	v.add_child(sub)
	return v


## Titulo de tela: icone rosa + texto em caixa alta (ex.: casa + GARAGEM).
static func screen_title(text: String, icon_name: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_icon_rect(icon_name, 30, UiTheme.PINK))
	var l: Label = heading(text.to_upper(), 30)
	h.add_child(l)
	return h


## Item de navegacao com icone (menu principal, abas). Destaque = fundo rosa em degrade + barra a esquerda.
static func nav_button(text: String, icon_name: String, min_size: Vector2 = Vector2(330, 46)) -> Button:
	var b: Button = UiTheme.button(text.to_upper(), min_size)
	b.icon = icon(icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 21)
	var flat: StyleBoxFlat = UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 16)
	var hov: StyleBoxFlat = UiTheme.box(Color(1, 0.18, 0.53, 0.16), UiTheme.PINK, 0, 4, 16)
	hov.border_width_left = 4
	var prs: StyleBoxFlat = UiTheme.box(Color(1, 0.18, 0.53, 0.32), UiTheme.PINK, 0, 4, 16)
	prs.border_width_left = 4
	var dis: StyleBoxFlat = UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 16)
	for sb in [flat, hov, prs, dis]:                # altura compacta: a lista do menu cabe em 540 px
		(sb as StyleBoxFlat).content_margin_top = 3
		(sb as StyleBoxFlat).content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("disabled", dis)
	return b


## Botao de acao principal (rosa cheio): SELECIONAR, ACEITAR, PARTIR.
static func primary_button(text: String, icon_name: String = "", min_size: Vector2 = Vector2(200, 48)) -> Button:
	var b: Button = UiTheme.button(text.to_upper(), min_size)
	if icon_name != "":
		b.icon = icon(icon_name)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color("#e0186f"), Color(0, 0, 0, 0), 0, 8, 16))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("#ff2e88"), Color(1, 1, 1, 0.5), 1, 8, 16))
	b.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), Color.WHITE, 2, 8, 16))
	b.add_theme_stylebox_override("pressed", UiTheme.box(Color("#a8104f"), Color(0, 0, 0, 0), 0, 8, 16))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color(0.3, 0.1, 0.2, 0.6), Color(0, 0, 0, 0), 0, 8, 16))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


## Botao VOLTAR discreto (contorno + seta).
static func back_button(min_size: Vector2 = Vector2(150, 44)) -> Button:
	var b: Button = UiTheme.button(Tr.t("menu.back"), min_size)
	b.icon = icon("chevron-left")
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.05, 0.06, 0.11, 0.7), Color(1, 1, 1, 0.14), 1, 8, 14))
	return b


## Chip de saldo/fama (topo direito): icone + valor.
static func chip(icon_name: String, text: String, color: Color = UiTheme.TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.11, 0.75), Color(1, 1, 1, 0.1), 1, 18, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_icon_rect(icon_name, 18, UiTheme.CYAN))
	h.add_child(heading(text, 20, color, false))
	p.add_child(h)
	return p


## Linha da ficha tecnica: icone, rotulo pequeno em cima e valor em destaque embaixo.
static func stat_row(icon_name: String, label_text: String, value: String, value_color: Color = UiTheme.TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_icon_rect(icon_name, 22, Color(1, 1, 1, 0.75)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(UiTheme.label(label_text, 14, UiTheme.TEXT_DIM))
	v.add_child(heading(value, 22, value_color, false))
	h.add_child(v)
	return h


## Painel de vidro escuro com margens (base de todas as caixas).
static func glass_panel(alpha: float = 0.86) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.11, alpha), Color(1, 1, 1, 0.1), 1, 12, 16))
	return p


## Separador fino.
static func divider() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.08)
	c.custom_minimum_size = Vector2(0, 1)
	return c
