extends TestCase
## HUD da corrida (T-202): contas puras do velocimetro (agulha), dos 5 segmentos de status, do pisca-alerta, do radar
## vertical e do layout (PC 16:9 e celular 20:9 com area segura e botoes de toque). Nada aqui toca na simulacao.


func _sim(len_m: float = 6000.0) -> RaceSim:
	var tr := Track.new()
	tr.add_section(len_m, 0.0)
	var sim := RaceSim.new(tr)
	sim.add_truck(500.0, Lanes.X[Lanes.CENTER])
	return sim


# --- agulha do velocimetro ---------------------------------------------------------------------------------------

func test_needle_angle_covers_240_degrees_from_bottom_left() -> void:
	check_near(rad_to_deg(GaugeNeedle.angle_for(0.0)), 150.0, 0.01, "0 km/h embaixo a esquerda (150 graus)")
	check_near(rad_to_deg(GaugeNeedle.angle_for(70.0)), 270.0, 0.01, "70 km/h (meio da escala) em cima (270 graus)")
	check_near(rad_to_deg(GaugeNeedle.angle_for(140.0)), 390.0, 0.01, "140 km/h embaixo a direita (150 + 240)")
	check_near(GaugeNeedle.angle_for(400.0), GaugeNeedle.angle_for(GaugeNeedle.STOP_KMH), 0.0001, "para no pino (150 km/h)")
	check_near(GaugeNeedle.angle_for(-10.0), GaugeNeedle.angle_for(0.0), 0.0001, "nunca abaixo de zero")
	var prev: float = -INF
	for v in range(0, 151, 5):
		var a: float = GaugeNeedle.angle_for(float(v))
		check(a > prev, "angulo cresce com a velocidade (%d km/h)" % v)
		prev = a


func test_needle_follows_speed_with_small_overshoot() -> void:
	var n := GaugeNeedle.new()
	var peak: float = 0.0
	for i in 120:                                        # 2 s a 60 FPS
		n.step(1.0 / 60.0, 100.0)
		peak = maxf(peak, n.value)
	check_near(n.value, 100.0, 0.5, "chega na velocidade em 2 s")
	check(peak > 100.0, "tem um pouco de inercia (passa do alvo)")
	check(peak < 112.0, "mas passa pouco (%.1f)" % peak)
	var n2 := GaugeNeedle.new()
	n2.step(0.05, 100.0)
	check(n2.value < 60.0, "nao pula direto para o alvo no 1o quadro (%.1f)" % n2.value)


func test_needle_same_motion_at_any_frame_rate() -> void:
	var a := GaugeNeedle.new()
	var b := GaugeNeedle.new()
	for i in 20:                                         # 1 s a 20 FPS
		a.step(0.05, 80.0)
	for i in 240:                                        # 1 s a 240 FPS
		b.step(1.0 / 240.0, 80.0)
	check_near(a.value, b.value, 1.0, "20 e 240 FPS dao a mesma agulha")
	var c := GaugeNeedle.new()
	c.step(0.5, 80.0)                                    # um travamento de meio segundo nao explode
	check(c.value >= 0.0 and c.value <= GaugeNeedle.STOP_KMH, "quadro longo fica estavel")


func test_needle_kick_on_crash_and_bounded_tremor() -> void:
	var n := GaugeNeedle.new()
	for i in 120:
		n.step(1.0 / 60.0, 90.0)
	var before: float = n.value
	n.step(1.0 / 60.0, 90.0, true)
	n.step(1.0 / 60.0, 90.0)
	check(n.value < before - 1.0, "a batida derruba a agulha um pouco (%.1f -> %.1f)" % [before, n.value])
	for i in 300:
		n.step(1.0 / 60.0, 90.0)
		var s: float = n.shown(1.0)
		if absf(s - n.value) > GaugeNeedle.TREMOR_KMH + GaugeNeedle.TREMOR_RPM_KMH + 0.01:
			check(false, "tremor passou do limite (%.2f)" % (s - n.value))
			break
	check_near(n.value, 90.0, 0.5, "volta para a velocidade")
	var parked := GaugeNeedle.new()
	parked.step(0.1, 0.0)
	check(parked.shown(0.0) < 0.2, "parado a agulha quase nao treme")
	check_eq(GaugeNeedle.cap_letter(0.0, 3), "N", "parado: N no centro")
	check_eq(GaugeNeedle.cap_letter(12.0, 4), "4", "andando: a marcha")


