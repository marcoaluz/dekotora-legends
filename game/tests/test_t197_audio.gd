extends TestCase
## T-197: diesel sintetizado (DieselMix/EngineAudio), sons proprios do bonde, freio a ar, pneus e fallback.

const VOICES: Array[String] = ["i6", "i6t", "v8", "i4"]


func _bus() -> Node:
	return Engine.get_main_loop().root.get_node("AudioBus")


func test_synth_loops_exist_and_loop() -> void:
	for v in VOICES:
		var names: Array[String] = []
		for r in DieselMix.RPM_POINTS:
			names.append(DieselMix.layer(v, "on", r))
			names.append(DieselMix.layer(v, "off", r))
		for r in DieselMix.JAKE_POINTS:
			names.append(DieselMix.layer(v, "jake", r))
		for r in DieselMix.OPEN_POINTS:
			names.append(DieselMix.layer(v, "open", r))
		for n in names:
			var s: AudioStream = _bus().stream(n)
			check(s is AudioStreamWAV, "%s carrega (wav)" % n)
			if s is AudioStreamWAV:
				var w: AudioStreamWAV = s as AudioStreamWAV
				check_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s em loop (smpl do arquivo)" % n)
				check(absf(float(w.loop_end) - w.get_length() * float(w.mix_rate)) < 2.0, "%s loop no arquivo inteiro" % n)
	for n in ["syn_exh_pop_1", "syn_exh_pop_2", "gear_air_pfft", "air_brake_park", "tram_bell"]:
		var o: AudioStream = _bus().stream(n)
		check(o != null, "%s carrega" % n)
		if o is AudioStreamWAV:
			check_eq((o as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s toca uma vez" % n)
	for n in ["tyre_road_loop", "tram_run_loop"]:
		var l: AudioStream = _bus().stream(n)
		check(l is AudioStreamWAV and (l as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s em loop" % n)


func test_spec_voice_exhaust_and_fallback() -> void:
	var s: Dictionary = EngineSounds.spec("eng_v8", "turbo_twin", "exh_stack")
	check_eq(String(s["voice"]), "v8", "V8 = voz v8")
	check_eq(String(s["turbo"]), "turbo_twin_whine", "turbo duplo")
	check(float(s["open_db"]) > -60.0, "chamines: ronco de escape aberto")
	check_near(float(s["redline"]), 2500.0, 0.1, "corte do V8 vem do .tres")
	check_eq(String(EngineSounds.spec("eng_i6_tuned", "turbo_none", "exh_std")["voice"]), "i6t", "6 cil. preparado")
	check(float(EngineSounds.spec("eng_i6_std", "turbo_none", "exh_std")["open_db"]) < -60.0, "escape padrao: abafado")
	check(bool(EngineSounds.spec("eng_i6_std", "turbo_none", "exh_chrome_cut")["pops"]), "cromado cortado: estalos")
	check_eq(String(EngineSounds.from_descriptor({"engine": "eng_v8", "body": "canter"})["voice"]), "i4", "Canter = 4 cil. leve")
	check_eq(String(EngineSounds.spec("eng_v8", "turbo_none", "exh_std", true, "", true)["set"]), "v8", "som antigo pedido")
	check(not EngineSounds.use_synth("nao_existe"), "sem os arquivos sintetizados -> som antigo")
	check(EngineSounds.use_synth("i6"), "com os arquivos -> sintetizado")


func test_point_weights_equal_power() -> void:
	for rpm in [600.0, 700.0, 850.0, 1200.0, 1650.0, 2200.0, 2500.0, 2700.0]:
		var w: Array[float] = DieselMix.point_weights(rpm, DieselMix.RPM_POINTS)
		var sq: float = 0.0
		var used: int = 0
		for x in w:
			sq += x * x
			used += 1 if x > 0.0001 else 0
		check_near(sq, 1.0, 0.001, "potencia constante em %d rpm" % int(rpm))
		check(used <= 2, "no maximo 2 pontos vizinhos em %d rpm" % int(rpm))
	# o tom de cada loop fica perto do original (sem "fita acelerada")
	for i in DieselMix.RPM_POINTS.size() - 1:
		var mid: float = sqrt(DieselMix.RPM_POINTS[i] * DieselMix.RPM_POINTS[i + 1])
		check(DieselMix.point_pitch(mid, DieselMix.RPM_POINTS[i]) < 1.25, "tom ate +25% entre pontos")


func test_mix_rules() -> void:
	check(DieselMix.is_shift_drop(-4000.0, 1.0), "giro caindo rapido com o pe no fundo = troca de marcha")
	check(not DieselMix.is_shift_drop(-4000.0, 0.0), "tirando o pe nao e troca")
	check(not DieselMix.is_shift_drop(-300.0, 1.0), "queda lenta nao e troca")
	check(DieselMix.jake_active(true, 0.0, 1800.0, 20.0), "freio-motor ligado ao soltar")
	check(not DieselMix.jake_active(false, 0.0, 1800.0, 20.0), "sem a peca, sem freio-motor")
	check(not DieselMix.jake_active(true, 0.0, 900.0, 20.0), "giro baixo, sem freio-motor")
	check(DieselMix.doppler(-30.0) > 1.0, "chegando = mais agudo")
	check(DieselMix.doppler(30.0) < 1.0, "indo embora = mais grave")
	check_near(DieselMix.doppler(-500.0), 1.0 + DieselMix.DOPPLER_MAX, 0.0001, "Doppler limitado")
	var lw: Vector2 = DieselMix.load_weights(0.5)
	check_near(lw.x * lw.x + lw.y * lw.y, 1.0, 0.001, "carga ON/OFF potencia constante")


func test_engine_audio_diesel_layers_follow_state() -> void:
	var e := EngineAudio.new()
	Engine.get_main_loop().root.add_child(e)
	e.setup_spec(EngineSounds.spec("eng_i6_std", "turbo_single", "exh_straight"), true)
	for i in 40:
		e.update(1.0 / 30.0, 0.0, 0.0, 0.0, 1.0, 0.0)
	var idle: Array[String] = e.active_layers()
	check("syn_i6_off_700" in idle, "parado: marcha lenta (%s)" % ", ".join(idle))
	check(not ("syn_i6_on_1900" in idle), "parado: sem camadas de giro alto")
	var r01: float = (1650.0 - 700.0) / (2400.0 - 700.0)
	for i in 40:
		e.update(1.0 / 30.0, r01, 1.0, 1.0, 1.0, 20.0)
	var full: Array[String] = e.active_layers()
	check("syn_i6_on_1400" in full and "syn_i6_on_1900" in full, "acelerando a 1650 rpm: pontos 1400 e 1900 (%s)" % ", ".join(full))
	check("syn_i6_open_1600" in full, "escape reto: ronco aberto acelerando")
	for i in 40:
		e.update(1.0 / 30.0, r01, 0.0, 0.0, 1.0, 20.0)
	var lift: Array[String] = e.active_layers()
	check("syn_i6_jake_1800" in lift or "syn_i6_jake_1300" in lift, "soltou com freio-motor: jake (%s)" % ", ".join(lift))
	check(not ("syn_i6_on_1400" in lift), "soltou: sai a carga")
	e.free()


func test_missing_voice_does_not_break() -> void:
	var e := EngineAudio.new()
	Engine.get_main_loop().root.add_child(e)
	var s: Dictionary = EngineSounds.synth_spec("eng_i6_std", "turbo_none", "exh_chrome_cut", "voz_que_nao_existe")
	e.setup_spec(s, true)
	e.update(0.1, 0.5, 1.0, 0.0, 1.0, 10.0)
	e.update(0.1, 0.5, 0.0, 0.0, 1.0, 10.0)
	check(e.active_layers().size() <= 1, "arquivos ausentes: so o que existe toca, sem erro")
	e.free()


func test_tram_has_own_sounds() -> void:
	var tram: Array[String] = LifeTrainSounds.sounds_for(RailTraffic.Type.LRT)
	var train: Array[String] = LifeTrainSounds.sounds_for(RailTraffic.Type.FREIGHT)
	for n in tram:
		check(not (n in train), "bonde nao usa o som do trem (%s)" % n)
		check(RaceAudio.has_sound(n), "arquivo do bonde %s" % n)
	_bus().call("_setup_buses")                    # o executor de testes nao roda o _ready dos autoloads
	check(AudioServer.get_bus_index("EngineCab") >= 0, "barramento da cabine existe")


func test_drive_demo_script() -> void:
	var d := AudioDriveDemo.new()
	d.configure("eng_i6_std", "turbo_single", "exh_std", false)
	var ups: int = 0
	var stops: int = 0
	var top: float = 0.0
	while d.t < AudioDriveDemo.DURATION:
		d.step(1.0 / 30.0)
		ups += 1 if d.gear_changed > 0 else 0
		stops += 1 if d.stopped_event else 0
		top = maxf(top, d.speed)
	check(ups >= 3, "roteiro troca marchas (%d subidas)" % ups)
	check(top > 15.0, "roteiro passa de 54 km/h (%.1f m/s)" % top)
	check_eq(stops, 1, "para uma vez (freio a ar)")
	check(d.speed < 0.31, "termina parado")
