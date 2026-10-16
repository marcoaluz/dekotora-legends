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
var traffic: TrafficSim
var collision := Collision.new()
var events: Array[Dictionary] = []     # eventos para a apresentacao (esvazie com drain_events)


func _init(track_: Track = null, traffic_density: int = -1, seed_: int = 1234) -> void:
	track = track_ if track_ != null else Track.make_test_track()
	finish_z = track.length_m
	if traffic_density >= 0:
		traffic = TrafficSim.new(seed_, traffic_density)


func add_truck(start_z: float = 0.0, start_x: float = 0.0) -> int:
	var t := TruckSim.new()
	t.z = start_z
	t.x = start_x
	trucks.append(t)
	commands.append(Commands.new())
	return trucks.size() - 1


func set_command(index: int, cmd: Commands) -> void:
	commands[index] = cmd


func step(dt: float = FIXED_DT) -> void:
	for i in trucks.size():
		trucks[i].step(dt, commands[i], track)
	if traffic != null and not trucks.is_empty():
		var lead: float = trucks[0].z
		var rear: float = trucks[0].z
		for t in trucks:
			lead = maxf(lead, t.z)
			rear = minf(rear, t.z)
		traffic.step(dt, lead, rear)
		for i in trucks.size():
			events.append_array(collision.resolve_traffic(trucks[i], i, traffic))
	events.append_array(collision.resolve_trucks(trucks, dt))
	time += dt
	tick += 1


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out


func finished(index: int) -> bool:
	return trucks[index].z >= finish_z