# --- 5 segmentos de status ---------------------------------------------------------------------------------------

func test_status_levels_follow_thresholds() -> void:
	check_eq(HudStatus.level_of(1.0), HudStatus.Level.OK, "inteiro = verde")
	check_eq(HudStatus.level_of(0.66), HudStatus.Level.OK, "66% ainda verde")
	check_eq(HudStatus.level_of(0.5), HudStatus.Level.DAMAGED, "50% amarelo")
	check_eq(HudStatus.level_of(0.2), HudStatus.Level.CRITICAL, "20% vermelho")
	check_eq(HudStatus.level_of(0.0), HudStatus.Level.DESTROYED, "0% destruido")
	check_eq(HudStatus.SEGMENTS.size(), 5, "5 segmentos")


func test_status_reads_parts_systems_and_cargo() -> void:
	var t := TruckSim.new()
	t.loadout = [
		DamageModel.make_part("fb", ["front"], 10.0, 100.0),
		DamageModel.make_part("side_l", ["left"], 10.0, 100.0),
		DamageModel.make_part("rear_l", ["rear"], 10.0, 50.0),
	]
	check_eq(HudStatus.levels(t), [0, 0, 0, 0, 0] as Array[int], "caminhao novo: tudo verde")
	t.loadout[0]["dur"] = 20.0
	t.loadout[1]["dur"] = 50.0
	t.loadout[2]["dur"] = 0.0
	t.loadout[2]["broken"] = true
	t.systems["steering"] = 10.0                         # a direita nao tem peca: mostra o sistema (direcao)
	t.cargo_penalty = TruckSim.MAX_CARGO_LOSS * 0.5
	var lv: Array[int] = HudStatus.levels(t)
	check_eq(lv[0], HudStatus.Level.CRITICAL, "frente 20%")
	check_eq(lv[1], HudStatus.Level.DAMAGED, "lateral esquerda 50%")
	check_eq(lv[2], HudStatus.Level.CRITICAL, "lateral direita sem peca = direcao 10%")
	check_eq(lv[3], HudStatus.Level.DESTROYED, "traseira quebrada")
	check_eq(lv[4], HudStatus.Level.DAMAGED, "carga 50%")
	check_eq(HudStatus.parts(t, "rear"), Vector2i(0, 1), "0 de 1 peca inteira atras")
	check_eq(HudStatus.parts(t, "right"), Vector2i(0, 0), "nenhuma peca na direita")
	var d: PackedStringArray = HudStatus.detail(t, "front")
	check_eq(d.size(), 4, "detalhe: nome, estado, pecas, sistema")
	check(d[1].contains("20%"), "detalhe mostra a porcentagem (%s)" % d[1])
	check_eq(HudStatus.detail(t, "cargo").size(), 3, "carga: nome, estado, perda no premio")


func test_hazard_rule() -> void:
	var t := TruckSim.new()
	t.speed = 0.0
	check(not HudStatus.hazard(t, 30.0, false), "na contagem nao liga")
	check(not HudStatus.hazard(t, 2.0, true), "logo depois da largada nao liga")
	check(HudStatus.hazard(t, 30.0, true), "parado no meio da corrida liga")
	t.speed = 20.0
	check(not HudStatus.hazard(t, 30.0, true), "andando normal nao liga")
	t.escaping = true
	check(HudStatus.hazard(t, 30.0, true), "derrapando liga")
	t.finish_time = 90.0
	check(not HudStatus.hazard(t, 95.0, true), "depois de chegar nao liga")


