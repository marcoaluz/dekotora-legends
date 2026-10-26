extends Control
## Cena de teste do som do motor (P51, T-173, T-197, T-220). Abra no editor: res://scenes/tools/engine_audio_test.tscn (F6).
## Esquerda: motor, escapamento, turbina, SOM (antigo ElevenLabs / loops T-197 / sintetizador / mistura), sliders de
## RPM, acelerador, turbo e dano, botoes ACELERAR 0->100% e SOLTAR, DIRIGIR (roteiro com marchas), buzinas.
## Direita (T-220): espectro ao vivo com a frequencia de ignicao esperada, CPU do sintetizador, ajuste do sintetizador
## e ANALISE DOS LOOPS (tabela + graficos de docs/audio_t220).
## Linha de comando: -- --cycle-profiles | --sweep | --ramp [--mode=old|loops|synth|mix] [--synth-light]
##   --cfg=MOTOR:TURBO:ESCAPE:CARROCERIA:jake|nojake:new|old:out|cab [--quit-at-end]. Com --write-movie X.png o
##   Godot grava o som exato em X.wav (tools/render_t197_audio.sh, tools/render_t220_audio.sh).

const MODES: Array = [["old", "Antigo (ElevenLabs)"], ["loops", "Loops T-197"], ["synth", "Sintetizador"], ["mix", "Mistura"]]
const ACCEL_S: float = 6.0             # ACELERAR: lenta -> corte em 6 s (pé no fundo, uma marcha longa)
const RELEASE_S: float = 3.0
## --ramp (gravacoes da T-220): lenta 2 s, acelera 8 s ate o corte, segura 1 s, solta 4 s, lenta 2 s.
const RAMP: Array[float] = [2.0, 10.0, 11.0, 15.0, 17.0]
## Ajuste ao vivo do sintetizador: [campo do EngineVoiceDef, rotulo, min, max]
const TUNE: Array = [["boom_db", "Grave (dB)", 0.0, 14.0], ["mid_db", "Médio (dB)", 0.0, 14.0],
	["presence_db", "Presença celular (dB)", 0.0, 12.0], ["drive", "Aspereza", 0.0, 0.9],
	["cyl_bias", "Irregularidade entre cilindros", 0.0, 0.3], ["burst", "Estouro de cada explosão", 0.0, 1.2],
	["flow", "Ruído de escape (fluxo)", 0.0, 0.6], ["clatter", "Batida do diesel (injetor)", 0.0, 1.0]]

var _audio: EngineAudio
var _rpm: float = 0.0
var _throttle: float = 0.0
var _boost: float = 0.0
var _health: float = 1.0
var _engine_id: String = "eng_i6_std"
var _turbo: String = "turbo_none"
var _exhaust: String = "exh_std"
var _jake: bool = false
var _auto: bool = false
var _auto_t: float = 0.0
var _info: Label
var _cpu: Label
var _sliders: Dictionary = {}
var _body: String = ""
var _legacy: bool = false
var _mode: String = "loops"
var _interior: bool = false
var _drive: AudioDriveDemo
var _quit_at_end: bool = false
var _loops: Dictionary = {}
var _ramp: int = 0                     # 1 acelerando, -1 soltando
var _script_t: float = -1.0            # --ramp: tempo do roteiro (-1 = desligado)
var _spec_view: EngineSpectrumView
var _voice_tune: EngineVoiceDef


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(480, 0)
	scroll.add_child(v)
	_build_left(v)
	var rs := ScrollContainer.new()
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(rs)
	var r := VBoxContainer.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(r)
	_build_right(r)
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
	if "--ramp" in OS.get_cmdline_user_args():
		_script_t = 0.0


