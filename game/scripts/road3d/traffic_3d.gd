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
## Placas (T-130): altura (m) do centro da placa [frente, tras] por modelo (perfil de tools_dev/measure_plates.gd);
## a distancia ate a lataria sai de raios (PlateSpot). Estilo: kei amarela/preta, onibus verde, o resto branca.
const PLATE_Y: Dictionary = {
	"car_hatch": [0.45, 0.65], "car_sedan": [0.45, 0.6], "car_van": [0.45, 0.6], "car_kei_truck": [0.45, 0.62],
	"car_van01": [0.42, 0.55], "car_ascona": [0.48, 0.55], "car_falcon": [0.5, 0.62], "car_suv": [0.55, 0.62],
	"car_bus": [0.48, 0.75], "car_fumi": [0.32, 0.57]}
const KEI_MODELS: Array[String] = ["car_hatch", "car_kei_truck"]
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


func setup(path_: TrackPath, traffic_: TrafficSim, plates: LicensePlates = null) -> void:
	path = path_
	traffic = traffic_
	var scenes: Dictionary = {}          # nome do modelo -> PackedScene (so os usados nesta corrida)
	var classic: bool = "--traffic-classic" in OS.get_cmdline_user_args()
	var spots: Dictionary = {}           # modelo -> [transform da placa da frente, de tras]
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
		if plates != null:
			if not spots.has(model):
				spots[model] = plate_spots(model, n)
			var cell: int = plates.pick(plate_style(model, i), i * 7919 + car.color_id)
			plates.add_plate(n, spots[model][0], cell)
			plates.add_plate(n, spots[model][1], cell)


## Estilo da placa (PlateCatalog.Style) do carro `i` deste modelo.
static func plate_style(model: String, i: int) -> int:
	if model == "car_bus":
		return PlateCatalog.Style.GREEN
	if model in KEI_MODELS:
		return PlateCatalog.Style.BLACK if i % 5 == 0 else PlateCatalog.Style.YELLOW
	return PlateCatalog.Style.WHITE


## Transforms locais das placas [frente, tras] para o modelo instanciado em `n` (frente = -Z, traseira em z = 0).
static func plate_spots(model: String, n: Node3D) -> Array:
	var ys: Array = PLATE_Y.get(model, [0.45, 0.6])
	var size: Vector2 = LicensePlates.SIZE_TRUCK if model == "car_bus" else LicensePlates.SIZE_CAR
	var tms: Array = PlateSpot.triangle_meshes(n, minf(ys[0], ys[1]) - 0.2, maxf(ys[0], ys[1]) + 0.2)
	return [PlateSpot.plate_transform(tms, float(ys[0]), size, true, -4.0),
		PlateSpot.plate_transform(tms, float(ys[1]), size, false, 0.0)]


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
		var xf: Transform3D = path.vehicle_transform(c.z, c.x, c.length, TrafficSim.body_yaw(c))
		if c.y > 0.0 or c.out_t > 0.0:            # arremessado (T-141): pulo e rolagem pela velocidade lateral/pulo
			var roll: float = clampf(-c.vx * 0.35, -0.5, 0.5) + clampf(c.vy * 0.06, -0.25, 0.25) * signf(c.yaw_rate)
			xf = Transform3D(xf.basis * Basis(Vector3.BACK, roll), xf.origin + xf.basis.y * c.y)
		_nodes[i].transform = xf
		var ws: Array = _wheels[i]
		for k in ws.size():
			var w: Node3D = ws[k]
			# altura do pivo = raio da roda; giro = distancia / raio (frente = -Z, por isso o sinal)
			var spin: float = fmod(c.z / maxf(w.position.y, 0.1), TAU)
			w.transform.basis = Basis(Vector3.RIGHT, -spin) * (_wheel_rest[i][k] as Basis)