func test_segments_hit_index() -> void:
	var s := DamageSegments.new()
	s.size = HudLayout.SEG
	var sw: float = s.seg_width()
	check_eq(s.index_at(Vector2(1.0, 4.0)), 0, "1o segmento")
	check_eq(s.index_at(Vector2(sw * 2.5 + DamageSegments.SEG_GAP * 2.0, 4.0)), 2, "3o segmento")
	check_eq(s.index_at(Vector2(HudLayout.SEG.x - 1.0, 4.0)), 4, "ultimo segmento")
	check_eq(s.index_at(Vector2(10.0, 60.0)), -1, "fora")
	s.tap(3)
	check_eq(s.shown(), 3, "toque abre o detalhe")
	s.tap(3)
	check_eq(s.shown(), -1, "2o toque fecha")
	s.free()


# --- radar vertical ----------------------------------------------------------------------------------------------

func test_radar_mapping() -> void:
	check_near(RadarModel.y_frac(0.0), RadarModel.ME_FRAC, 0.0001, "voce fica na altura ME_FRAC")
	check_near(RadarModel.y_frac(RadarModel.AHEAD_M), 1.0, 0.0001, "AHEAD_M no topo")
	check_near(RadarModel.y_frac(5000.0), 1.0, 0.0001, "mais longe fica no topo")
	check_near(RadarModel.y_frac(-RadarModel.BEHIND_M), 0.0, 0.0001, "BEHIND_M embaixo")
	check(RadarModel.y_frac(50.0) - RadarModel.y_frac(0.0) > RadarModel.y_frac(350.0) - RadarModel.y_frac(300.0),
			"perto ocupa mais espaco que longe (raiz)")
	check_near(RadarModel.x_frac(0.0), 0.5, 0.0001, "centro da pista no meio")
	check(RadarModel.x_frac(Lanes.X[Lanes.FIRST]) < RadarModel.x_frac(Lanes.X[Lanes.LAST]), "esquerda a esquerda")


func test_radar_blips() -> void:
	var sim := _sim()
	var rival: int = sim.add_truck(560.0, Lanes.X[Lanes.FIRST])
	sim.add_truck(500.0 + RadarModel.AHEAD_M + 50.0, 0.0)   # longe demais: fora
	sim.track.events.add({"kind": "accident", "z": 700.0, "length": 120.0, "lanes": [Lanes.LAST]})
	sim.track.events.add({"kind": "works", "z": 3000.0, "length": 200.0, "lanes": [Lanes.FIRST]})   # muito longe
	sim.traffic = TrafficSim.new(7, TrafficSim.Density.LIGHT)
	sim.traffic.cars.clear()
	var car := TrafficSim.Car.new()
	car.z = 600.0
	car.x = 0.5
	sim.traffic.cars.append(car)
	var wreck := TrafficSim.Car.new()
	wreck.z = 900.0                                       # 400 m a frente: carro comum some, so ate CAR_AHEAD_M
	wreck.wrecked = true
	sim.traffic.cars.append(wreck)
	var kinds: Array[int] = []
	for b in RadarModel.blips(sim, 0, rival):
		kinds.append(int(b["kind"]))
		if int(b["kind"]) == RadarModel.Kind.RIVAL:
			check_near(float(b["z0"]), 60.0, 0.01, "rival 60 m a frente")
		if int(b["kind"]) == RadarModel.Kind.ACCIDENT:
			check(float(b["x0"]) > 0.0, "acidente na faixa da direita")
	check_eq(kinds.count(RadarModel.Kind.ME), 1, "voce aparece uma vez")
	check_eq(kinds.count(RadarModel.Kind.RIVAL), 1, "o rival da rota aparece em dourado")
	check_eq(kinds.count(RadarModel.Kind.TRUCK), 0, "caminhao longe nao aparece")
	check_eq(kinds.count(RadarModel.Kind.CAR), 1, "carro perto aparece")
	check_eq(kinds.count(RadarModel.Kind.WRECK), 0, "carro alem de CAR_AHEAD_M nao aparece")
	check_eq(kinds.count(RadarModel.Kind.ACCIDENT), 1, "acidente a frente aparece")
	check_eq(kinds.count(RadarModel.Kind.WORKS), 0, "obra a 2,5 km nao aparece")
	check_eq(kinds.back(), RadarModel.Kind.ME, "voce e desenhado por ultimo (por cima)")
	check(RadarModel.blips(null, 0).is_empty(), "sem corrida: vazio")


