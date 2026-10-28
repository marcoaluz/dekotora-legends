extends TestCase
## T-220: diesel procedural (DieselSynth / EngineSynthVoice / EngineSoundMode): frequencia de ignicao certa,
## tom continuo, irregularidade, falhas com dano, versao leve, escolha do modo e montagem das camadas.


func _voice() -> EngineVoiceDef:
	return load("res://data/audio/voice_i6.tres") as EngineVoiceDef


## Conta as explosoes em `secs` segundos a rpm fixo.
func _fired(v: EngineVoiceDef, rate: float, rpm: float, secs: float) -> int:
	var s := DieselSynth.new(v, rate)
	s.render(int(rate * 0.2), rpm, 1.0)            # chega no rpm
	var f0: int = s.fired
	var block: int = int(rate / 60.0)
	for i in int(secs * 60.0):
		s.render(block, rpm, 1.0)
	return s.fired - f0


func test_firing_frequency_6_cyl() -> void:
	check_near(DieselSynth.firing_hz(700.0, 6), 35.0, 0.001, "6 cil. 4 tempos em lenta = 35 Hz")
	check_near(DieselSynth.firing_hz(2500.0, 6), 125.0, 0.001, "2500 rpm = 125 Hz")
	check_near(DieselSynth.firing_hz(2400.0, 8), 160.0, 0.001, "V8 = rpm/15")
	check_near(DieselSynth.firing_hz(1200.0, 4), 40.0, 0.001, "4 cil. = rpm/30")
	for rpm in [700.0, 1400.0, 2400.0]:
		var n: int = _fired(_voice(), 22050.0, rpm, 2.0)
		check(absi(n - int(rpm / 20.0 * 2.0)) <= 2, "%d rpm: %d explosoes em 2 s (esperado %d)" % [int(rpm), n, int(rpm / 10.0)])


func test_light_version_same_rhythm() -> void:
	var n: int = _fired(_voice(), 11025.0, 1800.0, 2.0)
	check(absi(n - 180) <= 2, "versao leve (11 kHz): mesmo ritmo, %d explosoes" % n)


func test_generic_cylinders() -> void:
	var v8 := EngineVoiceDef.new()
	v8.cylinders = 8
	var n: int = _fired(v8, 11025.0, 1500.0, 2.0)
	check(absi(n - 200) <= 2, "8 cilindros: rpm/15 (%d)" % n)
	var two := EngineVoiceDef.new()
	two.strokes = 2
	n = _fired(two, 11025.0, 1200.0, 1.0)
	check(absi(n - 120) <= 2, "2 tempos: o dobro (%d)" % n)


func test_ramp_continuous_and_deterministic() -> void:
	var a := DieselSynth.new(_voice(), 11025.0)
	var b := DieselSynth.new(_voice(), 11025.0)
	var block: int = 184
	var total: float = 0.0
	var same: bool = true
	var finite: bool = true
	for i in 360:                                   # 6 s: 700 -> 2400 rpm
		var rpm: float = lerpf(700.0, 2400.0, float(i) / 360.0)
		var x: PackedFloat32Array = a.render(block, rpm, 1.0)
		var y: PackedFloat32Array = b.render(block, rpm, 1.0)
		same = same and x == y
		total += DieselSynth.firing_hz(rpm, 6) * float(block) / 11025.0
		for s in x:
			finite = finite and is_finite(s) and absf(s) < 8.0
	check(same, "mesma semente = mesmo som (deterministico)")
	check(finite, "sem estouro nem NaN na rampa")
	check(absf(float(a.fired) - total) <= 3.0, "rampa: explosoes seguem o rpm continuo (%d x %.0f)" % [a.fired, total])


func test_irregular_not_machine() -> void:
	# intervalos entre explosoes em lenta nao sao todos iguais (o "lope" do diesel), mas a media e a certa
	var s := DieselSynth.new(_voice(), 22050.0)
	var x: PackedFloat32Array = s.render(22050, 700.0, 0.0)
	var peaks: Array[int] = []
	for i in range(1, x.size() - 1):
		if x[i] > 0.15 and x[i] >= x[i - 1] and x[i] > x[i + 1] and (peaks.is_empty() or i - peaks[-1] > 300):
			peaks.append(i)
	check(peaks.size() >= 30, "lenta: ~35 explosoes por segundo visiveis (%d)" % peaks.size())
	var amps: Array[float] = []
	for p in peaks:
		amps.append(x[p])
	var mn: float = amps.min()
	var mx: float = amps.max()
	check(mx / maxf(mn, 1e-6) > 1.2, "cada explosao com forca diferente (%.2f..%.2f)" % [mn, mx])


