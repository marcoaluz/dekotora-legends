extends TestCase
## T-239 (pedido do Marco): freando, todas as luzes ficam vermelhas; a seta acende EM CIMA da lampada (frente e tras,
## com e sem para-choque da oficina, em todos os caminhoes); a porta de tras do bau fica sem luzes (so as do
## para-choque); a luz de freio vai pela rede (protocolo 19).

const PF := preload("res://tests/test_part_fit.gd")
const DOOR_BODIES: Array[String] = ["base", "leve", "longo", "carreta", "canter", "alubox", "pinkbox"]


func _flat_track() -> Track:
	var track := Track.new()
	track.add_section(4000.0, 0.0)
	return track


# ---------------------------------------------------------------- simulacao e rede

func test_brake_lamp_follows_pedal_with_hysteresis() -> void:
	var t := TruckSim.new()
	var tr: Track = _flat_track()
	t.speed = 20.0
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 0.0, 1.0, false), tr)
	check(t.brake_lamp, "freio apertado: luz de freio acesa")
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 0.0, 0.1, false), tr)
	check(t.brake_lamp, "freio leve depois de apertar continua aceso (histerese)")
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 1.0, 0.0, false), tr)
	check(not t.brake_lamp, "soltou: apaga")
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 0.0, 0.1, false), tr)
	check(not t.brake_lamp, "freio de bot bem leve (0,1) nao acende do nada")
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 0.0, 0.3, false), tr)
	check(t.brake_lamp, "freio de bot de 0,3 acende")


func test_snapshot_carries_brake_lamp() -> void:
	check(Protocol.VERSION >= 19, "protocolo 19 (T-239: luz de freio no snapshot)")
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	sim.add_truck(0.0, 0.0)
	sim.add_truck(0.0, 0.5)
	sim.trucks[1].brake_lamp = true
	var snap: Dictionary = Snapshot.unpack(Snapshot.pack(sim, [0, 0]))
	check(not bool(snap["trucks"][0]["brake_lamp"]) and bool(snap["trucks"][1]["brake_lamp"]), "bit da luz de freio")
	var mirror := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	mirror.add_truck(0.0, 0.0)
	mirror.add_truck(0.0, 0.5)
	Snapshot.apply_to(mirror, snap)
	check(mirror.trucks[1].brake_lamp and not mirror.trucks[0].brake_lamp, "espelho do cliente recebe a luz de freio")


func test_signal_stays_on_during_lane_change() -> void:
	var t := TruckSim.new()
	var tr: Track = _flat_track()
	t.speed = 20.0
	t.step(RaceSim.FIXED_DT, Commands.make(1.0, 1.0, 0.0, false), tr)    # 1o toque: liga a seta
	check(t.shown_signal() == 1, "1o toque: seta direita")
	t.step(RaceSim.FIXED_DT, Commands.make(0.0, 1.0, 0.0, false), tr)
	t.step(RaceSim.FIXED_DT, Commands.make(1.0, 1.0, 0.0, false), tr)    # 2o toque: troca
	check(t.signal_dir == 0 and t.lane_change_time > 0.0, "2o toque troca de faixa (a sim apaga signal_dir)")
	check(t.shown_signal() == 1, "a seta continua piscando durante a troca")
	for k in 120:
		t.step(RaceSim.FIXED_DT, Commands.make(0.0, 1.0, 0.0, false), tr)
	check(t.shown_signal() == 0, "chegou na faixa: apaga")


# ---------------------------------------------------------------- caminhao

func _truck(body: String, cab: String) -> TruckNode:
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = cab if cab != "" and cab != "x" else CabCatalog.DEFAULT
	t._ready()                                   # fora da arvore: monta o modelo na hora
	return t


func test_every_truck_door_without_lamps_and_signals_on_lamps() -> void:
	var n: int = 0
	for m in PF.models():
		var body: String = String(m["body"])
		var t: TruckNode = _truck(body, String(m["cab"]))
		var data: Dictionary = m["data"]
		var tag: String = String(m["stem"])
		if body in DOOR_BODIES:
			check(RearDoorLamps.zone(data).size != Vector3.ZERO, "%s: tem porta de bau" % tag)
		check(RearDoorLamps.lamps_left(t.model, data) == 0, "%s: porta de tras sem luzes" % tag)
		var meas: Dictionary = data["measure"]
		var box: Dictionary = meas["box"]
		for i in 4:
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var bl: AABB = t.signals.box_of(i, t)
			var c: Vector3 = bl.get_center()
			check(c.x * side > 0.3, "%s seta %d: do lado certo (x=%.2f)" % [tag, i, c.x])
			for nd in t.signals.slots[i]:
				if (nd as Node).has_meta("halo"):
					check((nd as Node3D).position.distance_to(c) < 0.2, "%s seta %d: halo em cima da lampada" % [tag, i])
					continue
				var one: AABB = PartFit.rel_xform(nd, t) * (nd as MeshInstance3D).mesh.get_aabb()
				check(one.size.length() < 0.4, "%s seta %d: do tamanho de uma lampada (%.2f m)" % [tag, i, one.size.length()])
			if i < 2:
				check(t.signals.spots[i] == "cab", "%s seta %d: na lanterna da cabine (%s)" % [tag, i, t.signals.spots[i]])
				var hl: AABB = TruckSockets.aabb_of(meas["headlights"]["l" if i == 0 else "r"])
				check(c.y > hl.position.y - 0.05 and c.y < hl.end.y + 0.2, "%s seta %d: na altura do farol (y=%.2f)" % [tag, i, c.y])
				check(absf(c.z - float(meas["cab"]["front_z"])) < 0.5, "%s seta %d: na frente da cabine" % [tag, i])
			else:
				check(t.signals.spots[i] == "factory", "%s seta %d: na lanterna do para-choque de fabrica (%s)" % [tag, i, t.signals.spots[i]])
				check(c.y < float(box["bottom_y"]) and c.z > float(box["rear_z"]) - 0.15, "%s seta %d: no para-choque (y=%.2f z=%.2f)" % [tag, i, c.y, c.z])
		n += 1
		t.free()
	check(n >= 23, "%d caminhoes conferidos" % n)


