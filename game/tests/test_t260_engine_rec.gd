extends TestCase
## T-260: loops do motor feitos das gravacoes reais do Iveco Daily (BigSoundBank, CC0; tools/rec_engine_t260.py).
## Leve (i4), 6 cil. pesado (i6) e 6 cil. preparado (i6t) tem os 10 loops; V8 continua nos sintetizados.

const REC_VOICES: Array[String] = ["i4", "i6", "i6t"]


func _bus() -> Node:
	return Engine.get_main_loop().root.get_node("AudioBus")


func test_recorded_loops_exist_and_loop() -> void:
	for v in REC_VOICES:
		check(EngineAudio.recordings_complete(v), "%s: os 10 loops gravados existem" % v)
		for r in DieselMix.RPM_POINTS:
			for k in ["on", "off"]:
				var n: String = DieselMix.layer(v, k, r, "rec")
				var s: AudioStream = _bus().stream(n)
				check(s is AudioStreamWAV, "%s carrega (wav)" % n)
				if s is AudioStreamWAV:
					var w: AudioStreamWAV = s as AudioStreamWAV
					check_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s em loop (smpl do arquivo)" % n)
					check(w.get_length() > 1.5 and w.get_length() < 4.0, "%s dura %.2f s" % [n, w.get_length()])
	check(not EngineAudio.recordings_complete("v8"), "V8 sem gravacao: fica nos loops sintetizados")


func test_default_mode_is_recordings() -> void:
	var cfg: EngineAudioConfig = EngineSoundMode.config()
	check_eq(cfg.mode, "rec", "PC: gravacao real por padrao")
	check_eq(cfg.mode_mobile, "rec", "celular: gravacao real por padrao")
	check("rec" in EngineSoundMode.MODES, "modo rec existe")
	check_eq(EngineSoundMode.resolve("", "loops", false, cfg), "loops", "opcao do jogador volta aos sintetizados")
	check_eq(EngineSoundMode.cmdline_mode(PackedStringArray(["--engine-sound=rec"])), "rec", "le --engine-sound=rec")


func test_layers_follow_mode() -> void:
	(_bus() as Node).call("_setup_buses")
	var cases: Array = [["eng_i6_std", "", "i6"], ["eng_i6_tuned", "", "i6t"], ["eng_i6_std", "canter", "i4"]]
	for c in cases:
		var spec: Dictionary = EngineSounds.spec(String(c[0]), "turbo_none", "exh_std", true, String(c[1]))
		check_eq(String(spec["voice"]), String(c[2]), "%s %s = voz %s" % [c[0], c[1], c[2]])
		for m in ["rec", "loops"]:
			var e := EngineAudio.new()
			e.mode_override = m
			e.setup_spec(spec, false)
			var want: String = "rec" if m == "rec" else "syn"
			check_eq(e.loop_source(), want, "%s modo %s: loops %s" % [c[2], m, want])
			check(e.layer_names().has(DieselMix.layer(String(c[2]), "on", 1900.0, want)), "%s modo %s: camada on_1900" % [c[2], m])
			e.free()
	var r := EngineAudio.new()                               # outros caminhoes tambem usam as gravacoes
	r.positional = true
	r.mode_override = "rec"
	r.setup_spec(EngineSounds.spec("eng_i6_std", "turbo_none", "exh_std"), false)
	check_eq(r.loop_source(), "rec", "rival com gravacao real")
	r.free()
	var v8 := EngineAudio.new()
	v8.mode_override = "rec"
	v8.setup_spec(EngineSounds.spec("eng_v8", "turbo_none", "exh_std"), false)
	check_eq(v8.loop_source(), "syn", "V8 sem gravacao: sintetizado")
	check_eq(v8.sound_mode, "loops", "V8 informa loops")
	v8.free()


func test_crossfade_by_rpm_and_load() -> void:
	(_bus() as Node).call("_setup_buses")
	var e := EngineAudio.new()
	e.mode_override = "rec"
	e.setup_spec(EngineSounds.spec("eng_i6_std", "turbo_none", "exh_std"), false)
	for i in 120:                                             # lenta, pe fora: so a marcha lenta
		e.update(0.016, 0.0, 0.0, 0.0, 1.0, 0.0)
	var a: Array[String] = e.active_layers()
	check(a.has("rec_i6_off_700"), "lenta toca rec_i6_off_700 (%s)" % ", ".join(a))
	check(not a.has("rec_i6_on_2500"), "lenta nao toca o giro alto")
	for i in 120:                                             # meio do giro, pe no fundo
		e.update(0.016, 0.5, 1.0, 0.0, 1.0, 20.0)
	a = e.active_layers()
	check(a.has("rec_i6_on_1400") or a.has("rec_i6_on_1900"), "acelerando no meio toca on_1400/1900 (%s)" % ", ".join(a))
	check(not a.has("rec_i6_off_700"), "acelerando nao toca a lenta")
	e.free()
