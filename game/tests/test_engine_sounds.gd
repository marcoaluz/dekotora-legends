extends TestCase
## Variedade de som do motor (T-173): escapamento -> perfil de som, camadas existem, turbina por perfil, buzinas
## (catalogo, perfil, descritor de rede, servidor aceita) e o sorteio dos rivais.

const PROFILE_OF: Dictionary = {"exh_std": "", "exh_straight": "exh_rasp", "exh_stack": "exh_stack", "exh_chrome_cut": "exh_pop"}


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func test_exhaust_maps_to_profile() -> void:
	for ex in PROFILE_OF:
		check_eq(EngineSounds.exhaust_profile(String(ex)), String(PROFILE_OF[ex]), "perfil de som de %s" % ex)
		check(ex in _gs().MECH_KINDS["exhaust"]["ids"], "%s esta a venda na garagem" % ex)
		check(Tr.t("exhaust." + String(ex)) != "exhaust." + String(ex), "nome pt-BR de %s" % ex)
	check_eq(EngineSounds.PROFILES.size(), 3, "3 perfis novos")


func test_profile_layers_exist_and_loop() -> void:
	var bus: Node = Engine.get_main_loop().root.get_node("AudioBus")
	for p in EngineSounds.PROFILES:
		for layer in EngineSounds.profile_layers(p):
			check(EngineSounds.has_engine_file(layer), "arquivo %s existe" % layer)
			var s: AudioStream = bus.stream(layer)
			check(s != null, "carrega %s" % layer)
			if s is AudioStreamMP3:
				var want_loop: bool = not layer.ends_with("_blowoff")
				check_eq((s as AudioStreamMP3).loop, want_loop, "%s loop=%s" % [layer, want_loop])
				var len: float = s.get_length()
				check(len > (0.5 if layer.ends_with("_blowoff") else 2.5) and len < 5.0, "%s com duracao certa (%.2f s)" % [layer, len])


func test_spec_uses_profile_and_turbo_of_profile() -> void:
	var s: Dictionary = EngineSounds.spec("eng_v8", "turbo_twin", "exh_stack")
	check_eq(String(s["set"]), "exh_stack", "chamines: loops do perfil")
	check_eq((s["bands"] as Array).size(), 3, "3 camadas (lenta, media, alta)")
	check_eq(String(s["turbo"]), "exh_stack_turbo_whine", "turbina com o assobio do perfil")
	check(float(s["turbo_pitch"]) > 1.0, "turbo duplo mais agudo")
	check_eq(s["blowoffs"], ["exh_stack_blowoff"], "pssh do perfil")
	check(float(s["pitch"]) < 1.0, "V8 deixa o perfil mais grave")
	var std: Dictionary = EngineSounds.spec("eng_i6_tuned", "turbo_single", "exh_std")
	check_eq(String(std["set"]), "i6_tuned", "escape padrao: loops do proprio motor")
	check_eq((std["bands"] as Array).size(), 4, "motor: 4 camadas")
	check_eq(String(std["turbo"]), "turbo_single_whine", "escape padrao: turbo antigo")
	check(not bool(std["straight"]), "sem a camada de escape direto")
	var none: Dictionary = EngineSounds.spec("eng_i6_std", "turbo_none", "exh_chrome_cut")
	check_eq(String(none["turbo"]), "", "sem turbina: sem assobio")
	check_eq(String(none["set"]), "exh_pop", "cromado cortado: perfil com estalos")
	var d: Dictionary = EngineSounds.from_descriptor({"engine": "eng_i6_std", "turbo": "turbo_single", "exhaust": "exh_straight"})
	check_eq(String(d["set"]), "exh_rasp", "descritor -> perfil do escape direto")
	check_eq(String(d["turbo"]), "exh_rasp_turbo_whine", "descritor -> turbo do perfil")


func test_three_band_weights() -> void:
	for r in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var w: Array[float] = EngineAudio.band_weights(r, EngineAudio.CENTERS_3, EngineAudio.WIDTH_3)
		check_eq(w.size(), 3, "3 pesos")
		check_near(w[0] + w[1] + w[2], 1.0, 0.001, "somam 1 em %.2f" % r)
	check(EngineAudio.band_weights(0.0, EngineAudio.CENTERS_3, EngineAudio.WIDTH_3)[0] > 0.9, "lenta domina parado")
	check(EngineAudio.band_weights(0.5, EngineAudio.CENTERS_3, EngineAudio.WIDTH_3)[1] > 0.9, "media domina no meio")
	check(EngineAudio.band_weights(1.0, EngineAudio.CENTERS_3, EngineAudio.WIDTH_3)[2] > 0.9, "alta domina no corte")


func test_engine_audio_builds_profile_layers() -> void:
	var e := EngineAudio.new()
	Engine.get_main_loop().root.add_child(e)
	e.setup_spec(EngineSounds.spec("eng_i6_std", "turbo_single", "exh_chrome_cut"), true)
	var names: Array[String] = e.layer_names()
	for n in ["exh_pop_idle", "exh_pop_mid", "exh_pop_high", "exh_pop_turbo_whine", "jake_brake", "engine_damaged_rattle"]:
		check(n in names, "camada %s tocando" % n)
	check(not ("i6_std_idle" in names), "o perfil substitui os loops do motor")
	e.update(0.1, 0.9, 1.0, 1.0)                   # nao quebra com 3 camadas
	e.free()


