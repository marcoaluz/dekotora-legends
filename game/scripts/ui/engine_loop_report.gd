class_name EngineLoopReport
extends PanelContainer
## T-220: analysis of every engine loop (made by tools/audio_t220_analyze.py into docs/audio_t220/): table with the
## fundamental heard x expected and the verdict, plus the spectrum sheets (PNG). Reads the files from the repository
## folder next to game/ (works when the scene runs from the editor; not in exported builds).

const DOCS: String = "res://../docs/audio_t220/"
const SHEETS: Array[String] = ["espectro_elevenlabs", "espectro_t197_i6", "espectro_t197_i6t", "espectro_t197_v8", "espectro_t197_i4"]

var _img: TextureRect
var _table: RichTextLabel


func _ready() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.06, 0.97)
	add_theme_stylebox_override("panel", bg)
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var close: Button = UiTheme.button("FECHAR", Vector2(110, 32))
	close.pressed.connect(queue_free)
	top.add_child(close)
	var tbl: Button = UiTheme.button("Tabela", Vector2(90, 32))
	tbl.pressed.connect(func() -> void: _show(""))
	top.add_child(tbl)
	for s in SHEETS:
		var b: Button = UiTheme.button(s.substr(9), Vector2(110, 32))
		b.pressed.connect(func() -> void: _show(s))
		top.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_table = RichTextLabel.new()
	_table.bbcode_enabled = true
	_table.fit_content = true
	_table.custom_minimum_size = Vector2(900, 0)
	_table.add_theme_font_size_override("normal_font_size", 12)
	inner.add_child(_table)
	_img = TextureRect.new()
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_img.custom_minimum_size = Vector2(900, 0)
	inner.add_child(_img)
	_show("")


static func load_report() -> Dictionary:
	var path: String = ProjectSettings.globalize_path(DOCS + "analise.json")
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _show(sheet: String) -> void:
	_img.texture = null
	_table.visible = sheet == ""
	if sheet != "":
		var img := Image.load_from_file(ProjectSettings.globalize_path(DOCS + sheet + ".png"))
		if img != null:
			_img.texture = ImageTexture.create_from_image(img)
		return
	var rep: Dictionary = load_report()
	if rep.is_empty():
		_table.text = "Sem análise: rode  python tools/audio_t220_analyze.py  (gera docs/audio_t220/analise.json)."
		return
	var t: String = "[b]Fundamental de ignição (rpm/60 × cilindros/2) que o jogador OUVE × a de um motor real[/b]\n"
	t += "[code]%-24s %-7s %6s %8s %8s %6s  motivo[/code]\n" % ["loop", "veredito", "rpm", "ouvida", "esperada", "clareza"]
	for k in rep:
		var r: Dictionary = rep[k]
		var ok: bool = bool(r["ok"])
		t += "[color=%s][code]%-24s %-7s %6d %7.1fHz %7.1fHz %6.2f  %s[/code][/color]\n" % ["#5be37f" if ok else "#ff6b6b", k,
			"CERTO" if ok else "ERRADO", int(r["rpm"]), float(r["heard"]), float(r["expected"]), float(r["clarity"]),
			"; ".join(PackedStringArray(r["reasons"]))]
	_table.text = t
