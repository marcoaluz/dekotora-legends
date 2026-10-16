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


func _init(track_: Track = null) -> void:
	track = track_ if track_ != null else Track.make_test_track()
	finish_z = track.length_m


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
	time += dt
	tick += 1


func finished(index: int) -> bool:
	return trucks[index].z >= finish_z