func test_horn_catalog_and_profile() -> void:
	check_eq(HornCatalog.NEW_T173.size(), 3, "3 buzinas novas")
	for id in HornCatalog.IDS:
		check(RaceAudio.has_sound(id), "arquivo da buzina %s" % id)
		check(Tr.t(HornCatalog.label_key(id)) != HornCatalog.label_key(id), "nome pt-BR de %s" % id)
		if not HornCatalog.is_musical(id):
			var win: Array = HornCatalog.loop_window(id)
			check(float(win[0]) < float(win[1]), "janela de loop de %s" % id)
	check(HornCatalog.is_musical("horn_musical_dekotora"), "dekotora toca a melodia")
	check(not HornCatalog.is_musical("horn_ship_deep"), "navio segura o som")
	check_eq(HornCatalog.resolve("", "horn_musical_1"), "horn_musical_1", "automatica = a da peca")
	check_eq(HornCatalog.resolve("", ""), "horn_air_basic", "sem peca = basica")
	check_eq(HornCatalog.resolve("horn_dual_tone", "horn_musical_1"), "horn_dual_tone", "escolhida vence a da peca")
	check_eq(HornCatalog.resolve("nao_existe", ""), "horn_air_basic", "id invalido = basica")
	var gs: Node = _gs()
	gs.new_profile()
	check_eq(gs.installed_horn(), "horn_air_basic", "perfil novo: buzina basica")
	gs.set_horn("horn_ship_deep")
	check_eq(gs.installed_horn(), "horn_ship_deep", "buzina escolhida")
	check_eq(String(gs.truck_descriptor()["horn"]), "horn_ship_deep", "buzina vai no descritor de rede")
	check(gs.apply_action("set_horn", "horn_dual_tone"), "acao online set_horn")
	check_eq(String(gs.truck_descriptor()["horn"]), "horn_dual_tone", "servidor aplica a troca de buzina")
	gs.set_horn("lixo")
	check_eq(String(gs.profile["horn"]), HornCatalog.AUTO, "id invalido volta para automatica")
	gs.new_profile()


func test_server_keeps_chosen_horn_and_exhaust() -> void:
	# o servidor monta o descritor pelo perfil guardado: a buzina e o escape do perfil vao para todos
	var dir: String = "user://test_profiles_t173/"
	var store := ProfileStore.new(dir)
	var p: Node = store.get_profile("HORN7777")
	p.profile["horn"] = "horn_musical_dekotora"
	p.profile["exhaust"] = "exh_stack"
	var desc: Dictionary = p.truck_descriptor()
	check_eq(String(desc["horn"]), "horn_musical_dekotora", "descritor do servidor com a buzina do perfil")
	check_eq(String(EngineSounds.from_descriptor(desc)["set"]), "exh_stack", "os outros tocam o perfil do escape")
	store.release_all()


func test_rival_draw_is_deterministic_and_varied() -> void:
	check_eq(EngineSounds.rival_loadout(42), EngineSounds.rival_loadout(42), "mesma semente = mesmo som")
	check_eq(HornCatalog.rival_horn(42), HornCatalog.rival_horn(42), "mesma semente = mesma buzina")
	var sets: Dictionary = {}
	var horns: Dictionary = {}
	for s in 40:
		var lo: Dictionary = EngineSounds.rival_loadout(s * 7919)
		check(String(lo["exhaust"]) in EngineSounds.EXHAUST_IDS, "escape sorteado valido")
		sets[String(EngineSounds.from_descriptor(lo)["set"])] = true
		horns[HornCatalog.rival_horn(s * 7919)] = true
	check(sets.size() >= 4, "rivais variam o som (%d perfis/motores em 40)" % sets.size())
	check(horns.size() >= 4, "rivais variam a buzina (%d em 40)" % horns.size())


func test_turbo_pitch_sweep_is_short() -> void:
	# T-178: o assobio subindo quase uma oitava com o boost soava como sintetizador; agora no maximo ~7 semitons
	var lo: float = EngineAudio.turbo_pitch_for(0.0)
	var hi: float = EngineAudio.turbo_pitch_for(1.0)
	check(hi > lo, "turbina sobe o tom com o boost (spool)")
	check(12.0 * log(hi / lo) / log(2.0) <= 7.0, "subida do tom da turbina curta (%.1f semitons)" % (12.0 * log(hi / lo) / log(2.0)))
	check_near(EngineAudio.turbo_pitch_for(2.0), hi, 0.0001, "boost acima de 1 nao passa do topo")
	var bus: Node = Engine.get_main_loop().root.get_node("AudioBus")
	for n in ["turbo_single_whine", "turbo_twin_whine", "exh_rasp_turbo_whine", "exh_stack_turbo_whine", "exh_pop_turbo_whine"]:
		var s: AudioStream = bus.stream(n)
		check(s != null, "turbina %s carrega" % n)
		if s is AudioStreamMP3:
			check((s as AudioStreamMP3).loop, "turbina %s em loop" % n)


func test_sound_preview_curve() -> void:
	check(SoundPreview.rev_curve(0.0).x < 0.1, "previa comeca em marcha lenta")
	check(SoundPreview.rev_curve(1.7).x > 0.85 and SoundPreview.rev_curve(1.7).y > 0.5, "sobe ate perto do corte acelerando")
	check(SoundPreview.rev_curve(SoundPreview.DURATION).x < 0.1 and SoundPreview.rev_curve(2.5).y < 0.5, "solta e volta para a lenta")
	# T-178: o boost da previa fica sempre em 0..1 (antes valia 5,5 no comeco = guincho agudo da turbina)
	var t: float = 0.0
	while t <= SoundPreview.DURATION:
		var b: float = SoundPreview.boost_at(t)
		check(b >= 0.0 and b <= 1.0, "boost da previa em 0..1 (t=%.2f: %.2f)" % [t, b])
		t += 0.05
	check_eq(SoundPreview.boost_at(0.1), 0.0, "sem turbina antes de acelerar")
	check_near(SoundPreview.boost_at(1.7), 1.0, 0.001, "turbina cheia no alto do giro")
