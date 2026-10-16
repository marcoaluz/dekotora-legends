class_name RoadMesh
extends Node3D
## Gera a estrada 3D em "pedacos" (chunks de ~100 m) a partir de um TrackPath: asfalto, zebra
## rosa/branca, faixas, acostamento e grama. Cada chunk e um MeshInstance3D (o Godot descarta os
## que estao fora da camera). Cores por vertice (listras alternadas) + textura de ruido no asfalto.

const CHUNK_SEGS: int = 50
const BAND_SEGS: int = 4
const GRASS_WIDTH: float = 110.0
const RUMBLE_W: float = 0.9
const SHOULDER_W: float = 1.4

const COL_ROAD_A := Color("#2a2a30")
const COL_ROAD_B := Color("#303038")
const COL_RUMBLE_A := Color("#ff2e88")
const COL_RUMBLE_B := Color("#e8edf5")
const COL_SHOULDER := Color("#1c1c21")
const COL_GRASS_A := Color("#0f3a28")
const COL_GRASS_B := Color("#0c2f21")

var path: TrackPath


func build(path_: TrackPath) -> void:
	path = path_
	var total: int = path.track.segment_count()
	var road_mat := StandardMaterial3D.new()
	road_mat.vertex_color_use_as_albedo = true
	road_mat.roughness = 0.45
	road_mat.metallic_specular = 0.6
	road_mat.albedo_texture = _noise_texture()
	road_mat.uv1_scale = Vector3(1, 1, 1)
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("#ffe9c2")
	line_mat.emission_enabled = true
	line_mat.emission = Color("#ffe9c2")
	line_mat.emission_energy_multiplier = 0.8
	line_mat.roughness = 0.5
	var start: int = 0
	while start < total:
		var end: int = mini(start + CHUNK_SEGS, total)
		_build_chunk(start, end, road_mat, line_mat)
		start = end


func _noise_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.78, 0.8))
	grad.set_color(1, Color(1, 1, 1))
	tex.color_ramp = grad
	return tex


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv_a: Vector2, uv_len: Vector2) -> void:
	# a,b = borda de tras (esq,dir); c,d = borda da frente (dir,esq). Godot: frente = sentido horario.
	var ua: Vector2 = uv_a
	var ub: Vector2 = uv_a + Vector2(uv_len.x, 0)
	var uc: Vector2 = uv_a + uv_len
	var ud: Vector2 = uv_a + Vector2(0, uv_len.y)
	st.set_color(col)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ud)
	st.add_vertex(d)
	st.set_uv(uc)
	st.add_vertex(c)


func _edge(i: int, lateral: float) -> Vector3:
	var a: float = path.yaw[i]
	var r := Vector3(cos(a), 0.0, -sin(a))
	return path.pos[i] + r * lateral


func _build_chunk(s0: int, s1: int, road_mat: Material, line_mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = Track.ROAD_HALF_WIDTH_M
	for i in range(s0, s1):
		var band: bool = (i / BAND_SEGS) % 2 == 0
		var v: float = float(i) * 0.25
		var road_col: Color = COL_ROAD_A if band else COL_ROAD_B
		var rum_col: Color = COL_RUMBLE_A if band else COL_RUMBLE_B
		var grass_col: Color = COL_GRASS_A if band else COL_GRASS_B
		var j: int = i + 1
		var vl := Vector2(0.0, v)
		var ulen := Vector2(1.0, 0.5)
		# asfalto
		_quad(st, _edge(i, -half), _edge(i, half), _edge(j, half), _edge(j, -half), road_col, vl, ulen)
		# zebra
		_quad(st, _edge(i, -half - RUMBLE_W), _edge(i, -half), _edge(j, -half), _edge(j, -half - RUMBLE_W), rum_col, vl, ulen)
		_quad(st, _edge(i, half), _edge(i, half + RUMBLE_W), _edge(j, half + RUMBLE_W), _edge(j, half), rum_col, vl, ulen)
		# acostamento + grama
		var sh: float = half + RUMBLE_W
		_quad(st, _edge(i, -sh - SHOULDER_W), _edge(i, -sh), _edge(j, -sh), _edge(j, -sh - SHOULDER_W), COL_SHOULDER, vl, ulen)
		_quad(st, _edge(i, sh), _edge(i, sh + SHOULDER_W), _edge(j, sh + SHOULDER_W), _edge(j, sh), COL_SHOULDER, vl, ulen)
		var gw: float = sh + SHOULDER_W
		_quad(st, _edge(i, -gw - GRASS_WIDTH), _edge(i, -gw), _edge(j, -gw), _edge(j, -gw - GRASS_WIDTH), grass_col, vl, Vector2(8.0, 0.5))
		_quad(st, _edge(i, gw), _edge(i, gw + GRASS_WIDTH), _edge(j, gw + GRASS_WIDTH), _edge(j, gw), grass_col, vl, Vector2(8.0, 0.5))
		# faixas tracejadas (so nas bandas pares)
		if band:
			for lane in [-0.5, 0.0, 0.5]:
				var c: float = lane * half
				_quad(lines, _edge(i, c - 0.09) + Vector3.UP * 0.02, _edge(i, c + 0.09) + Vector3.UP * 0.02,
					_edge(j, c + 0.09) + Vector3.UP * 0.02, _edge(j, c - 0.09) + Vector3.UP * 0.02, Color.WHITE, Vector2.ZERO, Vector2.ONE)
		# faixas continuas de borda
		for side in [-1.0, 1.0]:
			var e: float = side * (half - 0.35)
			_quad(lines, _edge(i, e - 0.07) + Vector3.UP * 0.02, _edge(i, e + 0.07) + Vector3.UP * 0.02,
				_edge(j, e + 0.07) + Vector3.UP * 0.02, _edge(j, e - 0.07) + Vector3.UP * 0.02, Color.WHITE, Vector2.ZERO, Vector2.ONE)
	st.generate_normals()
	lines.generate_normals()
	var mi := MeshInstance3D.new()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, road_mat)
	lines.commit(mesh)
	mesh.surface_set_material(1, line_mat)
	mi.mesh = mesh
	mi.visibility_range_end = 520.0 if int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1 else 380.0
	add_child(mi)
