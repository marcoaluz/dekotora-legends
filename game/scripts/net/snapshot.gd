class_name Snapshot
extends RefCounted
## Empacota/desempacota o estado da corrida para a rede (servidor -> clientes, 20/s).
## Formato compacto com StreamPeerBuffer (little endian):
##   u32 tick · u8 n_trucks · por caminhao: u8 idx, f32 z, f32 x, f32 speed, f32 lateral_vel, u16 rpm,
##   u8 gear, u8 boost, u8 flags, u8 passing_charge, u8 draft, u8 lane, u8 signal(0..2 = -1/0/+1 +1),
##   u8 signal_time (centesimos de s), u8 tap_prev(0..2), u8 lane_change_time (centesimos),
##   u32 ack (ultimo comando aplicado)
##   · u8 n_cars · por carro: f32 z, f32 x.   flags: bit0 passing, bit1 offroad, bit2 chegou, bit3 buzina, bit4 freada forte (T-144)
## O dano completo NAO vai aqui: so quando muda, por evento ("damage").

static func pack(sim: RaceSim, acks: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u32(sim.tick)
	b.put_u8(sim.trucks.size())
	for i in sim.trucks.size():
		var t: TruckSim = sim.trucks[i]
		b.put_u8(i)
		b.put_float(t.z)
		b.put_float(t.x)
		b.put_float(t.speed)
		b.put_float(t.lateral_vel)
		b.put_u16(clampi(roundi(t.rpm), 0, 65535))
		b.put_u8(clampi(t.gear, 0, 255))
		b.put_u8(clampi(roundi(t.boost * 255.0), 0, 255))
		var flags: int = (1 if t.passing_active else 0) | (2 if t.offroad else 0) | (4 if t.finish_position > 0 else 0) \
			| (8 if t.horn else 0) | (16 if t.hard_braking else 0)
		b.put_u8(flags)
		b.put_u8(clampi(roundi(t.passing_charge * 255.0), 0, 255))
		b.put_u8(clampi(roundi(t.draft * 255.0), 0, 255))
		b.put_u8(clampi(t.lane, 0, 4))
		b.put_u8(t.signal_dir + 1)
		b.put_u8(clampi(roundi(t.signal_time * 100.0), 0, 255))
		b.put_u8(t.tap_prev + 1)
		b.put_u8(clampi(roundi(t.lane_change_time * 100.0), 0, 255))
		b.put_u32(int(acks[i]) if i < acks.size() else 0)
	var cars: Array = sim.traffic.cars if sim.traffic != null else []
	b.put_u8(mini(cars.size(), 255))
	for k in mini(cars.size(), 255):
		var c: TrafficSim.Car = cars[k]
		b.put_float(c.z)
		b.put_float(c.x)
	return b.data_array


static func unpack(data: PackedByteArray) -> Dictionary:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var out: Dictionary = {"tick": b.get_u32(), "trucks": [], "cars": []}
	var n: int = b.get_u8()
	for i in n:
		var t: Dictionary = {}
		t["idx"] = b.get_u8()
		t["z"] = b.get_float()
		t["x"] = b.get_float()
		t["speed"] = b.get_float()
		t["lateral_vel"] = b.get_float()
		t["rpm"] = b.get_u16()
		t["gear"] = b.get_u8()
		t["boost"] = float(b.get_u8()) / 255.0
		var flags: int = b.get_u8()
		t["passing"] = (flags & 1) != 0
		t["offroad"] = (flags & 2) != 0
		t["finished"] = (flags & 4) != 0
		t["horn"] = (flags & 8) != 0
		t["hard_braking"] = (flags & 16) != 0
		t["passing_charge"] = float(b.get_u8()) / 255.0
		t["draft"] = float(b.get_u8()) / 255.0
		t["lane"] = b.get_u8()
		t["signal_dir"] = int(b.get_u8()) - 1
		t["signal_time"] = float(b.get_u8()) / 100.0
		t["tap_prev"] = int(b.get_u8()) - 1
		t["lane_change_time"] = float(b.get_u8()) / 100.0
		t["ack"] = b.get_u32()
		(out["trucks"] as Array).append(t)
	var nc: int = b.get_u8()
	for k in nc:
		(out["cars"] as Array).append(Vector2(b.get_float(), b.get_float()))
	return out


## Estado de faixa/seta (precisa ser identico no cliente para a predicao concordar com o servidor).
static func _apply_lane(ts: TruckSim, t: Dictionary) -> void:
	ts.lane = int(t["lane"])
	ts.signal_dir = int(t["signal_dir"])
	ts.signal_time = float(t["signal_time"])
	ts.tap_prev = int(t["tap_prev"])
	ts.lane_change_time = float(t["lane_change_time"])


## Aplica um snapshot desempacotado a um RaceSim espelho (cliente). Nao mexe no caminhao `skip_idx`
## (o proprio jogador, controlado pela predicao).
static func apply_to(sim: RaceSim, snap: Dictionary, skip_idx: int = -1) -> void:
	for t in snap["trucks"]:
		var i: int = int(t["idx"])
		if i >= sim.trucks.size() or i == skip_idx:
			continue
		var ts: TruckSim = sim.trucks[i]
		ts.z = float(t["z"])
		ts.x = float(t["x"])
		ts.speed = float(t["speed"])
		ts.lateral_vel = float(t["lateral_vel"])
		ts.rpm = float(t["rpm"])
		ts.gear = int(t["gear"])
		ts.boost = float(t["boost"])
		ts.passing_active = bool(t["passing"])
		ts.offroad = bool(t["offroad"])
		ts.horn = bool(t["horn"])
		ts.hard_braking = bool(t["hard_braking"])
		ts.passing_charge = float(t["passing_charge"])
		ts.draft = float(t["draft"])
		_apply_lane(ts, t)
	if sim.traffic != null:
		var cars: Array = snap["cars"]
		for k in mini(cars.size(), sim.traffic.cars.size()):
			sim.traffic.cars[k].z = (cars[k] as Vector2).x
			sim.traffic.cars[k].x = (cars[k] as Vector2).y