func test_damage_misfires() -> void:
	var ok := DieselSynth.new(_voice(), 11025.0)
	ok.render(11025 * 2, 1500.0, 1.0, 1.0)
	check_eq(ok.misfires, 0, "motor saudavel nao falha")
	var bad := DieselSynth.new(_voice(), 11025.0)
	bad.render(11025 * 2, 1500.0, 1.0, 0.1)
	check(bad.misfires > 3, "motor quebrado falha (%d de %d)" % [bad.misfires, bad.fired])


func test_eq_curve_and_cutoff() -> void:
	var v: EngineVoiceDef = _voice()
	check(EngineSynthVoice.eq_gain_db(v, v.mid_hz) > EngineSynthVoice.eq_gain_db(v, 4000.0) + 4.0, "ressonancia media")
	check(EngineSynthVoice.eq_gain_db(v, v.boom_hz) > 3.0, "ronco grave do abafador")
	check(EngineSynthVoice.lp_cutoff(v, 2400.0, 2400.0, 1.0) > EngineSynthVoice.lp_cutoff(v, 700.0, 2400.0, 0.0), "abafador abre com o giro")


func test_mode_resolution() -> void:
	var cfg := EngineAudioConfig.new()
	cfg.mode = "loops"
	cfg.mode_mobile = "synth"
	check_eq(EngineSoundMode.resolve("", "", false, cfg), "loops", "padrao do PC vem do arquivo")
	check_eq(EngineSoundMode.resolve("", "", true, cfg), "synth", "padrao do celular vem do arquivo")
	check_eq(EngineSoundMode.resolve("", "mix", false, cfg), "mix", "opcao do jogador vence o arquivo")
	check_eq(EngineSoundMode.resolve("synth", "mix", false, cfg), "synth", "linha de comando vence tudo")
	check_eq(EngineSoundMode.resolve("", "xyz", false, cfg), "loops", "valor invalido = padrao")
	check_eq(EngineSoundMode.cmdline_mode(PackedStringArray(["--engine-sound=mix"])), "mix", "le --engine-sound=")
	check_eq(EngineSoundMode.cmdline_mode(PackedStringArray(["--engine-sound=old"])), "", "old e do EngineSounds")
	check(EngineSoundMode.config() != null, "engine_audio.tres carrega")
	check(EngineSoundMode.voice_def("i6") != null, "voz do 6 cil. existe")
	check(EngineSoundMode.voice_def("v8") == null, "V8 espera a aprovacao do Marco (continua nos loops)")


func test_engine_audio_layers_per_mode() -> void:
	(Engine.get_main_loop().root.get_node("AudioBus") as Node).call("_setup_buses")
	var spec: Dictionary = EngineSounds.spec("eng_i6_std", "turbo_single", "exh_std")
	for m in ["loops", "synth", "mix"]:
		var e := EngineAudio.new()
		e.mode_override = m
		e.setup_spec(spec, false)
		var names: Array[String] = e.layer_names()
		var has_on: bool = names.has(DieselMix.layer("i6", "on", 1400.0, e.loop_source()))   # T-260: rec_ ou syn_
		check_eq(e.sound_mode, m, "modo %s aplicado" % m)
		check_eq(has_on, m != "synth", "%s: loops ON/OFF %s" % [m, "presentes" if m != "synth" else "fora"])
		check_eq(e.proc != null, m != "loops", "%s: diesel procedural %s" % [m, "ligado" if m != "loops" else "desligado"])
		check(names.has("turbo_single_whine"), "%s: turbo continua em loop" % m)
		for i in 90:                                 # o rpm do audio e suavizado
			e.update(0.016, 0.5, 1.0, 0.5, 1.0, 20.0)
		if e.proc != null:
			check(e.proc.target_rpm > 1400.0 and e.proc.target_rpm < 1700.0, "%s: rpm real chega ao sintetizador (%.0f)" % [m, e.proc.target_rpm])
		e.free()
	var r := EngineAudio.new()
	r.positional = true
	r.mode_override = "synth"
	r.setup_spec(spec, false)
	check(r.proc == null and not (r.sound_mode in ["synth", "mix"]), "rivais ficam nos loops")
	r.free()
	var v8 := EngineAudio.new()
	v8.mode_override = "synth"
	v8.setup_spec(EngineSounds.spec("eng_v8", "turbo_none", "exh_std"), false)
	check(v8.proc == null and v8.layer_names().has(DieselMix.layer("v8", "on", 1400.0)), "V8 sem voz: loops")
	v8.free()