func _build_left(v: VBoxContainer) -> void:
	v.add_child(UiTheme.label("Teste do som do motor", 24, UiTheme.PINK))
	_row(v, "Motor", [["eng_i6_std", "6 cil."], ["eng_i6_tuned", "6 cil. prep."], ["eng_v8", "V8"], ["canter", "Leve"]], func(id: String) -> void:
		_body = "canter" if id == "canter" else ""
		_engine_id = "eng_i6_std" if id == "canter" else id)
	_row(v, "Escapamento", [["exh_std", "Padrão"], ["exh_straight", "Reto"], ["exh_stack", "Chaminés"], ["exh_chrome_cut", "Cromado"]], func(id: String) -> void: _exhaust = id)
	_row(v, "Turbina", [["turbo_none", "Sem turbo"], ["turbo_single", "Simples"], ["turbo_twin", "Duplo"]], func(id: String) -> void: _turbo = id)
	_row(v, "Som (T-220: compare)", MODES, func(id: String) -> void:
		_mode = id
		_legacy = id == "old")
	for opt in [["Freio-motor", "_jake"], ["Dentro da cabine", "_interior"]]:
		var cb := CheckButton.new()
		cb.text = String(opt[0])
		var key: String = String(opt[1])
		cb.toggled.connect(func(on: bool) -> void:
			set(key, on)
			_rebuild())
		v.add_child(cb)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	var acc: Button = UiTheme.button("ACELERAR 0→100%", Vector2(170, 40))
	acc.pressed.connect(func() -> void: _start_ramp(1))
	hb.add_child(acc)
	var rel: Button = UiTheme.button("SOLTAR", Vector2(110, 40))
	rel.pressed.connect(func() -> void: _start_ramp(-1))
	hb.add_child(rel)
	var drv: Button = UiTheme.button("DIRIGIR", Vector2(110, 40))
	drv.pressed.connect(_start_drive)
	hb.add_child(drv)
	var au := CheckButton.new()
	au.text = "Acelerar automático (sobe e desce o giro)"
	au.toggled.connect(func(on: bool) -> void:
		_auto = on
		_auto_t = 0.0)
	v.add_child(au)
	_slider(v, "rpm", "RPM", _rpm, 0.0, 1.0, func(x: float) -> void:
		_rpm = x
		_ramp = 0)
	_slider(v, "thr", "Acelerador", _throttle, 0.0, 1.0, func(x: float) -> void: _throttle = x)
	_slider(v, "boost", "Turbo (pressão)", _boost, 0.0, 1.0, func(x: float) -> void: _boost = x)
	_slider(v, "hp", "Saúde do motor (dano: falhas e chacoalho)", _health, 0.0, 1.0, func(x: float) -> void: _health = x)
	var hb2 := HBoxContainer.new()
	v.add_child(hb2)
	var pop: Button = UiTheme.button("PSSH", Vector2(100, 36))
	pop.pressed.connect(func() -> void: _audio.blowoff())
	hb2.add_child(pop)
	var rep: Button = UiTheme.button("ANÁLISE DOS LOOPS", Vector2(200, 36))
	rep.pressed.connect(func() -> void:
		var p := EngineLoopReport.new()
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(p))
	hb2.add_child(rep)
	v.add_child(UiTheme.label("Buzinas (toca uma vez)", 14))
	var hg := GridContainer.new()
	hg.columns = 3
	v.add_child(hg)
	for id in HornCatalog.IDS:
		var b: Button = UiTheme.button(Tr.t(HornCatalog.label_key(id)), Vector2(150, 32))
		b.pressed.connect(func() -> void: AudioBus.play_sfx(id, -3.0))
		hg.add_child(b)


