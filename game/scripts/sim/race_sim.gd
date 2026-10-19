class_name RaceSim
extends RefCounted
## Avanca a corrida um tick de cada vez: todos os caminhoes. Passo fixo de 1/30 s,
## igual no aparelho e no servidor. Tambem e a fonte unica da verdade do estado.

const FIXED_DT: float = 1.0 / 30.0

var track: Track
var trucks: Array[TruckSim] = []
var commands: Array[Commands] = []
var time: float = 0.0
var tick: int = 0
var finish_z: float = 0.0
var freight: int = 20000
var deadline: float = 0.0              # prazo de entrega (s) desde a largada; 0 = sem prazo
var _deadline_fired: bool = false
var finish_order: Array[int] = []      # indices na ordem de chegada
var _prev_ahead: Dictionary = {}       # "i:j" -> true se i estava a frente de j (para contar ultrapassagens)
const DRAFT_RANGE: float = 28.0
const DRAFT_ALIGN: float = 0.22
const DRAFT_BUILD: float = 0.7         # por segundo
var traffic: TrafficSim
var collision := Collision.new()
var events: Array[Dictionary] = []     # eventos para a apresentacao (esvazie com drain_events)


func _init(track_: Track = null, traffic_density: int = -1, seed_: int = 1234) -> void:
	track = track_ if track_ != null else Track.make_test_track()
	finish_z = track.length_m
	if traffic_density >= 0:
		traffic = TrafficSim.new(seed_, traffic_density)
	if not track.events.is_empty():
		set_events(track.events)


## Eventos de pista (T-139): liga a lista a pista, ao transito (desvio) e tira os carros de dentro dos bloqueios.
func set_events(evs: TrackEvents) -> void:
	track.events = evs
	if traffic != null:
		traffic.set_events(evs)


func add_truck(start_z: float = 0.0, start_x: float = 0.0) -> int:
	var t := TruckSim.new()
	t.z = start_z
	t.x = start_x
	t.lane = Lanes.nearest(start_x)
	trucks.append(t)
	commands.append(Commands.new())
	return trucks.size() - 1


func set_command(index: int, cmd: Commands) -> void:
	commands[index] = cmd


func step(dt: float = FIXED_DT) -> void:
	for i in trucks.size():
		trucks[i].step(dt, commands[i], track)
		if not trucks[i].event_contact.is_empty():
			_event_hit(i, trucks[i].event_contact)
		_brake_events(i)
	if traffic != null and not trucks.is_empty():
		var lead: float = trucks[0].z
		var rear: float = trucks[0].z
		for t in trucks:
			lead = maxf(lead, t.z)
			rear = minf(rear, t.z)
		traffic.step(dt, lead, rear, trucks)
		for i in trucks.size():
			events.append_array(collision.resolve_traffic(trucks[i], i, traffic))
	events.append_array(collision.resolve_trucks(trucks, dt))
	if not track.events.is_empty():              # T-139: nobody is pushed past the end of a lane
		for t in trucks:
			t.x = EventContact.wall_x(track.events, t.x, t.z, t.length, TruckSim.WIDTH_X * 0.5, dt)
		if traffic != null:
			for c in traffic.cars:
				c.x = EventContact.wall_x(track.events, c.x, c.z, c.length, c.width_x * 0.5, dt)
	_update_draft_and_passing(dt)
	_update_overtakes()
	_update_finish()
	time += dt
	tick += 1
	_update_deadline()


## Contato com um evento de pista (EventContact): cone = perda de carga; veiculo parado = batida com dano
## (regras de colisao: DamageModel com a massa do veiculo parado); fim de faixa raspando = toque na carga;
## chapas de aco das obras acima do limite = carga sacudindo (cargo_hit pelo excesso, sem dano).
func _event_hit(i: int, c: Dictionary) -> void:
	var t: TruckSim = trucks[i]
	var kind: String = String(c["kind"])
	var ev: TrackEvents.Event = track.events.list[int(c["event"])]
	var out: Dictionary = {"type": "event_" + kind, "truck": i, "zone": String(c["zone"]), "force": float(c["dv"]),
		"event": TrackEvents.KIND_IDS[ev.kind], "broken": [] as Array[String], "damage": 0.0}
	if kind == "obstacle":
		var dmg: float = DamageModel.impact_damage(float(c["dv"]), EventContact.OBSTACLE_MASS)
		out["broken"] = DamageModel.apply_impact(t, String(c["zone"]), dmg)
		out["damage"] = dmg
		t.cargo_touch()
		t.cargo_hit(float(c["dv"]))
	elif kind == "plates":
		t.cargo_hit(float(c["dv"]) * EventContact.PLATE_CARGO)
	else:
		t.cargo_touch()
	events.append(out)


