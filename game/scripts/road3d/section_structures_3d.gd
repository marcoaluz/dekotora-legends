class_name SectionStructures3D
extends Node3D
## Estrutura das pontes (T-153, RouteDef.bridges), so visual: o tabuleiro estreito do trecho de 2 faixas (as muretas e
## a borda sao do RoadMesh) apoiado em pilares duplos com viga de topo a cada PIER_EVERY m, 3 longarinas e a laje por
## baixo, e as cabeceiras: aterro de grama descendo ate o mar e um muro de concreto embaixo do tabuleiro.
## O mar e o chao do cenario (CityBuilder, y = WATER_Y). Custo: 2 chamadas por ponte visivel (concreto + aterro).

const PIER_EVERY: float = 30.0
const PIECE_M: float = 10.0               # longarinas e laje em pedacos (acompanham a curva e a rampa)
const DECK_DROP: float = 1.6              # = perfil da mureta com borda (RoadMesh._barrier2 drop)
const WATER_Y: float = -1.2               # CityBuilder._add_ground (litoral)
const FOOT_Y: float = -3.5                # pe dos pilares, dentro da agua
const SLOPE_M: float = 14.0               # comprimento do aterro das cabeceiras
const PIER_TOP_FRAC: float = 0.74         # T-163: topo do pilar em T = 74% da largura do tabuleiro (pega as 3 longarinas)
const CONCRETE := Color(0.66, 0.65, 0.62)
const DARK := Color(0.46, 0.45, 0.43)
const FASCIA := Color(0.58, 0.57, 0.54)

var path: TrackPath
var counts: Dictionary = {}
var _cube: Array = TrackEvents3D.CUBE


func build(path_: TrackPath, bridges: Array[Vector2], tod: TimeOfDay) -> void:
	path = path_
	for br in bridges:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var gr := SurfaceTool.new()
		gr.begin(Mesh.PRIMITIVE_TRIANGLES)
		_piers(st, br)
		_deck(st, br)
		_abutment(st, gr, br.x, 1.0)
		_abutment(st, gr, br.x + br.y, -1.0)
		_add(st, _concrete_mat(tod))
		_add(gr, _grass_mat())


## Laterais (m) das bordas do tabuleiro em z: Vector2(esquerda < 0, direita > 0).
func _edges(z: float) -> Vector2:
	var p: Vector3 = LaneSections.profile(path.track.events, z)
	return Vector2(-(p.x + RoadMesh.BARRIER_W), p.y + RoadMesh.BARRIER_W)


func _road_y(z: float) -> float:
	return path.center_at(z).y


func _piers(st: SurfaceTool, br: Vector2) -> void:
	var z: float = br.x + PIER_EVERY * 0.5
	while z < br.x + br.y - 6.0:
		var e: Vector2 = _edges(z)
		var c: float = (e.x + e.y) * 0.5
		var w: float = e.y - e.x
		var b := Basis(Vector3.UP, path.yaw_at(z))
		if PontesKit.enabled() and PierT.available():         # T-163: pilar em T da Ponte A sob as longarinas
			var top: float = _road_y(z) - DECK_DROP - 0.9
			var foot: Vector3 = _pt(z, c, 0.0)
			foot.y = FOOT_Y
			PierT.append(st, foot, b, top - FOOT_Y, w * PIER_TOP_FRAC, CONCRETE)
			var pipe: Vector3 = _pt(z, c + 1.1, 0.0)               # T-199: drain pipe down the pier
			pipe.y = (top + FOOT_Y) * 0.5
			_box(st, b, pipe + b.z * 1.02, Vector3(0.18, top - FOOT_Y, 0.18), Color(0.3, 0.31, 0.33))
			counts["pier"] = int(counts.get("pier", 0)) + 1
			z += PIER_EVERY
			continue
		var cap_top: float = -DECK_DROP - 0.45
		_box(st, b, _pt(z, c, cap_top - 0.55), Vector3(w + 0.6, 1.1, 2.0), CONCRETE)        # viga de topo
		var h: float = (_road_y(z) + cap_top - 1.1) - FOOT_Y
		if h > 0.3:
			for sx in [-1.0, 1.0]:
				var foot: Vector3 = path.world_point(z, (c + sx * (w * 0.5 - 2.2)) / Track.ROAD_HALF_WIDTH_M, 0.0)
				foot.y = FOOT_Y + h * 0.5
				_box(st, b, foot, Vector3(1.6, h, 1.6), DARK)
		counts["pier"] = int(counts.get("pier", 0)) + 1
		z += PIER_EVERY


