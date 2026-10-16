class_name RoadMesh
extends Node3D
## Gera a estrada 3D em "pedacos" (chunks de ~100 m) a partir de um TrackPath: asfalto texturizado (cor +
## rugosidade: trechos lisos parecem molhados a noite), zebra rosa/branca, faixas, acostamento, mureta de
## concreto, terreno com grama e, no litoral (`kind` = coast), guard-rail metalico e praia descendo ate o mar
## do lado direito. Cada chunk e um MeshInstance3D (o Godot descarta os que estao fora da camera).
## Texturas: assets/textures/ (blender/scripts/build_road_textures.py). UV em metros (projecao de cima).

const CHUNK_SEGS: int = 50
const BAND_SEGS: int = 4
const GRASS_WIDTH: float = 110.0
const RUMBLE_W: float = 0.9
const SHOULDER_W: float = 1.4
const BARRIER_W: float = 0.6
const BARRIER_IN: float = 13.0             # face interna da mureta: alem do limite fisico da sim (|x| <= 1,6 = 11,5 m + meia largura)
const TEX_TILE: float = 4.0                 # metros por repeticao da textura
const COAST_GRASS: float = 14.0             # litoral: grama do lado do mar antes da praia
const COAST_SAND: float = 16.0              # largura da praia (desce ate o mar)
const SEA_DROP: float = 1.6

const COL_RUMBLE_A := Color("#ff2e88")
const COL_RUMBLE_B := Color("#e8edf5")
const TEX_DIR := "res://assets/textures/"

var path: TrackPath
var kind: StringName = &"city"
var _mats: Dictionary = {}


func build(path_: TrackPath, kind_: StringName = &"city") -> void:
	path = path_
	kind = kind_
	_make_materials()
	var total: int = path.track.segment_count()
	var start: int = 0
	while start < total:
		var end: int = mini(start + CHUNK_SEGS, total)
		_build_chunk(start, end)
		start = end


func _tex(name: String) -> Texture2D:
	var p: String = TEX_DIR + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _make_materials() -> void:
	var road := StandardMaterial3D.new()
	road.vertex_color_use_as_albedo = true
	road.albedo_texture = _tex("asphalt_albedo.png")
	road.albedo_color = Color(1.25, 1.25, 1.3) if road.albedo_texture else Color("#2c2c33")
	road.roughness_texture = _tex("asphalt_rough.png")
	road.roughness = 1.0
	road.metallic_specular = 0.6
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats["road"] = road
	var paint := StandardMaterial3D.new()      # zebra (cor por vertice)
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.5
	_mats["paint"] = paint
	var line := StandardMaterial3D.new()
	line.albedo_color = Color("#ffe9c2")
	line.emission_enabled = true
	line.emission = Color("#ffe9c2")
	line.emission_energy_multiplier = 0.8
	line.roughness = 0.5
	_mats["line"] = line
	var ground := StandardMaterial3D.new()
	ground.albedo_texture = _tex("grass.png")
	ground.albedo_color = Color(0.55, 0.62, 0.6) if ground.albedo_texture else Color("#0f3a28")
	ground.roughness = 0.95
	ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["ground"] = ground
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = _tex("sand.png")
	sand.albedo_color = Color(0.7, 0.68, 0.7)
	sand.roughness = 0.9
	_mats["sand"] = sand
	var barrier := StandardMaterial3D.new()
	barrier.albedo_color = Color("#8d9099")
	barrier.roughness = 0.85
	_mats["barrier"] = barrier
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("#c4ccd8")
	rail.metallic = 0.85
	rail.roughness = 0.3
	_mats["rail"] = rail


func _edge(i: int, lateral: float, up: float = 0.0) -> Vector3:
	var a: float = path.yaw[i]
	var r := Vector3(cos(a), 0.0, -sin(a))
	return path.pos[i] + r * lateral + Vector3.UP * up


## Quadrilatero (a,b = tras; c,d = frente) com UV em metros vista de cima (texturas repetiveis).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color = Color.WHITE) -> void:
	for v in [a, c, b, a, d, c]:
		st.set_color(col)
		st.set_uv(Vector2(v.x, v.z) / TEX_TILE)
		st.add_vertex(v)


