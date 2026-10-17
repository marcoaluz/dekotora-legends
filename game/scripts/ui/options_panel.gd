class_name OptionsPanel
extends PanelContainer
## Tela de opcoes: categorias a esquerda, conteudo rolavel a direita e botao VOLTAR sempre visivel.
## Cabe em qualquer tela (960x540 base): nada fica fora da janela, o conteudo rola.

signal back_pressed
signal profile_changed

const CATEGORIES: Array = [["controls", "Controles"], ["graphics", "Gráficos"], ["audio", "Áudio"], ["account", "Conta"]]

var _s: Node
var _gs: Node
var _content: VBoxContainer
var _tabs: Dictionary = {}


func _ready() -> void:
	_s = get_node("/root/Settings")
	_gs = get_node("/root/GameState")
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 40.0
	offset_top = 28.0
	offset_right = -40.0
	offset_bottom = -28.0
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(UiTheme.label(Tr.t("options.title"), 34, UiTheme.PINK))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(190, 0)
	body.add_child(side)
	for c in CATEGORIES:
		var b: Button = UiTheme.menu_button(String(c[1]), Vector2(190, 48))
		b.add_theme_font_size_override("font_size", 20)
		var id: String = String(c[0])
		b.pressed.connect(func() -> void: _show(id))
		side.add_child(b)
		_tabs[id] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)
	var back: Button = UiTheme.button(Tr.t("menu.back"), Vector2(220, 48))
	back.pressed.connect(func() -> void: back_pressed.emit())
	root.add_child(back)
	_show("controls")


func _show(id: String) -> void:
	for c in _content.get_children():
		c.queue_free()
	for k in _tabs:
		(_tabs[k] as Button).add_theme_color_override("font_color", UiTheme.GOLD if k == id else UiTheme.TEXT)
	match id:
		"controls":
			_slider(Tr.t("options.touch_size"), _s.touch_scale, 0.7, 1.5, 0.05, func(v: float) -> void: _s.touch_scale = v, true)
			_hint("Troca de faixa: toque uma vez no lado para ligar a seta, toque de novo para trocar.")
		"graphics":
			_choice("Qualidade gráfica", ["Baixa", "Média", "Alta"], _s.quality, func(i: int) -> void: _s.quality = i)
			_hint("Baixa = mais FPS no celular; Alta = mais reflexos e luzes.")
			_toggle("Mostrar FPS na corrida", _s.show_fps, func(on: bool) -> void: _s.show_fps = on)
			_toggle(Tr.t("options.fx_speed"), _s.fx_speed, func(on: bool) -> void: _s.fx_speed = on)
			_toggle(Tr.t("options.fx_reflections"), _s.fx_reflections, func(on: bool) -> void: _s.fx_reflections = on)
			_toggle(Tr.t("options.fx_trails"), _s.fx_trails, func(on: bool) -> void: _s.fx_trails = on)
			_toggle(Tr.t("options.fx_rain"), _s.fx_rain, func(on: bool) -> void: _s.fx_rain = on)
			_hint(Tr.t("options.fx_hint"))
		"audio":
			_slider(Tr.t("options.music"), _s.music_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _s.music_volume = v, true)
			_slider(Tr.t("options.sfx"), _s.sfx_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _s.sfx_volume = v, true)
		"account":
			_account()


func _row_label(text: String) -> Label:
	var l: Label = UiTheme.label(text, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _hint(text: String) -> void:
	var l: Label = UiTheme.label(text, 15, UiTheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)


func _slider(text: String, value: float, lo: float, hi: float, step: float, apply: Callable, audio: bool = false) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_child(_row_label(text))
	var pct: Label = UiTheme.label("%d%%" % roundi(value * 100.0), 18, UiTheme.CYAN)
	head.add_child(pct)
	box.add_child(head)
	var hs := HSlider.new()
	hs.min_value = lo
	hs.max_value = hi
	hs.step = step
	hs.value = value
	hs.custom_minimum_size = Vector2(0, 34)
	hs.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		pct.text = "%d%%" % roundi(v * 100.0)
		_s.save_settings()
		if audio:
			AudioBus.apply_settings())
	box.add_child(hs)
	_content.add_child(box)


func _toggle(text: String, on: bool, apply: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = on
	cb.add_theme_font_size_override("font_size", 20)
	cb.custom_minimum_size = Vector2(0, 46)
	cb.toggled.connect(func(v: bool) -> void:
		apply.call(v)
		_s.save_settings())
	_content.add_child(cb)


func _choice(text: String, names: Array, selected: int, apply: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_row_label(text))
	var ob := OptionButton.new()
	for n in names:
		ob.add_item(String(n))
	ob.selected = selected
	ob.custom_minimum_size = Vector2(160, 44)
	ob.item_selected.connect(func(i: int) -> void:
		apply.call(i)
		_s.save_settings())
	row.add_child(ob)
	_content.add_child(row)


func _account() -> void:
	_hint("Código do jogador: use o mesmo código em outro aparelho para ter a mesma garagem.")
	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.text = String(_gs.profile["player_code"])
	edit.max_length = 12
	edit.custom_minimum_size = Vector2(220, 46)
	row.add_child(edit)
	var use: Button = UiTheme.button("USAR CÓDIGO", Vector2(170, 46))
	use.pressed.connect(func() -> void:
		var code: String = edit.text.strip_edges().to_upper()
		if code.length() >= 6 and code != String(_gs.profile["player_code"]):
			_gs.adopt_player_code(code)
			profile_changed.emit())
	row.add_child(use)
	_content.add_child(row)
	var reset: Button = UiTheme.button(Tr.t("options.reset"), Vector2(0, 46))
	reset.add_theme_color_override("font_color", UiTheme.BAD)
	var armed: Array = [false]                          # exige um segundo toque (nao apaga sem querer)
	reset.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			reset.text = "TOQUE DE NOVO PARA CONFIRMAR"
			return
		_gs.new_profile()
		profile_changed.emit())
	_content.add_child(reset)