func test_signals_go_to_workshop_bumpers() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for spec in [["base", "chata", "rb_grand_panel", "fb_fan_amber"], ["canter", "", "rb_torpedo", "fb_box_amber"],
			["pinkbox", "", "rb_bullet", "fb_deck_neon"], ["leve", "jac", "rb_square_row", "fb_fan_gold"]]:
		var t: TruckNode = _truck(spec[0], spec[1])
		var defs: Array[PartDef] = [gs.part(spec[2]), gs.part(spec[3])]
		t.apply_loadout(defs)
		var rb: Node3D = t._acc_nodes[spec[2]][0]
		var rbox: AABB = PartFit.aabb_in(rb, t)
		for i in 4:
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var c: Vector3 = t.signals.box_of(i, t).get_center()
			check(c.x * side > 0.2, "%s/%s seta %d: lado certo" % [spec[0], spec[2], i])
			if i >= 2:
				check(t.signals.spots[i] == "part", "%s seta %d: na lanterna do para-choque da oficina" % [spec[0], i])
				check(rbox.grow(0.02).has_point(c), "%s seta %d: dentro da peca %s" % [spec[0], i, spec[2]])
			else:
				check(t.signals.spots[i] == "bumper", "%s seta %d: no ponto SIGNAL do para-choque da frente" % [spec[0], i])
		if t._stock_rear != null:
			check(not t._stock_rear.visible, "%s: lanterna de fabrica do jogo some com o para-choque da oficina" % spec[0])
		t.apply_loadout([] as Array[PartDef])
		check(t.signals.spots[2] == "factory" and t.signals.spots[0] == "cab", "%s: tirando as pecas a seta volta" % spec[0])
		if t._stock_rear != null:
			check(t._stock_rear.visible, "%s: lanterna de fabrica do jogo volta" % spec[0])
		t.free()


func test_signal_blinks_only_its_side() -> void:
	var t: TruckNode = _truck("base", "chata")
	t.set_signal(-1)
	check(t.signal_lit(), "seta comeca acesa")
	var vis: Array[bool] = []
	for i in 4:
		vis.append((t.signals.slots[i][0] as Node3D).visible)
	check(vis == [true, false, true, false], "seta esquerda: frente e tras da esquerda (%s)" % str(vis))
	t.set_signal(2)
	check((t.signals.slots[1][0] as Node3D).visible and (t.signals.slots[3][0] as Node3D).visible, "pisca-alerta: os dois lados")
	t.free()


func test_brake_turns_every_light_red() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t: TruckNode = _truck("base", "chata")
	var defs: Array[PartDef] = [gs.part("rb_grand_panel"), gs.part("fb_deck_neon")]
	t.apply_loadout(defs)
	t.set_lights_on(false)                       # de dia: as luzinhas estao apagadas
	check(t._lamp_mats.size() >= 4, "luzinhas, LED e lanterna com material de luz (%d)" % t._lamp_mats.size())
	check(not t._red_mats.is_empty(), "lanterna vermelha de fabrica tem copia por caminhao")
	var red0: float = t._red_mats[0].emission_energy_multiplier
	t.set_brake(true, 0.04)
	check(t.brake_level() > 0.3 and t.brake_level() < 1.0, "transicao rapida, mas nao instantanea (%.2f)" % t.brake_level())
	t.set_brake(true, 0.1)
	check(is_equal_approx(t.brake_level(), 1.0), "aceso em ~0,08 s")
	for k in t._lamp_mats:
		var sm: ShaderMaterial = t._lamp_mats[k]
		check(float(sm.get_shader_parameter("brake")) == 1.0, "%s vermelho no freio" % k)
		check(float(sm.get_shader_parameter("brake_level")) >= 0.7, "%s acende mesmo de dia" % k)
	check(t._red_mats[0].emission_energy_multiplier > red0 * 1.5, "lanterna vermelha de fabrica brilha mais")
	t.set_brake(false, 1.0)
	check(t.brake_level() == 0.0, "soltou: volta ao normal")
	for k in t._lamp_mats:
		check(float((t._lamp_mats[k] as ShaderMaterial).get_shader_parameter("brake")) == 0.0, "%s volta a cor dele" % k)
	check(is_equal_approx(t._red_mats[0].emission_energy_multiplier, red0), "lanterna de fabrica volta ao brilho normal")
	t.free()
