class_name Traffic3D
extends Node3D
## Carros do transito em 3D. Provisorio: carroceria + cabine + lanternas em codigo (modelos .glb de
## carros genericos entram na P46). Um no por carro, reaproveitando malhas e materiais.

const BODY_COLORS: Array[Color] = [
	Color("#2a5cc0"), Color("#c8202f"), Color("#2c9a5a"), Color("#d29a2e"), Color("#aeb8c8"), Color("#8a3fd0")]

var path: TrackPath
var traffic: TrafficSim
var _nodes: Array[Node3D] = []


func setup(path_: TrackPath, traffic_: TrafficSim) -> void:
	path = path_
	traffic = traffic_
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.9, 0.75, 4.5)
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(1.65, 0.6, 2.3)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#0b1226")
	glass.metallic = 0.4
	glass.roughness = 0.08
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color("#ff2a2a")
	tail.emission_enabled = true
	tail.emission = Color("#ff2a2a")
	tail.emission_energy_multiplier = 3.5
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.4, 0.16, 0.06)
	var mats: Array[StandardMaterial3D] = []
	for c in BODY_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.5
		m.roughness = 0.3
		mats.append(m)
	for car in traffic.cars:
		var n := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = mats[car.color_id]
		body.position = Vector3(0, 0.7, -2.25)
		n.add_child(body)
		var cab := MeshInstance3D.new()
		cab.mesh = cab_mesh
		cab.material_override = glass
		cab.position = Vector3(0, 1.3, -2.5)
		n.add_child(cab)
		for sx in [-0.65, 0.65]:
			var lamp := MeshInstance3D.new()
			lamp.mesh = lamp_mesh
			lamp.material_override = tail
			lamp.position = Vector3(sx, 0.85, 0.02)
			n.add_child(lamp)
		add_child(n)
		_nodes.append(n)


func refresh() -> void:
	for i in traffic.cars.size():
		var c: TrafficSim.Car = traffic.cars[i]
		_nodes[i].transform = path.vehicle_transform(c.z, c.x, TrafficSim.CAR_LEN)