## Faixa lateral entre `l0` e `l1` (alturas h0, h1) do segmento i ao j. Funciona dos dois lados.
func _strip(st: SurfaceTool, i: int, j: int, l0: float, l1: float, h0: float = 0.0, h1: float = 0.0, col: Color = Color.WHITE) -> void:
	if l0 < l1:
		_quad(st, _edge(i, l0, h0), _edge(i, l1, h1), _edge(j, l1, h1), _edge(j, l0, h0), col)
	else:
		_quad(st, _edge(i, l1, h1), _edge(i, l0, h0), _edge(j, l0, h0), _edge(j, l1, h1), col)


## Mureta de concreto tipo New Jersey (perfil trapezio) com a face interna em `inner`; side = -1 ou 1.
func _barrier(st: SurfaceTool, i: int, j: int, inner: float, side: float) -> void:
	var prof: Array = [[0.0, 0.0], [0.05, 0.25], [0.2, 0.85], [0.4, 0.85], [0.55, 0.25], [BARRIER_W, 0.0]]
	for k in prof.size() - 1:
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		_strip(st, i, j, side * (inner + float(p0[0])), side * (inner + float(p1[0])), float(p0[1]), float(p1[1]))


## Guard-rail metalico continuo (litoral, lado do mar): lamina em duas alturas.
func _rail(st: SurfaceTool, i: int, j: int, lat: float) -> void:
	for h in [[0.55, 0.85], [0.3, 0.42]]:
		_quad(st, _edge(i, lat, float(h[0])), _edge(i, lat, float(h[1])), _edge(j, lat, float(h[1])), _edge(j, lat, float(h[0])))
		_quad(st, _edge(i, lat, float(h[1])), _edge(i, lat, float(h[0])), _edge(j, lat, float(h[0])), _edge(j, lat, float(h[1])))


func _build_chunk(s0: int, s1: int) -> void:
	var sts: Dictionary = {}
	for k in ["road", "paint", "line", "ground", "sand", "barrier", "rail"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st
	var half: float = Track.ROAD_HALF_WIDTH_M
	var sh: float = half + RUMBLE_W
	var gw: float = sh + SHOULDER_W
	var coast: bool = kind == &"coast"
	for i in range(s0, s1):
		var band: bool = (i / BAND_SEGS) % 2 == 0
		var j: int = i + 1
		_strip(sts["road"], i, j, -half, half)                                  # asfalto
		_strip(sts["road"], i, j, -gw, -sh, 0.0, 0.0, Color(0.8, 0.8, 0.82))    # acostamentos (mais escuros)
		_strip(sts["road"], i, j, sh, gw, 0.0, 0.0, Color(0.8, 0.8, 0.82))
		var rum: Color = COL_RUMBLE_A if band else COL_RUMBLE_B                 # zebra
		_strip(sts["paint"], i, j, -sh, -half, 0.0, 0.0, rum)
		_strip(sts["paint"], i, j, half, sh, 0.0, 0.0, rum)
		if band:                                                                # faixas tracejadas
			for lane in [-0.5, 0.0, 0.5]:
				var c: float = lane * half
				_strip(sts["line"], i, j, c - 0.09, c + 0.09, 0.02, 0.02)
		for side in [-1.0, 1.0]:                                                # faixas continuas de borda
			var e: float = side * (half - 0.35)
			_strip(sts["line"], i, j, e - 0.07, e + 0.07, 0.02, 0.02)
		# lado esquerdo: mureta + grama ate o horizonte
		var bo: float = BARRIER_IN + BARRIER_W
		_barrier(sts["barrier"], i, j, BARRIER_IN, -1.0)
		_strip(sts["ground"], i, j, -bo - GRASS_WIDTH, -gw)                    # grama (por baixo da mureta tambem)
		if coast:                                                               # lado do mar: guard-rail, grama curta e praia
			_rail(sts["rail"], i, j, BARRIER_IN + 0.3)
			_strip(sts["ground"], i, j, gw, gw + COAST_GRASS)
			_strip(sts["sand"], i, j, gw + COAST_GRASS, gw + COAST_GRASS + COAST_SAND, 0.0, -SEA_DROP)
		else:
			_barrier(sts["barrier"], i, j, BARRIER_IN, 1.0)
			_strip(sts["ground"], i, j, gw, bo + GRASS_WIDTH)
	var mesh := ArrayMesh.new()
	var used: Array = ["road", "paint", "line", "ground", "barrier"]
	used.append_array(["sand", "rail"] if coast else [])
	for k in used:
		var st: SurfaceTool = sts[k]
		st.generate_normals()
		var arrays: Array = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[k])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 520.0 if int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1 else 380.0
	add_child(mi)