## Freada forte (T-144): eventos de inicio e fim (a apresentacao tambem le o estado direto, inclusive na predicao).
func _brake_events(i: int) -> void:
	var t: TruckSim = trucks[i]
	if t.hard_brake_started:
		events.append({"type": "hard_brake", "truck": i, "speed": t.brake_speed0, "intensity": t.brake_intensity})
	elif t.hard_brake_ended:
		events.append({"type": "brake_release", "truck": i, "lost": t.brake_lost})


## Vacuo: atras de outro caminhao/carro, na mesma linha, a menos de DRAFT_RANGE.
func _update_draft_and_passing(dt: float) -> void:
	for i in trucks.size():
		var me: TruckSim = trucks[i]
		var target: float = 0.0
		var nose: float = me.z + me.length
		if me.speed > 25.0:
			for j in trucks.size():
				if j == i:
					continue
				var o: TruckSim = trucks[j]
				var gap: float = o.z - nose
				if gap > 0.0 and gap < DRAFT_RANGE and absf(o.x - me.x) < DRAFT_ALIGN:
					target = 1.0 - gap / DRAFT_RANGE
			if traffic != null:
				for c in traffic.cars:
					var gap2: float = c.z - nose
					if gap2 > 0.0 and gap2 < DRAFT_RANGE and absf(c.x - me.x) < DRAFT_ALIGN:
						target = maxf(target, 1.0 - gap2 / DRAFT_RANGE)
		me.draft = move_toward(me.draft, target, DRAFT_BUILD * dt)
		# Passing contra humanos: so tremor e susto sonoro (evento para a apresentacao)
		if me.passing_active:
			for j in trucks.size():
				var o2: TruckSim = trucks[j]
				var ahead: float = o2.z - me.z
				if j != i and not o2.is_bot and ahead > 0.0 and ahead < 40.0 and absf(o2.x - me.x) < 0.3:
					events.append({"type": "passing_scare", "from": i, "to": j})


func _update_overtakes() -> void:
	for i in trucks.size():
		for j in trucks.size():
			if i == j:
				continue
			var key: String = "%d:%d" % [i, j]
			var ahead_now: bool = trucks[i].z > trucks[j].z + 1.0
			var behind_now: bool = trucks[i].z < trucks[j].z - 1.0
			if _prev_ahead.has(key) and not bool(_prev_ahead[key]) and ahead_now:
				trucks[i].overtakes += 1
				events.append({"type": "overtake", "truck": i, "over": j})
			if ahead_now:
				_prev_ahead[key] = true
			elif behind_now:
				_prev_ahead[key] = false


## Segundos que faltam para o prazo (cresce sem limite se nao ha prazo).
func time_left() -> float:
	return maxf(deadline - time, 0.0) if deadline > 0.0 else INF


## Acabou o prazo: quem ainda nao chegou perde (evento "timeout" para a tela de tempo esgotado).
func _update_deadline() -> void:
	if deadline <= 0.0 or _deadline_fired or time < deadline:
		return
	_deadline_fired = true
	for i in trucks.size():
		if trucks[i].finish_position == 0:
			trucks[i].timed_out = true
			events.append({"type": "timeout", "truck": i, "time": time})


func deadline_passed() -> bool:
	return _deadline_fired


func _update_finish() -> void:
	for i in trucks.size():
		if trucks[i].finish_position == 0 and not trucks[i].timed_out and trucks[i].z >= finish_z:
			finish_order.append(i)
			trucks[i].finish_position = finish_order.size()
			trucks[i].finish_time = time
			events.append({"type": "finish", "truck": i, "position": finish_order.size(), "time": time})


## A corrida acaba quando todos os humanos chegaram (ou, sem humanos, todos) ou quando o prazo acaba.
func is_over() -> bool:
	if _deadline_fired:
		return true
	var humans: int = 0
	for t in trucks:
		if not t.is_bot:
			humans += 1
			if t.finish_position == 0:
				return false
	if humans == 0:
		return finish_order.size() >= trucks.size()
	return true


func result_for(index: int) -> Dictionary:
	var t: TruckSim = trucks[index]
	var pos: int = t.finish_position if t.finish_position > 0 else trucks.size()
	return RaceRules.build_result(t, pos, freight, t.finish_time, deadline)


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out


func finished(index: int) -> bool:
	return trucks[index].z >= finish_z
