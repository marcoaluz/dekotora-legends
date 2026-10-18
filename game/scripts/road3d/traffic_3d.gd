class_name Traffic3D
extends Node3D
## Carros do transito em 3D (.glb do Blender), cor da pintura por carro.
## Um no por carro, reaproveitando as malhas. O tipo (carro, onibus, esportivo) vem da simulacao
## (TrafficSim.Car.kind); o modelo dentro do tipo sai de (indice + color_id), entao a mesma semente
## da sempre o mesmo transito, no servidor e nos clientes.
## Modelos com rodas separadas (nos "wheel_*", pivo no eixo) giram as rodas pela distancia andada.

## Modelos por tipo (indice = TrafficSim.Kind). Os 4 primeiros carros sao os genericos feitos por codigo;
## os outros vem de modelos de terceiros reduzidos (blender/scripts/build_traffic_*.py, creditos em LICENCAS.md).
const MODELS_BY_KIND: Array = [
	["car_hatch", "car_sedan", "car_van", "car_kei_truck", "car_van01", "car_ascona", "car_falcon", "car_suv"],
	["car_bus"],
	["car_fumi"],
]
const DIR := "res://assets/vehicles/traffic/"
const BODY_COLORS: Array[Color] = [
	Color("#2a5cc0"), Color("#c8202f"), Color("#2c9a5a"), Color("#d29a2e"), Color("#aeb8c8"), Color("#8a3fd0")]

var path: TrackPath
var traffic: TrafficSim
var _nodes: Array[Node3D] = []
var _wheels: Array = []            # por carro: Array[Node3D] com as rodas (vazio se o modelo nao tem)
var _wheel_rest: Array = []        # por carro: Array[Basis] (rotacao original de cada roda)


## Todos os modelos (sem repetir), na ordem dos tipos.
static func all_models() -> Array[String]:
	var out: Array[String] = []
	for list in MODELS_BY_KIND:
		for m in list:
			out.append(String(m))
	return out


## Modelo do carro `i` do tipo `kind` (deterministico: so depende da simulacao).
static func model_for(kind: int, i: int, color_id: int) -> String:
	var list: Array = MODELS_BY_KIND[clampi(kind, 0, MODELS_BY_KIND.size() - 1)]
	return String(list[(i + color_id) % list.size()])


func setup(path_: TrackPath, traffic_: TrafficSim) -> void:
	path = path_
	traffic = traffic_
	var scenes: Dictionary = {}          # nome do modelo -> PackedScene (so os usados nesta corrida)
	var classic: bool = "--traffic-classic" in OS.get_cmdline_user_args()
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
		var model: String = model_for(car.kind, i, car.color_id)
		if classic:                       # depuracao (--traffic-classic): so os 4 carros antigos, para comparar custo
			model = String(MODELS_BY_KIND[0][(i + car.color_id) % 4])
		if not scenes.has(model):
			scenes[model] = load("%s%s.glb" % [DIR, model]) as PackedScene
		var n: Node3D = (scenes[model] as PackedScene).instantiate() as Node3D
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var inst: MeshInstance3D = mi as MeshInstance3D
			for s in inst.mesh.get_surface_count():
				var cur: Material = inst.get_active_material(s)
				if cur != null and cur.resource_name == "paint_white":
					inst.set_surface_override_material(s, paints[car.color_id])
		var ws: Array[Node3D] = []
		var rest: Array[Basis] = []
		for w in n.find_children("wheel_*", "Node3D", true, false):
			ws.append(w as Node3D)
			rest.append((w as Node3D).transform.basis)
		_wheels.append(ws)
		_wheel_rest.append(rest)
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
		_nodes[i].transform = path.vehicle_transform(c.z, c.x, c.length, TrafficSim.body_yaw(c))
		var ws: Array = _wheels[i]
		for k in ws.size():
			var w: Node3D = ws[k]
			# altura do pivo = raio da roda; giro = distancia / raio (frente = -Z, por isso o sinal)
			var spin: float = fmod(c.z / maxf(w.position.y, 0.1), TAU)
			w.transform.basis = Basis(Vector3.RIGHT, -spin) * (_wheel_rest[i][k] as Basis)
