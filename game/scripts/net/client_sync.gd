class_name ClientSync
extends RefCounted
## Sincronizacao no cliente (P61/P62): mantem um RaceSim "espelho" da corrida do servidor.
##  - Predicao: o caminhao do proprio jogador roda a mesma TruckSim com os comandos locais, sem
##    esperar o servidor. Quando chega um snapshot, volta ao estado do servidor (no tick confirmado
##    pelo ack) e reaplica os comandos ainda nao confirmados (reconciliacao).
##  - Interpolacao: os outros caminhoes e o transito sao desenhados ~100 ms no passado, entre dois snapshots.
##  - Colisao/dano: o servidor manda; aqui so se aplica o que ele envia.

const SNAP_BUFFER_MAX: int = 12
const SNAP_THRESHOLD_Z: float = 2.5          # erro maior que isto: teleporta em vez de suavizar
const SNAP_THRESHOLD_X: float = 0.2
const CORRECTION_DECAY: float = 8.0          # 1/s: velocidade com que o erro visual some

var sim: RaceSim
var me: int = -1
var predict: bool = true
var render_delay_ms: int = int(Protocol.INTERPOLATION_DELAY * 1000.0)
var tick: int = 0                            # numero do ultimo comando enviado
var correction: Vector2 = Vector2.ZERO       # (z, x) deslocamento visual que decai
var last_error: Vector2 = Vector2.ZERO       # ultimo erro de predicao medido (para depuracao)
var server_tick: int = 0
var snapshots_received: int = 0
var _history: Array[Dictionary] = []         # [{tick, cmd}] comandos ainda nao confirmados
var _snaps: Array[Dictionary] = []           # [{t, s}] snapshots recebidos (t = ms de chegada)


## Monta o espelho a partir do `setup` do servidor (rota, semente, grid com os caminhoes).
func setup(setup_: Dictionary, my_truck: int) -> void:
	me = my_truck
	var rules: Dictionary = setup_["rules"]
	var route: RouteDef = load("res://data/routes/%s.tres" % rules["route"]) as RouteDef
	var track: Track = route.build_track() if route != null else Track.make_test_track()
	sim = RaceSim.new(track, int(rules["traffic"]), int(setup_["seed"]))
	sim.freight = route.freight if route != null else 25000
	var grid: Array = setup_["grid"]
	for entry in grid:
		var i: int = int(entry["idx"])
		var idx: int = sim.add_truck(-float(i) * Room.GRID_GAP, Room.GRID_X[i % 4])
		sim.trucks[idx].is_bot = bool(entry["bot"])
		TruckConfig.apply(sim.trucks[idx], entry["loadout"])
	tick = 0
	_history.clear()
	_snaps.clear()


func my_truck() -> TruckSim:
	return sim.trucks[me]


## Chame a 30/s: guarda o comando e (com predicao) avanca o proprio caminhao. Devolve o numero do comando.
func local_step(cmd: Commands, dt: float = RaceSim.FIXED_DT) -> int:
	tick += 1
	_history.append({"tick": tick, "cmd": cmd.duplicate_cmd()})
	if _history.size() > 240:
		_history.pop_front()
	if predict:
		sim.trucks[me].step(dt, cmd, sim.track)
		sim.time += dt
	return tick


func on_snapshot(data: PackedByteArray, now_ms: int) -> void:
	var snap: Dictionary = Snapshot.unpack(data)
	snapshots_received += 1
	server_tick = int(snap["tick"])
	_snaps.append({"t": now_ms, "s": snap})
	if _snaps.size() > SNAP_BUFFER_MAX:
		_snaps.pop_front()
	_reconcile(snap)


func _find_truck(snap: Dictionary, idx: int) -> Dictionary:
	for t in snap["trucks"]:
		if int(t["idx"]) == idx:
			return t
	return {}


func _reconcile(snap: Dictionary) -> void:
	var st: Dictionary = _find_truck(snap, me)
	if st.is_empty():
		return
	var tr: TruckSim = sim.trucks[me]
	var old_z: float = tr.z
	var old_x: float = tr.x
	_copy_state(tr, st)
	if not predict:
		last_error = Vector2.ZERO
		return
	var ack: int = int(st["ack"])
	while not _history.is_empty() and int(_history[0]["tick"]) <= ack:
		_history.pop_front()
	for h in _history:                        # reaplica o que o servidor ainda nao viu
		tr.step(RaceSim.FIXED_DT, h["cmd"], sim.track)
	var err := Vector2(old_z - tr.z, old_x - tr.x)
	last_error = err
	if absf(err.x) > SNAP_THRESHOLD_Z or absf(err.y) > SNAP_THRESHOLD_X:
		correction = Vector2.ZERO             # erro grande: aceita o servidor de uma vez
	else:
		correction += err                     # erro pequeno: some suavemente