# --- layout ------------------------------------------------------------------------------------------------------

func _inside(r: Rect2, area: Rect2) -> bool:
	return area.grow(0.01).encloses(r)


func test_pc_layout_fits_and_does_not_overlap() -> void:
	var l := HudLayout.new()
	l.size = Vector2(480, 270)
	l.compute()
	var screen := Rect2(Vector2.ZERO, l.size)
	var rects: Array[Rect2] = [l.clocks_rect(), l.gauge_rect(), l.strip_rect(), l.seg_rect(), l.radar,
			Rect2(l.pos_at, HudLayout.POS * l.s), Rect2(l.cam_at, HudLayout.CAM * l.s)]
	for i in rects.size():
		check(_inside(rects[i], screen), "peca %d dentro da tela %s" % [i, rects[i]])
		for j in range(i + 1, rects.size()):
			check(not rects[i].intersects(rects[j]), "pecas %d e %d nao se cobrem" % [i, j])
	check(not l.clocks_rect().intersects(l.mirror_rect()), "relogios fora do retrovisor")
	check(l.gauge_rect().position.x > l.size.x * 0.6, "velocimetro embaixo a direita")
	check(l.radar.position.x < 20.0 and l.radar.size.y > 120.0, "radar alto na borda esquerda")
	check_near(l.s, 1.0, 0.0001, "PC escala 1")


func test_phone_layout_respects_buttons_and_safe_area() -> void:
	for ts in [0.7, 1.0, 1.5]:
		var l := HudLayout.new()
		l.size = Vector2(600, 270)                     # 2400x1080 (20:9)
		l.touch = true
		l.want_scale = 1.25
		l.inset_l = 22.0                                  # entalhe (notch) na esquerda
		l.buttons = TouchControls.button_layout(l.size, ts)
		l.compute()
		var safe := Rect2(22.0, 0.0, l.size.x - 22.0, l.size.y)
		for r in l.cluster_rects() + [l.clocks_rect(), l.radar]:
			check(_inside(r, safe), "botoes %.1f: %s dentro da area segura" % [ts, r])
			check(l._clear(r), "botoes %.1f: %s longe dos botoes de toque" % [ts, r])
		check(l.pos_at.x >= 22.0 + HudLayout.M - 0.01, "POSICAO fora do entalhe")
		check(l.cluster_s >= HudLayout.MIN_SCALE, "escala minima respeitada")
		check(not l.clocks_rect().intersects(l.mirror_rect()), "relogios fora do retrovisor")
	var l2 := HudLayout.new()
	l2.size = Vector2(480, 270)                          # celular 16:9: ainda cabe
	l2.touch = true
	l2.want_scale = 1.25
	l2.buttons = TouchControls.button_layout(l2.size, 1.0)
	l2.compute()
	for r in l2.cluster_rects():
		check(l2._clear(r), "16:9 com toque: %s longe dos botoes" % r)


func test_scale_from_dpi() -> void:
	check_near(HudLayout.scale_for(false, 1080.0, 400.0), 1.0, 0.0001, "PC sempre 1")
	check_near(HudLayout.scale_for(true, 1080.0, 400.0), 1.25, 0.0001, "celular de 6,5 pol: 1,25")
	check_near(HudLayout.scale_for(true, 1600.0, 220.0), 1.0, 0.0001, "tablet grande: 1")
	check_near(HudLayout.scale_for(true, 1080.0, 0.0), 1.0, 0.0001, "DPI desconhecido: 1")
