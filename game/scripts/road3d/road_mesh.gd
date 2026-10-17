class_name RoadMesh
extends Node3D
## Gera a estrada 3D em "pedacos" (chunks de ~100 m) a partir de um TrackPath, com cara de via expressa
## japonesa: asfalto texturizado com marcas de pneu escuras nas trilhas de roda, remendos e trechos
## recapeados (cor por vertice, sem textura extra), acostamento cinza (sem zebra de autodromo), faixas
## brancas tracejadas que viram AMARELAS continuas nas curvas fortes (proibido mudar de faixa), linha de
## borda continua, mureta de concreto com manchas de chuva, terreno com grama e, por cenario:
## - litoral (`coast`): guard-rail metalico e praia descendo ate o mar do lado direito;
## - cidade (`city`): VIADUTO (tabuleiro a DECK_CITY m do chao, borda de concreto, chao la embaixo) e
##   barreiras de som translucidas em trechos alternados.
## Dentro dos tuneis (RouteDef.tunnels) o asfalto recebe a luz de sodio pintada (faixas laranja).
## Cada chunk e um MeshInstance3D (o Godot descarta os que estao fora da camera).
## Texturas: assets/textures/ (blender/scripts/build_road_textures.py). UV em metros.

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
const DECK_CITY: float = 9.0                # altura do viaduto na cidade
const SOUND_BLOCK_M: float = 300.0          # barreira de som em blocos alternados
const LANE_W: float = 3.6
## Sub-faixas de uma faixa de rolamento (inicio em m, multiplicador de cor): trilhas de roda mais escuras.
const LANE_BANDS: Array = [[0.0, 1.0], [0.5, 0.74], [1.15, 0.97], [2.45, 0.74], [3.1, 1.0]]

const TEX_DIR := "res://assets/textures/"

var path: TrackPath
var kind: StringName = &"city"
var tod: TimeOfDay
var tunnels: Array[Vector2] = []
var _mats: Dictionary = {}
var _deck: float = 0.0
var _used: Dictionary = {}                  # SurfaceTool com algum vertice neste pedaco


## Altura do tabuleiro (viaduto) do cenario; 0 = estrada no chao.
static func deck_height(kind_: StringName) -> float:
	return DECK_CITY if kind_ == &"city" else 0.0


static func sound_wall_at(z: float) -> bool:
	return int(z / SOUND_BLOCK_M) % 2 == 1


## z esta dentro de algum tunel (Vector2(inicio, comprimento)), com folga `margin` m?
static func in_tunnel(z: float, list: Array[Vector2], margin: float = 0.0) -> bool:
	for t in list:
		if z >= t.x - margin and z <= t.x + t.y + margin:
			return true
	return false