## Laje por baixo do tabuleiro e 3 longarinas, em pedacos que seguem a pista.
func _deck(st: SurfaceTool, br: Vector2) -> void:
	var z: float = br.x
	while z < br.x + br.y - 0.5:
		var zm: float = minf(z + PIECE_M * 0.5, br.x + br.y - 0.5)
		var len_: float = minf(PIECE_M, br.x + br.y - z) + 0.05
		var e: Vector2 = _edges(zm)
		var c: float = (e.x + e.y) * 0.5
		var w: float = e.y - e.x
		var b: Basis = path.basis_at(zm)
		_box(st, b, _pt(zm, c, -DECK_DROP + 0.12), Vector3(w, 0.24, len_), CONCRETE)
		for k in [-1.0, 0.0, 1.0]:
			_box(st, b, _pt(zm, c + k * w * 0.32, -DECK_DROP - 0.45), Vector3(0.7, 0.9, len_), DARK)
		for ex in [e.x - 0.12, e.y + 0.12]:                     # T-199: fascia beam with a drip line on both edges
			_box(st, b, _pt(zm, ex, -DECK_DROP * 0.5 - 0.1), Vector3(0.24, DECK_DROP + 0.2, len_ - 0.06), FASCIA)
			_box(st, b, _pt(zm, ex + signf(ex) * 0.1, -DECK_DROP - 0.16), Vector3(0.12, 0.12, len_ - 0.06), DARK)
		z += PIECE_M


## Cabeceira em `z` (dir = +1 na entrada da ponte, -1 na saida): aterro de grama descendo para dentro do vao e muro
## de concreto embaixo do tabuleiro.
func _abutment(st: SurfaceTool, gr: SurfaceTool, z: float, dir: float) -> void:
	var e: Vector2 = _edges(z)
	var zw: float = z + dir * SLOPE_M
	var water: float = WATER_Y - 0.4 - _road_y(zw)                    # altura da agua relativa a pista em zw
	var bo: float = RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W
	var spans: Array = [[-bo - RoadMesh.GRASS_WIDTH, e.x], [e.y, Track.ROAD_HALF_WIDTH_M + RoadMesh.RUMBLE_W
		+ RoadMesh.SHOULDER_W + RoadMesh.COAST_GRASS + RoadMesh.COAST_SAND]]
	for s in spans:
		var a: Vector3 = _pt(z, float(s[0]), 0.0)
		var bb: Vector3 = _pt(z, float(s[1]), 0.0)
		var cc: Vector3 = _pt(zw, float(s[1]), water)
		var d: Vector3 = _pt(zw, float(s[0]), water)
		_quad_up(gr, a, bb, cc, d, Color(1, 1, 1))
	var top: float = -DECK_DROP
	var bottom: float = WATER_Y - 0.4 - _road_y(z)
	var b := Basis(Vector3.UP, path.yaw_at(z))
	var h: float = top - bottom
	if h > 0.2:
		_box(st, b, _pt(z + dir * 1.0, (e.x + e.y) * 0.5, bottom + h * 0.5), Vector3(e.y - e.x + 0.8, h, 2.0), CONCRETE)


func _pt(z: float, lat_m: float, h: float) -> Vector3:
	return path.world_point(z, lat_m / Track.ROAD_HALF_WIDTH_M, h)


func _box(st: SurfaceTool, b: Basis, c: Vector3, size: Vector3, col: Color) -> void:
	var half: Vector3 = size * 0.5
	for f in _cube:
		var n: Vector3 = (b * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var p: Array[Vector3] = []
		for v in q:
			p.append(c + b * ((v as Vector3) * half))
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(p[i])


## Quadrilatero virado para cima (aterro), UV em metros vistos de cima.
func _quad_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	var flip: bool = n.y < 0.0
	if flip:
		n = -n
	for v in ([a, c, b, a, d, c] if not flip else [a, b, c, a, c, d]):
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.z) / RoadMesh.TEX_TILE)
		st.add_vertex(v)


func _concrete_mat(tod: TimeOfDay) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	var tex: String = "res://assets/textures/concrete_streaks.png"
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex) as Texture2D
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	if tod != null and tod.lamps_on:
		m.albedo_color = Color(0.85, 0.85, 0.9)
	return m


func _grass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex: String = "res://assets/textures/grass.png"
	m.albedo_texture = load(tex) as Texture2D if ResourceLoader.exists(tex) else null
	m.albedo_color = Color(0.55, 0.62, 0.6) if m.albedo_texture else Color("#0f3a28")
	m.roughness = 0.95
	return m


func _add(st: SurfaceTool, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 700.0
	add_child(mi)