func _build_right(r: VBoxContainer) -> void:
	_spec_view = EngineSpectrumView.new()
	r.add_child(_spec_view)
	_info = UiTheme.label("", 13, UiTheme.CYAN)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(_info)
	_cpu = UiTheme.label("", 13, UiTheme.GOLD)
	r.add_child(_cpu)
	r.add_child(UiTheme.label("Ajuste do sintetizador (modos Sintetizador e Mistura)", 14, UiTheme.PINK))
	_voice_tune = (EngineSoundMode.voice_def("i6") as EngineVoiceDef)
	if _voice_tune == null:
		_voice_tune = EngineVoiceDef.new()
	_voice_tune = _voice_tune.duplicate() as EngineVoiceDef
	for t in TUNE:
		var key: String = String(t[0])
		_slider(r, "tune_" + key, String(t[1]), float(_voice_tune.get(key)), float(t[2]), float(t[3]), func(x: float) -> void:
			_voice_tune.set(key, x)
			_apply_tune())
	var pr: Button = UiTheme.button("IMPRIMIR VALORES (Output)", Vector2(260, 34))
	pr.pressed.connect(func() -> void:
		var parts: PackedStringArray = []
		for t in TUNE:
			parts.append("%s = %.3f" % [String(t[0]), float(_voice_tune.get(String(t[0])))])
		print("T220_TUNE ", ", ".join(parts)))
	r.add_child(pr)


## Sliders mexidos: o sintetizador le os numeros da excitacao ao vivo; o barramento (EQ, aspereza) e refeito.
func _apply_tune() -> void:
	if _audio == null or _audio.proc == null:
		return
	_audio.proc.voice = _voice_tune
	_audio.proc.synth.voice = _voice_tune
	var cfg: EngineAudioConfig = EngineSoundMode.config()
	_audio.proc.setup_bus(_voice_tune, _audio.proc.light, "EngineCab" if _interior else "Engine", cfg.crossover_hz if _audio.sound_mode == "mix" else 0.0)


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
				_mode = "old" if _legacy else _mode
				_interior = f[6] == "cab"
		elif a.begins_with("--mode="):
			_mode = a.substr(7)
			_legacy = _mode == "old"
	_quit_at_end = "--quit-at-end" in OS.get_cmdline_user_args()


func _start_ramp(dir: int) -> void:
	_drive = null
	_auto = false
	_ramp = dir
	if dir < 0 and _boost > 0.6 and _audio.turbo_set != "":
		_audio.blowoff()


func _start_drive() -> void:
	_auto = false
	_ramp = 0
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


## --ramp: roteiro fixo para as gravacoes antes x depois (mesmo RPM e acelerador em todos os modos).
func _script_step(dt: float) -> void:
	_script_t += dt
	var t: float = _script_t
	if t < RAMP[0]:
		_rpm = 0.0
		_throttle = 0.0
	elif t < RAMP[1]:
		_rpm = (t - RAMP[0]) / (RAMP[1] - RAMP[0])
		_throttle = 1.0
	elif t < RAMP[2]:
		_rpm = 1.0
		_throttle = 1.0
	elif t < RAMP[3]:
		_rpm = 1.0 - (t - RAMP[2]) / (RAMP[3] - RAMP[2])
		_throttle = 0.0
	else:
		_rpm = 0.0
		_throttle = 0.0
	_boost = clampf(_rpm * 1.4 - 0.3, 0.0, 1.0) if _throttle > 0.5 else 0.0
	if t >= RAMP[4]:
		_script_t = -1.0
		if _quit_at_end:
			get_tree().quit()


