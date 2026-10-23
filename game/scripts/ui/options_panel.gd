class_name OptionsPanel
extends PanelContainer
## Tela de opcoes: categorias a esquerda, conteudo rolavel a direita e botao VOLTAR sempre visivel.
## Presa aos 4 cantos com margem (960x540 e celular 20:9): nada fica fora da janela, o conteudo rola.
## Textos via Tr.t (game/data/i18n/pt-BR.json).

signal back_pressed
signal profile_changed
signal menu_bg_changed

const CATEGORIES: Array = [["controls", "options.cat_controls", "gamepad-2"], ["graphics", "options.cat_graphics", "monitor"],
		["audio", "options.cat_audio", "volume-2"], ["account", "options.cat_account", "circle-user"],
		["advanced", "options.cat_advanced", "wrench"]]

var _s: Node
var _gs: Node
var _content: VBoxContainer
var _tabs: Dictionary = {}


func _ready() -> void:
	_s = get_node("/root/Settings")
	_gs = get_node("/root/GameState")
	theme = UiTheme.make()
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.11, 0.9), Color(1, 1, 1, 0.1), 1, 12, 18))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 36.0
	offset_top = 24.0
	offset_right = -36.0
	offset_bottom = -24.0
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(UiKit.screen_title(Tr.t("options.title"), "settings"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(200, 0)
	body.add_child(side)
	for c in CATEGORIES:
		var b: Button = UiKit.nav_button(Tr.t(String(c[1])), String(c[2]), Vector2(200, 46))
		b.add_theme_font_size_override("font_size", 19)
		var id: String = String(c[0])
		b.pressed.connect(func() -> void: _show(id))
		side.add_child(b)
		_tabs[id] = b
	var scroll := TouchScroll.new()           # rola arrastando sobre os cartoes (T-165)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)
	var foot := HBoxContainer.new()
	var back: Button = UiKit.back_button()
	back.pressed.connect(func() -> void: back_pressed.emit())
	foot.add_child(back)
	root.add_child(foot)
	var first: String = "controls"
	for a in OS.get_cmdline_user_args():             # depuracao/capturas: --options-tab=graphics|audio|account
		if a.begins_with("--options-tab=") and _tabs.has(a.substr(14)):
			first = a.substr(14)
	_show(first)
	(_tabs[first] as Button).grab_focus.call_deferred()


func _show(id: String) -> void:
	for c in _content.get_children():
		c.queue_free()
	for k in _tabs:
		(_tabs[k] as Button).add_theme_color_override("font_color", UiTheme.GOLD if k == id else UiTheme.TEXT)
	match id:
		"controls":
			_slider(Tr.t("options.touch_size"), _s.touch_scale, 0.7, 1.5, 0.05, func(v: float) -> void: _s.touch_scale = v, true)
			_hint(Tr.t("options.lane_hint"))
			_hint(Tr.t("options.keys_hint"))
		"graphics":
			var bgs: Array[String] = MenuBackdrop.KINDS
			_choice(Tr.t("options.menu_bg"), bgs.map(func(k: String) -> String: return Tr.t("options.menu_bg_" + k)), maxi(bgs.find(String(_s.menu_bg)), 0),
					func(i: int) -> void:
						_s.menu_bg = bgs[i]
						menu_bg_changed.emit())
			_hint(Tr.t("options.menu_bg_hint"))
			var qs: Array = [Tr.t("options.quality_low"), Tr.t("options.quality_mid"), Tr.t("options.quality_high")]
			if UltraLook.available():                 # T-189: Ultra so no PC (Forward+)
				qs.append(Tr.t("options.quality_ultra"))
			_choice(Tr.t("options.quality"), qs, mini(_s.quality, qs.size() - 1), func(i: int) -> void: _s.quality = i)
			_hint(Tr.t("options.quality_hint"))
			if UltraLook.available():
				_hint(Tr.t("options.quality_ultra_hint"))
			_toggle(Tr.t("options.show_fps"), _s.show_fps, func(on: bool) -> void: _s.show_fps = on)
			_toggle(Tr.t("options.fx_speed"), _s.fx_speed, func(on: bool) -> void: _s.fx_speed = on)
			_toggle(Tr.t("options.fx_reflections"), _s.fx_reflections, func(on: bool) -> void: _s.fx_reflections = on)
			_toggle(Tr.t("options.fx_trails"), _s.fx_trails, func(on: bool) -> void: _s.fx_trails = on)
			_toggle(Tr.t("options.fx_rain"), _s.fx_rain, func(on: bool) -> void: _s.fx_rain = on)
			_toggle(Tr.t("options.fx_impact"), _s.fx_impact, func(on: bool) -> void: _s.fx_impact = on)
			_toggle(Tr.t("options.fx_life"), _s.fx_life, func(on: bool) -> void: _s.fx_life = on)
			_toggle(Tr.t("options.fx_reduce_flash"), _s.fx_reduce_flash, func(on: bool) -> void: _s.fx_reduce_flash = on)   # T-204
			if UltraLook.available():
				_toggle(Tr.t("options.fx_motion_blur"), _s.fx_motion_blur, func(on: bool) -> void: _s.fx_motion_blur = on)
			_hint(Tr.t("options.fx_hint"))
			var cams: Array[String] = RaceCamRig.IDS                 # T-198: camera da corrida e retrovisor
			_choice(Tr.t("options.race_cam"), cams.map(func(k: String) -> String: return Tr.t("options.race_cam_" + k)),
					maxi(cams.find(_s.race_cam), 0), func(i: int) -> void:
						_s.race_cam = cams[i]
						_s.race_cam_routes = {})                       # a escolha aqui vale para todas as rotas
			_choice(Tr.t("options.mirror"), [Tr.t("options.mirror_auto"), Tr.t("options.mirror_on"), Tr.t("options.mirror_off")],
					_s.mirror_mode, func(i: int) -> void: _s.mirror_mode = i)
			_toggle(Tr.t("options.cam_letterbox"), _s.cam_letterbox, func(on: bool) -> void: _s.cam_letterbox = on)
			_hint(Tr.t("options.cam_hint"))
		"audio":
			_slider(Tr.t("options.music"), _s.music_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _s.music_volume = v, true)
			_slider(Tr.t("options.sfx"), _s.sfx_volume, 0.0, 1.0, 0.05, func(v: float) -> void: _s.sfx_volume = v, true)
		"account":
			_account()
		"advanced":                                   # T-181: camera livre de exploracao
			_toggle(Tr.t("options.explorer_mode"), _s.explorer_mode, func(on: bool) -> void: _s.explorer_mode = on)
			_hint(Tr.t("options.explorer_hint"))
			_hint(Tr.t("options.explorer_keys"))


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
	cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_hint(Tr.t("options.code_hint"))
	var row := HBoxContainer.new()
	var edit := LineEdit.new()
	edit.text = String(_gs.profile["player_code"])
	edit.max_length = 12
	edit.custom_minimum_size = Vector2(220, 46)
	row.add_child(edit)
	var use: Button = UiTheme.button(Tr.t("options.use_code"), Vector2(170, 46))
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
			reset.text = Tr.t("options.reset_confirm")
			return
		_gs.new_profile()
		profile_changed.emit())
	_content.add_child(reset)
