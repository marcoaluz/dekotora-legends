class_name Traffic3D
extends Node3D
## Carros do transito em 3D: 4 modelos genericos (.glb do Blender), cor da pintura por carro.
## Um no por carro, reaproveitando as malhas.

const MODELS: Array[String] = ["car_hatch", "car_sedan", "car_van", "car_kei_truck"]
const DIR := "res://assets/vehicles/traffic/"
const BODY_COLORS: Array[Color] = [
	Color("#2a5cc0"), Color("#c8202f"), Color("#2c9a5a"), Color("#d29a2e"), Color("#aeb8c8"), Color("#8a3fd0")]

var path: TrackPath
var traffic: TrafficSim
var _nodes: Array[Node3D] = []


func setup(path_: TrackPath, traffic_: TrafficSim) -> void:
	path = path_
	traffic = traffic_
	var scenes: Array[PackedScene] = []
	for m in MODELS:
		scenes.append(load("%s%s.glb" % [DIR, m]) as PackedScene)
	var paints: Array[StandardMaterial3D] = []
	for c in BODY_COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.metallic = 0.5
		mat.roughness = 0.3
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.8
		paints.append(mat)
	for i in traffic.cars.size():
		var car: TrafficSim.Car = traffic.cars[i]
		var n: Node3D = scenes[(i + car.color_id) % scenes.size()].instantiate() as Node3D
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var inst: MeshInstance3D = mi as MeshInstance3D
			for s in inst.mesh.get_surface_count():
				var cur: Material = inst.get_active_material(s)
				if cur != null and cur.resource_name == "paint_white":
					inst.set_surface_override_material(s, paints[car.color_id])
		add_child(n)
		_nodes.append(n)


func car_count() -> int:
	return _nodes.size()


func car_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for n in _nodes:
		out.append(n.global_transform)
	return out


func refresh() -> void:
	for i in traffic.cars.size():
		var c: TrafficSim.Car = traffic.cars[i]
		_nodes[i].transform = path.vehicle_transform(c.z, c.x, TrafficSim.CAR_LEN)