func _set_loop(n: String, w: float, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _loops[n]
	p.volume_db = linear_to_db(clampf(w, 0.0, 1.0)) + db if w > 0.01 else -80.0
	p.pitch_scale = pitch


func _row(parent: Control, title: String, items: Array, set_cb: Callable) -> void:
	parent.add_child(UiTheme.label(title, 14))
	var row := HBoxContainer.new()
	parent.add_child(row)
	for e in items:
		var b: Button = UiTheme.button(String(e[1]), Vector2(116, 34))
		b.pressed.connect(func() -> void:
			set_cb.call(String(e[0]))
			_rebuild())
		row.add_child(b)


func _slider(parent: Control, key: String, label: String, val: float, lo: float, hi: float, cb: Callable) -> void:
	parent.add_child(UiTheme.label(label, 13))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = val
	s.custom_minimum_size = Vector2(420, 20)
	s.value_changed.connect(cb)
	parent.add_child(s)
	_sliders[key] = s


func _rebuild() -> void:
	if _audio != null:
		_audio.queue_free()
	_audio = EngineAudio.new()
	_audio.interior = _interior
	_audio.mode_override = "" if _legacy else _mode
	add_child(_audio)
	var s: Dictionary = EngineSounds.spec(_engine_id, _turbo, _exhaust, true, _body, _legacy)
	_audio.setup_spec(s, _jake)
	if _audio.proc != null and _voice_tune != null and String(s.get("voice", "")) == "i6":
		_apply_tune.call_deferred()
	var mode_txt: String = "antigo (ElevenLabs)" if _legacy else _audio.sound_mode
	if not _legacy and _mode != "loops" and _audio.sound_mode == "loops":
		mode_txt += " (sintetizador ainda não feito para este motor: só o 6 cil. padrão, até o Marco aprovar)"
	_info.text = "Som: %s  |  arquivos: %s" % [mode_txt, String(s["set"])]
	_spec_view.cylinders = 8 if _engine_id == "eng_v8" else (4 if _body == "canter" else 6)


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
				want = (10 if _audio.sound_mode != "synth" else 0) + (3 if float(EngineSounds.SYN_EXHAUST[ex]["open_db"]) > -60.0 else 0) \
					+ (2 if bool(EngineSounds.SYN_EXHAUST[ex]["pops"]) else 0) + (1 if tb != "turbo_none" else 0) + 1 + (3 if _jake else 0)
			print("ENGINE_TEST %s %s %s -> %s (%d camadas)" % [_audio.sound_mode, ex, tb, ", ".join(_audio.layer_names()), n])
			if n != want:
				bad += 1
	print("ENGINE_TEST_DONE erros=%d" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _process(delta: float) -> void:
	if _script_t >= 0.0:
		_script_step(delta)
	elif _drive != null:
		_drive_step(delta)
	elif _ramp != 0:
		_throttle = 1.0 if _ramp > 0 else 0.0
		_rpm = clampf(_rpm + float(_ramp) * delta / (ACCEL_S if _ramp > 0 else RELEASE_S), 0.0, 1.0)
		_boost = move_toward(_boost, clampf(_rpm * 1.4 - 0.3, 0.0, 1.0) if _ramp > 0 else 0.0, delta * (1.0 if _ramp > 0 else 2.5))
		if _ramp < 0 and _rpm <= 0.0:
			_ramp = 0
	elif _auto:
		_auto_t = fmod(_auto_t + delta, SoundPreview.DURATION + 0.6)
		var c: Vector2 = SoundPreview.rev_curve(_auto_t)
		_rpm = c.x
		_throttle = c.y
		_boost = clampf((_auto_t - 0.8) / 0.8, 0.0, 1.0) if c.y > 0.5 else 0.0
	if _script_t >= 0.0 or _drive != null or _ramp != 0 or _auto:
		(_sliders["rpm"] as HSlider).set_value_no_signal(_rpm)
		(_sliders["thr"] as HSlider).set_value_no_signal(_throttle)
		(_sliders["boost"] as HSlider).set_value_no_signal(_boost)
	_audio.update(delta, _rpm, _throttle, _boost, _health, _drive.speed if _drive != null else 20.0)
	var redline: float = EngineSounds.redline_of(_engine_id)
	var rpm_abs: float = lerpf(EngineModel.IDLE_RPM, redline, _rpm)
	_spec_view.rpm = rpm_abs
	var p: EngineSynthVoice = _audio.proc
	_cpu.text = "RPM %d  |  acelerador %d%%  |  " % [int(rpm_abs), int(_throttle * 100.0)] + (
		"sintetizador %s %d Hz: %.2f ms por quadro (pico %.2f)" % ["leve" if p.light else "PC", int(p.synth.mix_rate), p.cpu_ms_avg, p.cpu_ms_max]
		if p != null else "sintetizador desligado")