func build(path_: TrackPath, kind_: StringName = &"city", tod_: TimeOfDay = null, tunnels_: Array[Vector2] = []) -> void:
	path = path_
	kind = kind_
	tod = tod_ if tod_ != null else TimeOfDay.by_id(&"night")
	tunnels = tunnels_
	_deck = deck_height(kind)
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
	road.albedo_texture = _tex("cc0/asphalt_02_diff_1k.jpg")              # Poly Haven, CC0 (assets/LICENCAS.md)
	road.roughness_texture = _tex("cc0/asphalt_02_rough_1k.jpg")
	if road.albedo_texture == null:                                         # reserva: textura procedural
		road.albedo_texture = _tex("asphalt_albedo.png")
		road.roughness_texture = _tex("asphalt_rough.png")
	road.albedo_color = Color(1.3, 1.3, 1.34).lerp(Color(0.85, 0.84, 0.82), tod.day_amount) if road.albedo_texture else Color("#2c2c33")
	road.uv1_scale = Vector3(0.7, 0.7, 1.0)                                  # uma repeticao a cada ~5,7 m
	road.roughness = tod.road_roughness       # noite: asfalto umido (reflete mais)
	road.metallic_specular = 0.6
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats["road"] = road
	var troad: StandardMaterial3D = road.duplicate() as StandardMaterial3D   # tunel: asfalto pre-iluminado pelo sodio
	troad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	troad.albedo_color = Color(1.1, 1.1, 1.1)
	_mats["troad"] = troad
	var tbar := StandardMaterial3D.new()                                      # mureta dentro do tunel (pre-iluminada)
	tbar.vertex_color_use_as_albedo = true
	tbar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats["tbarrier"] = tbar
	for k in ["line", "yline"]:
		var c: Color = Color("#f2efe6") if k == "line" else Color("#ffaa1e")
		var line := StandardMaterial3D.new()
		line.albedo_color = c
		line.emission_enabled = tod.line_emission > 0.0
		line.emission = c
		line.emission_energy_multiplier = tod.line_emission
		line.roughness = 0.5
		_mats[k] = line
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
	var barrier := StandardMaterial3D.new()       # concreto com manchas de chuva escorrida (UV: metros na pista x altura)
	barrier.albedo_texture = _tex("concrete_streaks.png")
	barrier.albedo_color = Color(1, 1, 1) if barrier.albedo_texture else Color("#8d9099")
	barrier.vertex_color_use_as_albedo = true
	barrier.roughness = 0.85
	barrier.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["barrier"] = barrier
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("#c4ccd8")
	rail.metallic = 0.85
	rail.roughness = 0.3
	_mats["rail"] = rail
	var glass := StandardMaterial3D.new()         # barreira de som (acrilico translucido)
	glass.albedo_color = Color(0.62, 0.8, 0.86, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.1
	glass.metallic = 0.3
	_mats["glass"] = glass


func _edge(i: int, lateral: float, up: float = 0.0) -> Vector3:
	var a: float = path.yaw[i]
	var r := Vector3(cos(a), 0.0, -sin(a))
	return path.pos[i] + r * lateral + Vector3.UP * up


## Quadrilatero (a,b = tras; c,d = frente) com UV em metros vista de cima (texturas repetiveis).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color = Color.WHITE) -> void:
	_used[st] = true
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


## Como _strip, mas UV = (metros ao longo da pista, altura): para paredes (textura escorre de cima para baixo).
func _wall_strip(st: SurfaceTool, i: int, j: int, l0: float, l1: float, h0: float, h1: float, col: Color = Color.WHITE) -> void:
	var u0: float = float(i) * Track.SEG_LEN / TEX_TILE
	var u1: float = float(j) * Track.SEG_LEN / TEX_TILE
	var vs: Array = [[_edge(i, l0, h0), Vector2(u0, 0.85 - h0)], [_edge(i, l1, h1), Vector2(u0, 0.85 - h1)],
		[_edge(j, l1, h1), Vector2(u1, 0.85 - h1)], [_edge(j, l0, h0), Vector2(u1, 0.85 - h0)]]   # v = 0 no topo da mureta
	var order: Array = [0, 2, 1, 0, 3, 2] if l0 < l1 else [0, 1, 2, 0, 2, 3]   # mesma orientacao de _strip
	_used[st] = true
	for k in order:
		st.set_color(col)
		st.set_uv(vs[k][1] / Vector2(TEX_TILE, 1.6))
		st.add_vertex(vs[k][0])


## Mureta de concreto tipo New Jersey (perfil trapezio) com a face interna em `inner`; side = -1 ou 1.
func _barrier(st: SurfaceTool, i: int, j: int, inner: float, side: float, col: Color = Color.WHITE) -> void:
	var prof: Array = [[0.0, 0.0], [0.05, 0.25], [0.2, 0.85], [0.4, 0.85], [0.55, 0.25], [BARRIER_W, 0.0]]
	if _deck > 0.0:
		prof[prof.size() - 1] = [BARRIER_W, -1.6]                     # viaduto: a face externa desce ate a borda do tabuleiro
	for k in prof.size() - 1:
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		_wall_strip(st, i, j, side * (inner + float(p0[0])), side * (inner + float(p1[0])), float(p0[1]), float(p1[1]), col)


## Lamina vertical com as duas faces (guard-rail, barreira de som).
func _blade(st: SurfaceTool, i: int, j: int, lat: float, h0: float, h1: float) -> void:
	_quad(st, _edge(i, lat, h1), _edge(i, lat, h0), _edge(j, lat, h0), _edge(j, lat, h1))
	_quad(st, _edge(i, lat, h0), _edge(i, lat, h1), _edge(j, lat, h1), _edge(j, lat, h0))


## Cor do asfalto (multiplica a textura) por faixa e por trecho: recapeamento, remendos, tunel.
func _lane_tint(i: int, lane: int) -> Color:
	var z: float = float(i) * Track.SEG_LEN
	var block: int = int(z / 38.0)
	var h: float = _hash(block * 7 + 3)
	var c: float = 0.93 + 0.14 * h                                      # trechos recapeados (variacao lenta)
	if _hash(block * 31 + lane * 5) < 0.09:                              # remendo numa faixa so
		c *= 0.72 if _hash(block * 13 + lane) < 0.6 else 1.18
	var col := Color(c, c, c)
	if in_tunnel(z, tunnels):                                            # luz de sodio pintada no asfalto
		var lamp: float = 0.5 + 0.5 * cos(fmod(z, 6.0) / 6.0 * TAU)
		col *= Color(0.55, 0.4, 0.26).lerp(Color(1.0, 0.7, 0.42), lamp)
	return col


func _hash(n: int) -> float:
	return fmod(absf(sin(float(n) * 12.9898) * 43758.5453), 1.0)


func _build_chunk(s0: int, s1: int) -> void:
	var sts: Dictionary = {}
	_used.clear()
	for k in ["road", "troad", "line", "yline", "ground", "sand", "barrier", "tbarrier", "rail", "glass"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st
	var half: float = Track.ROAD_HALF_WIDTH_M
	var sh: float = half + RUMBLE_W
	var gw: float = sh + SHOULDER_W
	var coast: bool = kind == &"coast"
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	var bo: float = BARRIER_IN + BARRIER_W
	for i in range(s0, s1):
		var band: bool = (i / BAND_SEGS) % 2 == 0
		var j: int = i + 1
		var z: float = float(i) * Track.SEG_LEN
		var tunnel: bool = in_tunnel(z, tunnels)
		var rs: SurfaceTool = sts["troad"] if tunnel else sts["road"]
		if tunnel:
			for side in [-1.0, 1.0]:
				_barrier(sts["tbarrier"], i, j, BARRIER_IN, side, Color(0.62, 0.52, 0.4) * _lane_tint(i, 9))
		for lane in 4:                                                      # asfalto: 4 faixas com trilhas de roda
			var x0: float = -half + float(lane) * LANE_W
			var tint: Color = _lane_tint(i, lane)
			for b in LANE_BANDS.size():
				var a0: float = float(LANE_BANDS[b][0])
				var a1: float = float(LANE_BANDS[b + 1][0]) if b + 1 < LANE_BANDS.size() else LANE_W
				var m: float = float(LANE_BANDS[b][1])
				_strip(rs, i, j, x0 + a0, x0 + a1, 0.0, 0.0, Color(tint.r * m, tint.g * m, tint.b * m))
		var shoulder: Color = Color(0.86, 0.86, 0.88) * (_lane_tint(i, 9) if tunnel else Color.WHITE)
		_strip(rs, i, j, -gw, -half, 0.0, 0.0, shoulder)                     # acostamento (sem zebra)
		_strip(rs, i, j, half, gw, 0.0, 0.0, shoulder)
		var sharp: bool = absf(path.track.curves[i]) >= RoadFurniture.SHARP_CURVE
		for lane in [-0.5, 0.0, 0.5]:                                       # divisao de faixas
			var c: float = lane * half
			if sharp:
				_strip(sts["yline"], i, j, c - 0.08, c + 0.08, 0.02, 0.02)  # amarela continua: nao mude de faixa
			elif band:
				_strip(sts["line"], i, j, c - 0.08, c + 0.08, 0.02, 0.02)
		for side in [-1.0, 1.0]:                                            # linhas continuas de borda
			var e: float = side * (half - 0.35)
			_strip(sts["line"], i, j, e - 0.1, e + 0.1, 0.02, 0.02)
		_strip(sts["road"], i, j, -BARRIER_IN, -gw, 0.0, 0.0, Color(0.7, 0.7, 0.72))   # faixa ate a mureta
		if not tunnel:
			_barrier(sts["barrier"], i, j, BARRIER_IN, -1.0)
		if _deck > 0.0:                                                     # viaduto: mureta dos dois lados, chao la embaixo
			_strip(sts["road"], i, j, gw, BARRIER_IN, 0.0, 0.0, Color(0.7, 0.7, 0.72))
			if not tunnel:
				_barrier(sts["barrier"], i, j, BARRIER_IN, 1.0)
			_strip(sts["ground"], i, j, -bo - GRASS_WIDTH, -bo, -_deck, -_deck)
			_strip(sts["ground"], i, j, bo, bo + GRASS_WIDTH, -_deck, -_deck)
			if q >= 1 and sound_wall_at(z) and not tunnel:
				for side in [-1.0, 1.0]:
					_blade(sts["glass"], i, j, side * (BARRIER_IN + 0.45), 0.85, 4.0)
			continue
		_strip(sts["ground"], i, j, -bo - GRASS_WIDTH, -BARRIER_IN)        # grama do lado esquerdo
		if coast:                                                           # lado do mar: guard-rail, grama curta e praia
			_strip(sts["road"], i, j, gw, BARRIER_IN, 0.0, 0.0, Color(0.7, 0.7, 0.72))
			_blade(sts["rail"], i, j, BARRIER_IN + 0.3, 0.55, 0.85)
			_blade(sts["rail"], i, j, BARRIER_IN + 0.3, 0.3, 0.42)
			_strip(sts["ground"], i, j, BARRIER_IN, gw + COAST_GRASS)
			_strip(sts["sand"], i, j, gw + COAST_GRASS, gw + COAST_GRASS + COAST_SAND, 0.0, -SEA_DROP)
		else:
			_strip(sts["road"], i, j, gw, BARRIER_IN, 0.0, 0.0, Color(0.7, 0.7, 0.72))
			if not tunnel:
				_barrier(sts["barrier"], i, j, BARRIER_IN, 1.0)
			_strip(sts["ground"], i, j, BARRIER_IN, bo + GRASS_WIDTH)
	var mesh := ArrayMesh.new()
	for k in ["road", "troad", "line", "yline", "ground", "barrier", "tbarrier", "sand", "rail", "glass"]:
		var st: SurfaceTool = sts[k]
		if not _used.has(st):
			continue                                                        # so as superficies usadas neste pedaco
		st.generate_normals()
		var arrays: Array = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[k])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 520.0 if int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1 else 380.0
	add_child(mi)
