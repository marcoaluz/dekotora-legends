extends Control
## Cena de teste do som do motor (P51, T-173): sliders de RPM, acelerador, boost e dano; escolha de motor, turbo,
## ESCAPAMENTO (perfis de som da T-173) e buzinas. ACELERAR AUTOMATICO repete a subida/descida do giro da garagem.
## Abra: godot --path game res://scenes/tools/engine_audio_test.tscn
## Sem tela (conferencia): godot --headless --path game res://scenes/tools/engine_audio_test.tscn -- --cycle-profiles

var _audio: EngineAudio
var _rpm: float = 0.2
var _throttle: float = 0.5
var _boost: float = 0.0
var _health: float = 1.0
var _engine_id: String = "eng_i6_std"
var _turbo: String = "turbo_none"
var _exhaust: String = "exh_std"
var _jake: bool = false
var _auto: bool = false
var _auto_t: float = 0.0
var _info: Label
var _sliders: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	scroll.add_child(v)
	v.add_child(UiTheme.label("Teste do som do motor", 28, UiTheme.PINK))
	_row(v, "Motor", [["eng_i6_std", "6 cil. padrão"], ["eng_i6_tuned", "6 cil. preparado"], ["eng_v8", "V8"]], func(id: String) -> void: _engine_id = id)
	_row(v, "Escapamento", [["exh_std", "Padrão"], ["exh_straight", "Reto rouco"], ["exh_stack", "Chaminés V8"], ["exh_chrome_cut", "Cromado estalos"]], func(id: String) -> void: _exhaust = id)
	_row(v, "Turbina", [["turbo_none", "Sem turbo"], ["turbo_single", "Turbo simples"], ["turbo_twin", "Turbo duplo"]], func(id: String) -> void: _turbo = id)
	var jk := CheckButton.new()
	jk.text = "Freio-motor"
	jk.toggled.connect(func(on: bool) -> void:
		_jake = on
		_rebuild())
	v.add_child(jk)
	var au := CheckButton.new()
	au.text = "Acelerar automático (sobe e desce o giro)"
	au.toggled.connect(func(on: bool) -> void:
		_auto = on
		_auto_t = 0.0)
	v.add_child(au)
	_slider(v, "rpm", "RPM", _rpm, func(x: float) -> void: _rpm = x)
	_slider(v, "thr", "Acelerador", _throttle, func(x: float) -> void: _throttle = x)
	_slider(v, "boost", "Boost do turbo", _boost, func(x: float) -> void: _boost = x)
	_slider(v, "hp", "Saúde do motor", _health, func(x: float) -> void: _health = x)
	var pop: Button = UiTheme.button("PSSH (blow-off)", Vector2(220, 40))
	pop.pressed.connect(func() -> void: _audio.blowoff())
	v.add_child(pop)
	v.add_child(UiTheme.label("Buzinas (segure H no jogo; aqui toca uma vez)", 16))
	var hg := GridContainer.new()
	hg.columns = 3
	v.add_child(hg)
	for id in HornCatalog.IDS:
		var hb: Button = UiTheme.button(Tr.t(HornCatalog.label_key(id)) + ("  (nova)" if id in HornCatalog.NEW_T173 else ""), Vector2(240, 38))
		hb.pressed.connect(func() -> void: AudioBus.play_sfx(id, -3.0))
		hg.add_child(hb)
	_info = UiTheme.label("", 14, UiTheme.CYAN)
	v.add_child(_info)
	_rebuild()
	if "--cycle-profiles" in OS.get_cmdline_user_args():
		_cycle_check.call_deferred()


func _row(parent: Control, title: String, items: Array, set_cb: Callable) -> void:
	parent.add_child(UiTheme.label(title, 16))
	var row := HBoxContainer.new()
	parent.add_child(row)
	for e in items:
		var b: Button = UiTheme.button(String(e[1]), Vector2(170, 40))
		b.pressed.connect(func() -> void:
			set_cb.call(String(e[0]))
			_rebuild())
		row.add_child(b)


func _slider(parent: Control, key: String, label: String, val: float, cb: Callable) -> void:
	parent.add_child(UiTheme.label(label, 14))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = val
	s.custom_minimum_size = Vector2(500, 22)
	s.value_changed.connect(cb)
	parent.add_child(s)
	_sliders[key] = s


func _rebuild() -> void:
	if _audio != null:
		_audio.queue_free()
	_audio = EngineAudio.new()
	add_child(_audio)
	var s: Dictionary = EngineSounds.spec(_engine_id, _turbo, _exhaust)
	_audio.setup_spec(s, _jake)
	_info.text = "Tocando: %s  |  camadas: %s" % [String(s["set"]), ", ".join(_audio.layer_names())]


## --cycle-profiles: monta os 4 escapamentos x 3 turbos e imprime as camadas (conferencia sem tela).
func _cycle_check() -> void:
	var bad: int = 0
	for ex in EngineSounds.EXHAUST_IDS:
		for tb in EngineSounds.TURBO_IDS:
			_exhaust = ex
			_turbo = tb
			_rebuild()
			var n: int = _audio.layer_names().size()
			var want: int = (3 if EngineSounds.exhaust_profile(ex) != "" else 4) + (1 if tb != "turbo_none" else 0) + 1
			print("ENGINE_TEST %s %s -> %s (%d camadas)" % [ex, tb, ", ".join(_audio.layer_names()), n])
			if n != want:
				bad += 1
	print("ENGINE_TEST_DONE erros=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _process(delta: float) -> void:
	if _auto:
		_auto_t = fmod(_auto_t + delta, SoundPreview.DURATION + 0.6)
		var c: Vector2 = SoundPreview.rev_curve(_auto_t)
		_rpm = c.x
		_throttle = c.y
		_boost = clampf((_auto_t - 0.8) / 0.8, 0.0, 1.0) if c.y > 0.5 else 0.0
		(_sliders["rpm"] as HSlider).set_value_no_signal(_rpm)
		(_sliders["thr"] as HSlider).set_value_no_signal(_throttle)
		(_sliders["boost"] as HSlider).set_value_no_signal(_boost)
	_audio.update(delta, _rpm, _throttle, _boost, _health, 20.0)
