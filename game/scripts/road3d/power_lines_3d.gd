class_name PowerLines3D
extends Node3D
## Postes de energia de concreto com fios (電柱, T-163), so visuais e deterministicos (lugares em PowerLineLayout).
## Poste do kit "road" (power_pole.glb / power_pole_tr.glb com transformador, ~190-220 triangulos, cor por vertice
## x concreto). Fios: 3 de energia (pontas da travessa e topo) + 1 de telefone, em catenaria entre os postes da
## mesma corrida, como LINHAS (1 pixel, sem triangulos). Custo por bloco de BLOCK_M visivel: 1 chamada dos postes
## + 1 dos fios. Modo baixo: sem fios e um poste a cada 2. --no-poles (ou --no-pontes-kit) desliga.

const BLOCK_M: float = 400.0
const POLE_RANGE: float = 520.0
const WIRE_RANGE: float = 380.0
const WIRE_SEGS: int = 8
const SAG: float = 0.025                 # flecha = 2,5% do vao (o fio do kit: ~0,9 m em 40 m)
## Pontos dos fios no poste (x atravessando a pista, y altura, z ao longo), da linha POLE_WIRES do Blender.
const WIRES: Array[Vector3] = [Vector3(1.621, 10.583, -0.183), Vector3(-0.004, 11.418, 0.01),
	Vector3(-1.631, 10.583, -0.194), Vector3(0.45, 7.45, 0.2)]

var poles: Array = []                    # PowerLineLayout.poles (depois do build)
var keep_out: Array = []                 # T-164: embaixo do viaduto (OverpassLayout.keep_out) nao ha poste
var counts: Dictionary = {}
var tris: int = 0


func build(path: TrackPath, route_id: String, kind: StringName, tod: TimeOfDay, tunnels: Array[Vector2]) -> void:
	if not PontesKit.poles_enabled():
		return
	poles = PowerLineLayout.poles(route_id, kind, path.track, tunnels)
	if not keep_out.is_empty():                  # T-164: tira os postes de baixo do viaduto (e corta os fios ali)
		var kept: Array = []
		var bump: int = 0
		for p in poles:
			if OverpassLayout.blocked(keep_out, transform_of(path, p).origin, 2.0):
				bump += 1
				continue
			kept.append([p[0], p[1], p[2], int(p[3]) + bump * 1000])
		poles = kept
	if poles.is_empty():
		return
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	var mat: StandardMaterial3D = PontesKit.concrete(tod, 0.5)
	var plain: ArrayMesh = PontesKit.mesh("power_pole", mat)
	var trafo: ArrayMesh = PontesKit.mesh("power_pole_tr", mat)
	if plain == null:
		return
	var batch := MeshBatch.new(BLOCK_M, POLE_RANGE)
	var wires: Dictionary = {}           # bloco -> PackedVector3Array (pares de pontos)
	var prev: Array = []
	var k: int = 0
	for p in poles:
		var z: float = float(p[0])
		var xf: Transform3D = transform_of(path, p)
		if q >= 1 or k % 2 == 0:
			batch.add(trafo if int(p[2]) == 1 and trafo != null else plain, xf, z)
			counts["pole"] = int(counts.get("pole", 0)) + 1
		if q >= 1 and not prev.is_empty() and int(prev[3]) == int(p[3]):
			_span(wires, transform_of(path, prev), xf, float(prev[0]))
		prev = p
		k += 1
	batch.commit(self)
	tris = batch.tris
	var wm: StandardMaterial3D = _wire_material(tod)
	for bi in wires:
		var am := ArrayMesh.new()
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = wires[bi]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		am.surface_set_material(0, wm)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = WIRE_RANGE
		add_child(mi)
		counts["wire_seg"] = int(counts.get("wire_seg", 0)) + (wires[bi] as PackedVector3Array).size() / 2
	if "--fps-log" in OS.get_cmdline_user_args():
		print("PONTES: postes de energia ", counts, "  triangulos=", tris)


## Transform do poste [z, lado, ...]: na lateral LATERAL_M do lado dele, travessa atravessando a pista.
static func transform_of(path: TrackPath, p: Array) -> Transform3D:
	var z: float = float(p[0])
	var pos: Vector3 = path.world_point(z, float(p[1]) * PowerLineLayout.LATERAL_M / Track.ROAD_HALF_WIDTH_M, -0.15)
	return Transform3D(Basis(Vector3.UP, path.yaw_at(z)), pos)


## Pontos de cada fio entre dois postes (catenaria aproximada por parabola), para desenho e testes.
static func span_points(a: Transform3D, b: Transform3D, wire: Vector3) -> PackedVector3Array:
	var pa: Vector3 = a * wire
	var pb: Vector3 = b * wire
	var sag: float = pa.distance_to(pb) * SAG
	var out := PackedVector3Array()
	for s in WIRE_SEGS + 1:
		var t: float = float(s) / float(WIRE_SEGS)
		out.append(pa.lerp(pb, t) + Vector3.DOWN * (4.0 * sag * t * (1.0 - t)))
	return out


func _span(wires: Dictionary, a: Transform3D, b: Transform3D, z: float) -> void:
	var bi: int = int(floor(z / BLOCK_M))
	if not wires.has(bi):
		wires[bi] = PackedVector3Array()
	var arr: PackedVector3Array = wires[bi]
	for w in WIRES:
		var pts: PackedVector3Array = span_points(a, b, w)
		for s in WIRE_SEGS:
			arr.append(pts[s])
			arr.append(pts[s + 1])
	wires[bi] = arr


func _wire_material(tod: TimeOfDay) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var day: float = tod.day_amount if tod != null else 1.0
	m.albedo_color = Color(0.16, 0.17, 0.19).lerp(Color(0.05, 0.05, 0.07), 1.0 - day)
	return m
