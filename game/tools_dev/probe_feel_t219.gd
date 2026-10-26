extends SceneTree
## T-219: numeros do "peso" do caminhao na SIMULACAO (sem tela). Roda no codigo antigo e no novo (antes/depois).
##   godot --headless --path game -s res://tools_dev/probe_feel_t219.gd
## Imprime, para alguns caminhoes: 0-60 e 0-100 km/h, distancia ate 100 km/h, e o tempo da troca de faixa a 80 km/h
## (do 2o toque ate 50%, 90% e 98% do caminho) com o pico da velocidade lateral.

const DT: float = 1.0 / 30.0


func _initialize() -> void:
	var cases: Array = [
		["padrao (12 t: 8 t + 4 t de carga, para-choques basicos)", TruckConfig.basic_descriptor()],
		["bau cheio (contrato de 12 t)", _with(TruckConfig.basic_descriptor(), {"cargo_kg": 12000.0})],
		["bau vazio (0 t)", _with(TruckConfig.basic_descriptor(), {"cargo_kg": 0.0})],
		["Tanque (pecas pesadas ~1,3 t + V8)", {"parts": [{"id": "fb_gold_wing"}, {"id": "skirt_chrome"}, {"id": "rb_chrome"}],
			"engine": "eng_v8", "turbo": "turbo_none", "exhaust": "exh_std"}],
		["Canter (3,5 t + 2 t)", _with(TruckConfig.basic_descriptor(), {"body": "canter"})],
	]
	for c in cases:
		var acc: Array = _accel(c[1])
		var lane: Array = _lane(c[1])
		var t := TruckSim.new()
		TruckConfig.apply(t, c[1])
		print("FEEL_T219 %-55s massa %5.0f kg | 0-60 %5.1f s | 0-100 %5.1f s (%4.0f m) | troca a 80 km/h: 50%% %.2f s, 90%% %.2f s, 98%% %.2f s, pico %.2f m/s" % [
			c[0], t.mass, acc[0], acc[1], acc[2], lane[0], lane[1], lane[2], lane[3]])
	# T-219: aceleracao lateral das curvas (m/s2) a 100 km/h ou na velocidade segura, o que for menor (calibra o roll)
	if true:
		for r in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
			var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
			var tr: Track = route.build_track()
			var path := TrackPath.new(tr)
			var acc: Array[float] = []
			var z: float = 10.0
			while z < tr.length_m - 10.0:
				var k: float = angle_difference(path.yaw_at(z - 3.0), path.yaw_at(z + 3.0)) / 6.0
				var v: float = minf(100.0 / 3.6, TruckSim.curve_safe_speed(tr.curve_at(z), 1.0))
				acc.append(absf(v * v * k))
				z += 5.0
			acc.sort()
			print("FEEL_T219 curvas %s: aceleracao lateral p50 %.2f p90 %.2f max %.2f m/s2" % [r, acc[acc.size() / 2], acc[acc.size() * 9 / 10], acc[acc.size() - 1]])
	quit()


func _with(d: Dictionary, extra: Dictionary) -> Dictionary:
	var o: Dictionary = d.duplicate(true)
	o.merge(extra, true)
	return o


func _straight() -> Track:
	var tr := Track.new()
	tr.add_section(9000.0, 0.0)
	return tr


func _accel(desc: Dictionary) -> Array:
	var t := TruckSim.new()
	TruckConfig.apply(t, desc)
	var tr: Track = _straight()
	var time: float = 0.0
	var t60: float = -1.0
	while t.speed < 100.0 / 3.6 and time < 120.0:
		t.step(DT, Commands.make(0.0, 1.0, 0.0), tr)
		time += DT
		if t60 < 0.0 and t.speed >= 60.0 / 3.6:
			t60 = time
	return [t60, time, t.z]


func _lane(desc: Dictionary) -> Array:
	var t := TruckSim.new()
	TruckConfig.apply(t, desc)
	var tr: Track = _straight()
	t.speed = 80.0 / 3.6
	for n in 30:
		t.step(DT, Commands.make(0.0, 0.6, 0.0), tr)
	# 2 toques para a direita (3 passos segurando, 3 soltos)
	var time: float = 0.0
	var started: bool = false
	var marks: Array[float] = [-1.0, -1.0, -1.0]
	var peak: float = 0.0
	var x0: float = t.x
	for n in 30 * 6:
		var held: bool = (n % 6) < 3 and n < 12
		t.step(DT, Commands.make(1.0 if held else 0.0, 0.6, 0.0), tr)
		if not started and t.lane_changes > 0:
			started = true
		if started:
			time += DT
			var f: float = (t.x - x0) / (Lanes.X[t.lane] - x0)
			peak = maxf(peak, absf(t.lateral_vel) * Track.ROAD_HALF_WIDTH_M)
			for k in 3:
				if marks[k] < 0.0 and f >= [0.5, 0.9, 0.98][k]:
					marks[k] = time
	return [marks[0], marks[1], marks[2], peak]
