extends Control
## Cena de teste do som do motor (P51, T-173): sliders de RPM, acelerador, boost e dano; escolha de motor, turbo,
## ESCAPAMENTO (perfis de som da T-173) e buzinas. ACELERAR AUTOMATICO repete a subida/descida do giro da garagem.
## Abra: godot --path game res://scenes/tools/engine_audio_test.tscn
## Sem tela (conferencia): godot --headless --path game res://scenes/tools/engine_audio_test.tscn -- --cycle-profiles
## T-197: DIRIGIR (roteiro AudioDriveDemo: lenta, marchas, freio-motor, freada ate parar), Leve (Canter), som antigo
## e cabine. Por linha de comando: -- --sweep --cfg=MOTOR:TURBO:ESCAPE:CARROCERIA:jake|nojake:new|old:out|cab
## [--quit-at-end]. Com --write-movie X.png o Godot grava o som exato em X.wav (tools/render_t197_audio.sh).

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
var _body: String = ""
var _legacy: bool = false
var _interior: bool = false
var _drive: AudioDriveDemo
var _quit_at_end: bool = false
var _loops: Dictionary = {}


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
	_row(v, "Motor", [["eng_i6_std", "6 cil. padrão"], ["eng_i6_tuned", "6 cil. preparado"], ["eng_v8", "V8"], ["canter", "Leve (Canter)"]], func(id: String) -> void:
		_body = "canter" if id == "canter" else ""
		_engine_id = "eng_i6_std" if id == "canter" else id)
	_row(v, "Escapamento", [["exh_std", "Padrão"], ["exh_straight", "Reto rouco"], ["exh_stack", "Chaminés V8"], ["exh_chrome_cut", "Cromado estalos"]], func(id: String) -> void: _exhaust = id)
	_row(v, "Turbina", [["turbo_none", "Sem turbo"], ["turbo_single", "Turbo simples"], ["turbo_twin", "Turbo duplo"]], func(id: String) -> void: _turbo = id)
	var jk := CheckButton.new()
	jk.text = "Freio-motor"
	jk.toggled.connect(func(on: bool) -> void:
		_jake = on
		_rebuild())
	v.add_child(jk)
	for opt in [["Som antigo (ElevenLabs)", "_legacy"], ["Dentro da cabine", "_interior"]]:
		var cb := CheckButton.new()
		cb.text = String(opt[0])
		var key: String = String(opt[1])
		cb.toggled.connect(func(on: bool) -> void:
			set(key, on)
			_rebuild())
		v.add_child(cb)
	var drv: Button = UiTheme.button("DIRIGIR (lenta, marchas, freio-motor, freada)", Vector2(460, 40))
	drv.pressed.connect(_start_drive)
	v.add_child(drv)
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
	for n in ["wind_speed_loop", "tyre_road_loop"]:
		var lp := AudioStreamPlayer.new()
		lp.bus = "SFX"
		lp.stream = AudioBus.stream(n)
		lp.volume_db = -80.0
		add_child(lp)
		_loops[n] = lp
	_read_cmdline()
	_rebuild()
	if "--cycle-profiles" in OS.get_cmdline_user_args():
		_cycle_check.call_deferred()
	if "--sweep" in OS.get_cmdline_user_args():
		_start_drive()


func _read_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cfg="):
			var f: PackedStringArray = a.substr(6).split(":")
			if f.size() >= 7:
				_engine_id = f[0]
				_turbo = f[1]
				_exhaust = f[2]
				_body = "" if f[3] == "-" else f[3]
				_jake = f[4] == "jake"
				_legacy = f[5] == "old"
				_interior = f[6] == "cab"
	_quit_at_end = "--quit-at-end" in OS.get_cmdline_user_args()


func _start_drive() -> void:
	_auto = false
	_drive = AudioDriveDemo.new()
	_drive.configure(_engine_id, _turbo, _exhaust, _jake)
	for n in _loops:
		if (_loops[n] as AudioStreamPlayer).stream != null:
			(_loops[n] as AudioStreamPlayer).play()


## Um passo do roteiro: estado do motor -> som, e os eventos (troca, pssh, freio a ar).
func _drive_step(dt: float) -> void:
	_drive.step(dt)
	var e: EngineModel = _drive.engine
	_rpm = _drive.rpm01()
	_throttle = 0.0 if e.shifting > 0.0 else _drive.throttle
	_boost = e.boost
	if _drive.gear_changed != 0:
		AudioBus.play_sfx("gear_shift_%d" % (1 + e.gear % 2), -6.0)
		if _drive.gear_changed > 0:
			AudioBus.play_sfx("gear_air_pfft", -14.0)
	if e.blowoff and _audio.turbo_set != "":
		_audio.blowoff()
	if _drive.brake_released or (_drive.stopped_event and _drive.braking):
		AudioBus.play_sfx("air_brake_hiss", -6.0)
	if _drive.stopped_event:
		AudioBus.play_sfx("air_brake_park", -8.0)
	var v01: float = clampf(_drive.speed / 38.9, 0.0, 1.0)
	_set_loop("wind_speed_loop", v01 * 0.55, -8.0, 0.85 + 0.3 * v01)
	_set_loop("tyre_road_loop", clampf(_drive.speed / 6.0, 0.0, 1.0) * (0.25 + 0.5 * v01), -9.0, 0.75 + 0.55 * v01)
	if _drive.t >= AudioDriveDemo.DURATION:
		_drive = null
		for n in _loops:
			(_loops[n] as AudioStreamPlayer).stop()
		if _quit_at_end:
			get_tree().quit()


func _set_loop(n: String, w: float, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _loops[n]
	p.volume_db = linear_to_db(clampf(w, 0.0, 1.0)) + db if w > 0.01 else -80.0
	p.pitch_scale = pitch


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
	_audio.interior = _interior
	add_child(_audio)
	var s: Dictionary = EngineSounds.spec(_engine_id, _turbo, _exhaust, true, _body, _legacy)
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
			if not _legacy:          # T-197: 5 pontos x ON/OFF + escape aberto (3) + estalos (2)
				want = 10 + (3 if float(EngineSounds.SYN_EXHAUST[ex]["open_db"]) > -60.0 else 0) 					+ (2 if bool(EngineSounds.SYN_EXHAUST[ex]["pops"]) else 0) + (1 if tb != "turbo_none" else 0) + 1 + (3 if _jake else 0)
			print("ENGINE_TEST %s %s -> %s (%d camadas)" % [ex, tb, ", ".join(_audio.layer_names()), n])
			if n != want:
				bad += 1
	print("ENGINE_TEST_DONE erros=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _process(delta: float) -> void:
	if _drive != null:
		_drive_step(delta)
	elif _auto:
		_auto_t = fmod(_auto_t + delta, SoundPreview.DURATION + 0.6)
		var c: Vector2 = SoundPreview.rev_curve(_auto_t)
		_rpm = c.x
		_throttle = c.y
		_boost = clampf((_auto_t - 0.8) / 0.8, 0.0, 1.0) if c.y > 0.5 else 0.0
		(_sliders["rpm"] as HSlider).set_value_no_signal(_rpm)
		(_sliders["thr"] as HSlider).set_value_no_signal(_throttle)
		(_sliders["boost"] as HSlider).set_value_no_signal(_boost)
	_audio.update(delta, _rpm, _throttle, _boost, _health, _drive.speed if _drive != null else 20.0)