func _copy_state(tr: TruckSim, st: Dictionary) -> void:
	tr.z = float(st["z"])
	tr.x = float(st["x"])
	tr.speed = float(st["speed"])
	tr.lateral_vel = float(st["lateral_vel"])
	tr.rpm = float(st["rpm"])
	tr.gear = int(st["gear"])
	tr.engine.gear = tr.gear
	tr.engine.rpm = tr.rpm
	tr.boost = float(st["boost"])
	tr.engine.boost = tr.boost
	tr.passing_charge = float(st["passing_charge"])
	tr.draft = float(st["draft"])
	tr.offroad = bool(st["offroad"])
	tr.passing_active = bool(st["passing"])
	Snapshot._apply_lane(tr, st)
	if bool(st["finished"]) and tr.finish_position == 0:
		tr.finish_position = 1


## Interpola os outros caminhoes e o transito para o instante `now_ms - atraso`. Chame todo frame.
func interpolate(now_ms: int, dt: float) -> void:
	correction = correction.lerp(Vector2.ZERO, clampf(CORRECTION_DECAY * dt, 0.0, 1.0))
	if _snaps.is_empty():
		return
	var target: int = now_ms - render_delay_ms
	var a: Dictionary = _snaps[0]
	var b: Dictionary = _snaps[_snaps.size() - 1]
	for i in range(_snaps.size() - 1):
		if int(_snaps[i]["t"]) <= target and int(_snaps[i + 1]["t"]) >= target:
			a = _snaps[i]
			b = _snaps[i + 1]
			break
	var span: float = float(int(b["t"]) - int(a["t"]))
	var f: float = clampf((float(target - int(a["t"])) / span) if span > 0.0 else 1.0, 0.0, 1.0)
	if target > int(b["t"]):
		f = 1.0 + minf(float(target - int(b["t"])) / 1000.0, 0.25) * 20.0   # extrapola um pouco (limitado)
	for i in sim.trucks.size():
		if i == me and predict:
			continue
		var ta: Dictionary = _find_truck(a["s"], i)
		var tb: Dictionary = _find_truck(b["s"], i)
		if ta.is_empty() or tb.is_empty():
			continue
		var ts: TruckSim = sim.trucks[i]
		ts.z = lerpf(float(ta["z"]), float(tb["z"]), f)
		ts.x = lerpf(float(ta["x"]), float(tb["x"]), f)
		ts.speed = lerpf(float(ta["speed"]), float(tb["speed"]), f)
		ts.lateral_vel = lerpf(float(ta["lateral_vel"]), float(tb["lateral_vel"]), f)
		ts.rpm = float(tb["rpm"])
		ts.gear = int(tb["gear"])
		ts.boost = float(tb["boost"])
		ts.passing_active = bool(tb["passing"])
		ts.offroad = bool(tb["offroad"])
		ts.draft = float(tb["draft"])
		ts.passing_charge = float(tb["passing_charge"])
		Snapshot._apply_lane(ts, tb)
		if bool(tb["finished"]) and ts.finish_position == 0:
			ts.finish_position = 1
	if sim.traffic != null:
		var ca: Array = a["s"]["cars"]
		var cb: Array = b["s"]["cars"]
		for k in mini(mini(ca.size(), cb.size()), sim.traffic.cars.size()):
			sim.traffic.cars[k].z = lerpf((ca[k] as Vector2).x, (cb[k] as Vector2).x, f)
			sim.traffic.cars[k].x = lerpf((ca[k] as Vector2).y, (cb[k] as Vector2).y, f)


## Dano completo de um caminhao enviado pelo servidor (so quando muda).
func apply_damage(d: Dictionary) -> void:
	var i: int = int(d["idx"])
	if i < 0 or i >= sim.trucks.size():
		return
	var t: TruckSim = sim.trucks[i]
	for p in d["parts"]:
		for lp in t.loadout:
			if String(lp["id"]) == String(p[0]):
				lp["dur"] = float(p[1])
				lp["broken"] = bool(p[2])
	for k in d["systems"]:
		t.systems[k] = float(d["systems"][k])
	t.mass = float(d["mass"])
	t.refresh_damage_effects()


## Posicao para DESENHAR o proprio caminhao: predicao + correcao suave.
func my_draw_z() -> float:
	return sim.trucks[me].z + correction.x


func my_draw_x() -> float:
	return sim.trucks[me].x + correction.y
