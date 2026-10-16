extends TestCase
## Testes de audio (P50-P52): arquivos presentes, mistura por RPM e carregamento com loop.


func test_band_weights_sum_to_one_and_follow_rpm() -> void:
	for r in [0.0, 0.1, 0.3, 0.5, 0.62, 0.8, 1.0]:
		var w: Array[float] = EngineAudio.band_weights(r)
		var total: float = 0.0
		for x in w:
			total += x
		check_near(total, 1.0, 0.001, "pesos somam 1 em rpm %.2f" % r)
	check(EngineAudio.band_weights(0.0)[0] > 0.9, "marcha lenta: camada idle domina")
	check(EngineAudio.band_weights(1.0)[3] > 0.9, "rotacao maxima: camada high domina")
	var mid: Array[float] = EngineAudio.band_weights(0.62)
	check(mid[2] > mid[0] and mid[2] > mid[3], "rpm medio: camada mid domina")


func test_pitch_rises_with_rpm() -> void:
	check(EngineAudio.pitch_for(1.0) > EngineAudio.pitch_for(0.0), "tom sobe com a rotacao")


func test_documented_audio_files_exist() -> void:
	var missing: Array[String] = []
	var must: Array[String] = ["engines/i6_std_idle", "engines/i6_std_low", "engines/i6_std_mid", "engines/i6_std_high",
		"engines/v8_high", "engines/i6_tuned_mid", "engines/turbo_single_whine", "engines/turbo_blowoff_1", "engines/jake_brake",
		"sfx/truck/horn_air_basic", "sfx/crash/crash_heavy_1", "sfx/ui/ui_select", "sfx/ui/countdown_go", "music/menu_citypop",
		"music/race_night_synthwave", "music/boss_enka_rock", "music/results_win"]
	for m in must:
		if not ResourceLoader.exists("res://assets/audio/%s.mp3" % m):
			missing.append(m)
	check(missing.is_empty(), "arquivos de audio ausentes: %s" % [missing])


func test_audiobus_loads_streams_and_sets_loops() -> void:
	var bus: Node = Engine.get_main_loop().root.get_node("AudioBus")
	var idle: AudioStream = bus.stream("i6_std_idle")
	check(idle != null, "carrega i6_std_idle")
	if idle is AudioStreamMP3:
		check((idle as AudioStreamMP3).loop, "motor em loop")
	var select: AudioStream = bus.stream("ui_select")
	if select is AudioStreamMP3:
		check(not (select as AudioStreamMP3).loop, "efeito pontual sem loop")
	var music: AudioStream = bus.stream("menu_citypop")
	if music is AudioStreamMP3:
		check((music as AudioStreamMP3).loop, "musica em loop")
