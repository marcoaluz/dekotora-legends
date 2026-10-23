class_name RoadSigns
extends Node3D
## Sinalizacao de via expressa japonesa (T-130), so visual e deterministica (so depende da pista):
## limite de velocidade (circulo vermelho), losango amarelo de curva/tunel/queda de pedras com placa de apoio,
## chevrons vermelhos e brancos por fora das curvas fortes, paineis verdes de distancia (km), placa 出口 de saida,
## placa com nome e comprimento na boca de cada tunel e 止まれ pintado + placa de pare no acostamento do pedagio.
## Custo: 2 chamadas de desenho para a rota inteira (faces: AtlasQuads com o atlas SignAtlas; postes e costas:
## MultiMesh de caixas). Sem luz por pixel: claridade pela hora do dia (AtlasQuads.level_for), igual as placas.
## No Japao a mao e inglesa: as placas ficam a ESQUERDA (x negativo), em cima da mureta.
## T-146: chapas de verdade (redonda, losango, triangulo, retangulo, com borda) e postes redondos com base, do pacote
## "ROAD SIGNS" (RoadsideKit), juntados por bloco de 400 m (MeshBatch: +1 chamada por bloco visivel). --no-kit volta
## as caixas antigas.

const SIDE_LAT: float = -(RoadMesh.BARRIER_IN + 0.3)   # em cima da mureta esquerda
const SHARP: float = 0.9                                # curva forte (= RoadFurniture.SHARP_CURVE): chevrons
const MILD: float = 0.5                                 # curva que ja ganha o losango de aviso
const BASE_LIMIT: Dictionary = {&"coast": 80, &"city": 60, &"mountain": 60}
const CURVE_LIMIT: Dictionary = {&"coast": 60, &"city": 50, &"mountain": 50}
const GANTRY_FIRST: float = 320.0                        # porticos do RoadFurniture (evita placa embaixo deles)
const GANTRY_EVERY: float = 650.0
const TOLL_Z: float = 150.0                              # Track.decorate_roadside: pedagio
const POST := Color("#8e939a")
const SMALL_SIGN := Vector2(1.6, 1.6)                   # circulo/losango (via expressa: placas grandes)
const AUX_SIGN := Vector2(1.7, 0.85)                    # placa de apoio embaixo do losango
const LAYER: float = 0.05                                # afastamento entre camadas (fundo, texto) contra z-fighting
const BOX_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float level = 1.0;
varying vec3 tint;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb * (0.62 + 0.38 * clamp(dot(n, normalize(vec3(0.4, 0.8, 0.3))), 0.0, 1.0));
}
void fragment() { ALBEDO = tint * level; }
"""

var path: TrackPath
var faces: AtlasQuads
var counts: Dictionary = {}                 # tipo -> quantas (testes e depuracao)
var _boxes: Array = []                      # [Transform3D, Color]
var _taken: Array[float] = []               # z ja usados do lado esquerdo
var _kit: MeshBatch                          # chapas e postes do kit (null = caixas)
var _tod: TimeOfDay


func build(path_: TrackPath, kind: StringName, tod: TimeOfDay, tunnels: Array[Vector2], places: PackedStringArray,
		route_id: String = "") -> void:
	path = path_
	_tod = tod
	_kit = MeshBatch.new(400.0, 560.0) if RoadsideKit.enabled() else null
	faces = AtlasQuads.new()
	add_child(faces)
	faces.setup(load(SignAtlas.ATLAS) as Texture2D, AtlasQuads.level_for(tod))
	var L: float = path.track.length_m
	for t in tunnels:
		_tunnel(t, route_id, kind)
	if L > 1400.0:                                          # saida: antes das outras para ter prioridade no lugar
		var exit_sign := func(z: float) -> void: _sign(z, SIDE_LAT - 0.9, 3.6, Vector2(2.6, 1.3), "exit", 2)
		_place(L - 520.0, tunnels, exit_sign, "exit")
		if not counts.has("exit"):                          # caiu no tunel ou num portico: mais perto do fim
			_place(L - 280.0, tunnels, exit_sign, "exit")
		var sec: TrackEvents.Event = LaneSections.at(path.track.events, L - 520.0, 30.0)
		if not counts.has("exit") and sec != null:          # T-153: trecho de 2 faixas no fim: antes dele
			_place(sec.z - 140.0, tunnels, exit_sign, "exit")
	_curves(L, kind, tunnels)
	_limits(L, kind, tunnels)
	_distances(L, places, tunnels)
	if not TollPlaza3D.enabled(path.track):                 # T-207: a praca nova tem placas proprias (sem 止まれ/pare)
		_toll()
	faces.commit()
	_commit_boxes(AtlasQuads.level_for(tod))
	var blocks: int = _kit.commit(self) if _kit != null else 0
	if "--fps-log" in OS.get_cmdline_user_args():
		print("SINALIZACAO: ", counts, "  quads=", faces.quad_count(), "  caixas=", _boxes.size(), "  z=", _taken)
		if _kit != null:
			print("KIT: placas  blocos=", blocks, "  triangulos=", _kit.tris)


# ---------------------------------------------------------------- regras de colocacao
func _free(z: float, tunnels: Array[Vector2], gap: float = 30.0) -> bool:
	if z < 40.0 or z > path.track.length_m - 40.0 or RoadMesh.in_tunnel(z, tunnels, 60.0):
		return false
	if LaneSections.at(path.track.events, z, 30.0) != null:
		return false                                            # T-153: o trecho de 2 faixas tem as placas dele
	var g: float = fposmod(z - GANTRY_FIRST, GANTRY_EVERY)
	if minf(g, GANTRY_EVERY - g) < 35.0 or absf(z - TOLL_Z) < 40.0:
		return false
	for u in _taken:
		if absf(u - z) < gap:
			return false
	return true


## Coloca no primeiro z livre a partir de `z` (procura ate 120 m para tras e para frente).
func _place(z: float, tunnels: Array[Vector2], put: Callable, kind: String) -> void:
	for k in 9:
		var zz: float = z + ceilf(k / 2.0) * 15.0 * (1.0 if k % 2 == 0 else -1.0)
		if _free(zz, tunnels):
			_taken.append(zz)
			put.call(zz)
			counts[kind] = int(counts.get(kind, 0)) + 1
			return


## Sentido da curva em z: +1 direita, -1 esquerda (pelo giro da pista nos proximos 40 m).
func _turn(z: float) -> float:
	return -signf(angle_difference(path.yaw_at(z), path.yaw_at(z + 40.0)))


func _runs(L: float, limit: float) -> Array:
	var out: Array = []
	var start: float = -1.0
	var z: float = 0.0
	while z < L:
		var on: bool = absf(path.track.curve_at(z)) >= limit
		if on and start < 0.0:
			start = z
		elif not on and start >= 0.0:
			out.append(Vector2(start, z))
			start = -1.0
		z += 8.0
	if start >= 0.0:
		out.append(Vector2(start, L))
	return out


# ---------------------------------------------------------------- tipos de placa
func _curves(L: float, kind: StringName, tunnels: Array[Vector2]) -> void:
	for run in _runs(L, MILD):
		var dir: float = _turn(run.x + 10.0)
		var sharp: bool = absf(path.track.curve_at(run.x + 10.0)) >= SHARP or _peak(run) >= SHARP
		var id: String = "warn_curve_r" if dir > 0.0 else "warn_curve_l"
		var warn := func(z: float) -> void:
			_sign(z, SIDE_LAT, 3.6, SMALL_SIGN, id, 1, 0.45)
			if sharp:
				_sign(z, SIDE_LAT, 2.35, AUX_SIGN, "aux_slow", 0)
		_place(run.x - 190.0, tunnels, warn, "curve")
		if sharp:
			var lim: int = int(CURVE_LIMIT.get(kind, 60))
			_place(run.x - 110.0, tunnels, func(z: float) -> void: _sign(z, SIDE_LAT, 3.6, SMALL_SIGN, "spd_%d" % lim, 1, 0.6), "limit")
	for run in _runs(L, SHARP):                                   # chevrons por fora da curva forte
		var outside: float = -_turn(run.x + 10.0)
		var id: String = "chev_r" if outside < 0.0 else "chev_l"
		var z: float = run.x + 6.0
		while z < run.y:
			if not RoadMesh.in_tunnel(z, tunnels, 8.0):
				var p: Vector3 = LaneSections.profile(path.track.events, z)        # T-153: em cima da mureta que estreitou
				var wall: float = p.x if outside < 0.0 else p.y
				_sign(z, outside * (wall + 0.3), 1.6, Vector2(1.0, 1.25), id, -1, 0.0, -0.18 * outside)
				counts["chevron"] = int(counts.get("chevron", 0)) + 1
			z += 24.0
	if kind == &"mountain":                                       # queda de pedras nas encostas
		var z2: float = 700.0
		while z2 < L - 300.0:
			_place(z2, tunnels, func(z: float) -> void: _sign(z, SIDE_LAT, 3.6, SMALL_SIGN, "warn_rocks", 1, 0.45), "rocks")
			z2 += 1100.0


func _peak(run: Vector2) -> float:
	var m: float = 0.0
	var z: float = run.x
	while z < run.y:
		m = maxf(m, absf(path.track.curve_at(z)))
		z += 8.0
	return m


func _limits(L: float, kind: StringName, tunnels: Array[Vector2]) -> void:
	var lim: int = int(BASE_LIMIT.get(kind, 80))
	var spots: Array[float] = [260.0]
	var z: float = 1160.0
	while z < L - 200.0:
		spots.append(z)
		z += 900.0
	for t in tunnels:
		spots.append(t.x + t.y + 140.0)                            # depois da saida do tunel
	for s in spots:
		_place(s, tunnels, func(zz: float) -> void: _sign(zz, SIDE_LAT, 3.6, SMALL_SIGN, "spd_%d" % lim, 1, 0.6), "limit")


## Paineis verdes: os 2 proximos lugares e a distancia em km (como os porticos).
func _distances(L: float, places: PackedStringArray, tunnels: Array[Vector2]) -> void:
	if places.is_empty():
		return
	var k: int = 0
	var z: float = 600.0
	while z < L - 700.0:
		var kk: int = k
		_place(z, tunnels, func(zz: float) -> void: _panel(zz, places, kk, L), "distance")
		k += 1
		z += 1300.0


func _panel(z: float, places: PackedStringArray, k: int, L: float) -> void:
	var lat: float = SIDE_LAT - 1.0
	var b: Basis = _basis(z, 0.1)
	var c: Vector3 = _at(z, lat, 3.6)
	_face(b, c, Vector2(3.9, 2.3), "solid_white")                 # borda branca
	_face(b, c + b.z * LAYER, Vector2(3.75, 2.15), "solid_green")
	_back(b, c, Vector2(3.9, 2.3), 1.0, "solid_white", z)
	for sx in [-1.2, 1.2]:
		_post(_at(z, lat + sx, 0.0), 3.6 - 1.1, z)
	for row in 2:
		var place: String = String(places[(k + row + 1) % places.size()])
		if not SignAtlas.has("place_" + place):
			continue
		var km: int = maxi(1, roundi(maxf((L - z) / 1000.0, 0.5) + 6.0 * row))
		var y: float = 0.5 - row * 1.0
		_face(b, c + b.y * y - b.x * 0.75 + b.z * LAYER * 2.0, Vector2(2.0, 0.75), "place_" + place)
		var digits: String = str(km)
		var x: float = 0.75 + 0.24 * (2 - digits.length())
		for ch in digits:
			_face(b, c + b.y * y + b.x * x + b.z * LAYER * 2.0, Vector2(0.36, 0.72), "g" + ch)
			x += 0.36
		_face(b, c + b.y * (y - 0.1) + b.x * (x + 0.12) + b.z * LAYER * 2.0, Vector2(0.5, 0.5), "km")


## Losango + apoio "トンネル" antes do tunel e placa com nome e comprimento em cima da boca.
func _tunnel(t: Vector2, route_id: String, kind: StringName) -> void:
	var tunnels: Array[Vector2] = []
	var warn := func(z: float) -> void:
		_sign(z, SIDE_LAT, 3.6, SMALL_SIGN, "warn_tunnel", 1, 0.45)
		_sign(z, SIDE_LAT, 2.35, AUX_SIGN, "aux_tunnel", 0)
	_place(t.x - 260.0, tunnels, warn, "tunnel_warn")
	if LaneSections.profile(path.track.events, t.x + t.y * 0.5).y <= LaneSections.RIGHT_WALL_M + 0.05:
		counts["tunnel_plaque_old"] = int(counts.get("tunnel_plaque_old", 0)) + 1
		return                                                  # T-153: tunel antigo (o Tunnel3D poe a placa de pedra)
	var z0: float = t.x - 0.35
	var b: Basis = _basis(z0, 0.0)
	var c: Vector3 = _at(z0, 0.0, float(Tunnel3D.ARCH[Tunnel3D.ARCH.size() - 1][1]) + 2.2)
	_face(b, c, Vector2(6.6, 2.9), "solid_white")
	_boxes.append([Transform3D(b * Basis.from_scale(Vector3(6.9, 3.2, 0.16)), c - b.z * 0.09), Color("#1b1d22")])   # moldura escura
	var name_id: String = "tun_" + route_id if SignAtlas.has("tun_" + route_id) else "aux_tunnel"
	var nw: float = 1.45 * SignAtlas.aspect(name_id)
	_face(b, c + b.y * 0.62 + b.z * LAYER * 2.0, Vector2(minf(nw, 6.2), 1.45), name_id)
	var len_txt: String = str(roundi(t.y))
	var w: float = 1.0 + 0.5 * (len_txt.length() + 1)
	var x: float = -w * 0.5 + 0.5
	_face(b, c + b.y * -0.75 + b.x * x + b.z * LAYER * 2.0, Vector2(1.0, 1.0), "enchou")
	x += 0.75
	for ch in len_txt + "m":
		_face(b, c + b.y * -0.75 + b.x * x + b.z * LAYER * 2.0, Vector2(0.5, 1.0), "wm" if ch == "m" else "w" + ch)
		x += 0.5
	counts["tunnel_plaque"] = int(counts.get("tunnel_plaque", 0)) + 1


## Pedagio (z = 150): 止まれ pintado no acostamento da esquerda e placa de pare ao lado.
func _toll() -> void:
	var lat: float = Lanes.X[Lanes.SHOULDER_L] * Track.ROAD_HALF_WIDTH_M
	var z: float = TOLL_Z - 24.0
	var b: Basis = Basis(Vector3.UP, path.yaw_at(z)) * Basis(Vector3.RIGHT, -PI * 0.5)
	faces.add_quad(Transform3D(b * Basis.from_scale(Vector3(2.3, 3.4, 1.0)), _at(z, lat, 0.04)), SignAtlas.uv("tomare"))
	_sign(z - 6.0, -(Track.ROAD_HALF_WIDTH_M + 0.6), 2.4, Vector2(1.0, 1.0), "stop", 1, 0.35)
	counts["stop"] = 1


# ---------------------------------------------------------------- pecas basicas
func _at(z: float, lat_m: float, h: float) -> Vector3:
	return path.world_point(z, lat_m / Track.ROAD_HALF_WIDTH_M, h)


## Base da placa em z: +Z local aponta para quem vem pela pista; `turn` gira um pouco para o meio da pista.
func _basis(z: float, turn: float) -> Basis:
	return Basis(Vector3.UP, path.yaw_at(z) + turn)


func _face(b: Basis, c: Vector3, size: Vector2, id: String) -> void:
	faces.add_quad(Transform3D(b * Basis.from_scale(Vector3(size.x, size.y, 1.0)), c), SignAtlas.uv(id))


## Costas da placa: a chapa do kit no formato da face `id` (ou, sem o kit, uma caixa cinza; `inset` < 1 para
## placas redondas/losango nao mostrarem canto).
func _back(b: Basis, c: Vector3, size: Vector2, inset: float = 1.0, id: String = "", z: float = 0.0) -> void:
	if _kit != null:
		var p: Array = RoadsideKit.plate_xform(b, c, size, id)
		_kit.add(RoadsideKit.mesh(String(p[0]), _tod), p[1], z)
		return
	_boxes.append([Transform3D(b * Basis.from_scale(Vector3(size.x * inset, size.y * inset, 0.05)), c - b.z * 0.035), POST])


func _post(base: Vector3, h: float, z: float = 0.0) -> void:
	if _kit != null:
		_kit.add(RoadsideKit.mesh("sign_post", _tod), RoadsideKit.post_xform(base, h), z)
		return
	_boxes.append([Transform3D(Basis.from_scale(Vector3(0.11, h, 0.11)), base + Vector3.UP * h * 0.5), POST])


## Placa simples num poste: `posts` = 1 (um poste ate o chao), 2 (dois postes), 0 (sem poste, presa a outra),
## -1 (presa na mureta: poste curto). `inset` = tamanho das costas; `turn` = giro extra (rad) para a pista.
func _sign(z: float, lat: float, h: float, size: Vector2, id: String, posts: int, inset: float = 1.0, turn: float = 0.1) -> void:
	var b: Basis = _basis(z, turn)
	var c: Vector3 = _at(z, lat, h)
	_face(b, c, size, id)
	_back(b, c, size, inset, id, z)
	if posts == 1:
		_post(_at(z, lat, 0.0) - b.z * 0.06, h, z)
	elif posts == 2:
		for sx in [-0.8, 0.8]:
			_post(_at(z, lat, 0.0) + b.x * sx * size.x * 0.5 - b.z * 0.06, h - size.y * 0.4, z)
	elif posts == -1:
		_post(_at(z, lat, 0.8) - b.z * 0.06, h - 0.8 - size.y * 0.3, z)


func _commit_boxes(level: float) -> void:
	if _boxes.is_empty():
		return
	var sh := Shader.new()
	sh.code = BOX_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("level", level)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = _boxes.size()
	for i in _boxes.size():
		mm.set_instance_transform(i, _boxes[i][0])
		mm.set_instance_color(i, _boxes[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
