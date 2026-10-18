class_name PauseMenu
extends Control
## Tela de pausa da corrida SEM escurecer a pista (ATB-1): icone, titulo e 3 blocos (continuar, revanche,
## desistir) + Configuracoes. Centralizada por containers (T-138; antes ficava presa em x = 150 da tela de 960).

signal resume_pressed
signal rematch_pressed
signal giveup_pressed
signal options_pressed

var first_button: Button


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	var ic := TextureRect.new()
	ic.texture = UiKit.icon("pause")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 40)
	col.add_child(ic)
	var title: Label = UiKit.heading(Tr.t("race.paused"), 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var tiles: Array = [
		[Tr.t("race.resume"), "play", resume_pressed],
		[Tr.t("race.rematch"), "rotate-ccw", rematch_pressed],
		[Tr.t("race.giveup"), "flag", giveup_pressed],
	]
	for t in tiles:
		var b: Button = UiTheme.button(String(t[0]), Vector2(150, 120))
		b.icon = UiKit.icon(String(t[1]))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_font_size_override("font_size", 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sig: Signal = t[2]
		b.pressed.connect(func() -> void: sig.emit())
		row.add_child(b)
		if first_button == null:
			first_button = b
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.22), UiTheme.PINK, 1, 10, 10))
	var opt: Button = UiTheme.button(Tr.t("menu.settings"), Vector2(220, 40))
	opt.pressed.connect(func() -> void: options_pressed.emit())
	opt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(opt)
