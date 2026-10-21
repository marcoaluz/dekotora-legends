class_name CityBuilder
extends Node3D
## Cenario de fundo, todo em MultiMesh (poucos draw calls) e determinístico (semente fixa):
## - predios com janelas por shader; cada predio tem cor de parede e estilo de janela proprios (cor da instancia),
##   alguns com recuo no topo, luz vermelha de aviacao piscando e letreiro de neon na fachada virada para a pista;
## - litoral (`coast`): predios so do lado da terra (esquerda), mar animado a direita e o skyline de uma cidade do
##   outro lado da baia com o reflexo das luzes na agua;
## - hora do dia (TimeOfDay): de dia as paredes clareiam e o vidro reflete o ceu; a noite as janelas acendem;
## - montanhas escuras ao longe (mais altas no cenario `mountain`).

const BUILDING_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float energy = 2.0;
uniform float day = 0.0;
varying vec3 wpos;
varying vec3 wnormal;
varying vec4 tint;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); tint = COLOR; }
void fragment() {
	vec2 uv = abs(wnormal.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	vec2 cell = floor(uv / vec2(3.0, 3.5));
	vec2 f = fract(uv / vec2(3.0, 3.5));
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.78);
	float on = step(0.5, hash(cell + floor(wpos.xz * 0.01)));
	float floor_dark = step(0.86, hash(vec2(cell.y, floor(wpos.x * 0.02 + wpos.z * 0.02))));
	float side = abs(wnormal.y) < 0.5 ? 1.0 : 0.0;
	vec3 warm = vec3(1.0, 0.8, 0.45);
	vec3 cool = vec3(0.75, 0.88, 1.0);
	vec3 pink = vec3(1.0, 0.3, 0.6);
	vec3 wc = tint.a < 0.4 ? warm : (tint.a < 0.75 ? cool : mix(warm, pink, step(0.7, hash(cell * 1.7))));
	vec3 wall = tint.rgb * (0.85 + 0.15 * step(0.5, f.y));
	wall = mix(wall, vec3(dot(wall, vec3(0.333))), day * 0.6) * mix(1.0, 3.2, day);   // dia: concreto claro
	float glass = win * side * day;
	ALBEDO = mix(wall, vec3(0.2, 0.28, 0.38) * (0.8 + 0.4 * hash(cell * 5.3)), glass);
	EMISSION = wc * win * on * side * (1.0 - floor_dark) * energy * (0.55 + 0.8 * hash(cell * 3.1));
	ROUGHNESS = mix(0.75, 0.12, glass);
	METALLIC = mix(0.2, 0.7, glass);
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
uniform float blink = 0.0;
uniform float energy = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	float b = blink > 0.5 ? step(0.0, sin(TIME * 3.0 + tint.a * 20.0)) : 1.0;
	ALBEDO = tint.rgb * 2.2 * b * energy;
}
"""

const REFLECT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
varying vec4 tint;
varying vec2 luv;
void vertex() { tint = COLOR; luv = UV; }
void fragment() {
	float w = sin(luv.y * 60.0 + TIME * 2.0) * 0.5 + 0.5;
	float fade = (1.0 - luv.y) * (1.0 - abs(luv.x - 0.5) * 2.0);
	ALBEDO = tint.rgb * fade * (0.35 + 0.65 * w) * 0.9;
}
"""

const WATER_SHADER := """
shader_type spatial;
uniform vec3 deep : source_color = vec3(0.005, 0.03, 0.08);
uniform sampler2D waves : hint_normal;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv1 = wpos.xz * 0.02 + vec2(TIME * 0.01, TIME * 0.006);
	vec2 uv2 = wpos.xz * 0.05 - vec2(TIME * 0.008, -TIME * 0.012);
	NORMAL_MAP = mix(texture(waves, uv1).rgb, texture(waves, uv2).rgb, 0.5);
	NORMAL_MAP_DEPTH = 0.6;
	ALBEDO = deep;
	METALLIC = 0.05;
	ROUGHNESS = 0.14;
	SPECULAR = 0.55;
}
"""

const SIGN_COLORS: Array = [Color("#ff2e88"), Color("#21e6ff"), Color("#ffb347"), Color("#b44dff")]

var path: TrackPath
var tod: TimeOfDay
var _deck: float = 0.0
var keep_out: Array = []          # T-154: corredores da ferrovia sem predio ([a, b, meia_largura], RailwayLayout.keep_out)


func build(path_: TrackPath, seed_: int = 21, kind: StringName = &"city", tod_: TimeOfDay = null) -> void:
	path = path_
	tod = tod_ if tod_ != null else TimeOfDay.by_id(&"night")
	_deck = RoadMesh.deck_height(kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	_add_ground(kind)
	var blds: Array = []       # [Transform3D, Color]
	var lights: Array = []     # luz de aviacao
	var signs: Array = []      # letreiros de neon
	var refl: Array = []       # reflexos na agua (litoral)
	var z: float = 0.0
	var L: float = path.track.length_m
	while z < L + 200.0:
		var zz: float = minf(z, L - 1.0)
		var yaw: float = path.yaw_at(zz)
		for side in [-1.0, 1.0]:
			if kind == &"coast" and side > 0.0:
				continue
			if rng.randf() < _building_chance(kind):
				var dist: float = rng.randf_range(95.0, 260.0) if kind == &"city" else rng.randf_range(140.0, 380.0)
				_building(rng, zz, yaw, side, dist, 25.0, 110.0, blds, lights, signs, true)
		if kind == &"coast" and rng.randf() < 0.85:                 # skyline do outro lado da baia
			var far: float = rng.randf_range(380.0, 560.0)          # dentro da neblina visivel
			var h: float = _building(rng, zz, yaw, 1.0, far, 30.0, 170.0, blds, lights, signs, false)
			var cw: Color = Color(1.0, 0.75, 0.45) if rng.randf() < 0.6 else SIGN_COLORS[rng.randi() % SIGN_COLORS.size()]
			var start: Vector3 = path.world_point(zz, (far - 30.0) / Track.ROAD_HALF_WIDTH_M, -1.15)
			var span: float = minf(far - 60.0, h * 3.5)
			var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(span, 1.0, rng.randf_range(4.0, 10.0)))
			refl.append([Transform3D(b, start - path.right_at(zz) * span * 0.5), cw])
		z += rng.randf_range(18.0, 40.0)
	var bm: ShaderMaterial = _shader_mat(BUILDING_SHADER)
	bm.set_shader_parameter("energy", tod.window_energy)
	bm.set_shader_parameter("day", tod.day_amount)
	_multi(_box(), blds, bm, tod.day_amount > 0.5)
	_multi(_box(), lights, _glow_mat(true), false)
	_multi(_box(), signs, _glow_mat(false), false)
	if not refl.is_empty() and tod.window_energy > 0.3:       # reflexo das luzes na agua so com janelas acesas
		var q := PlaneMesh.new()
		q.size = Vector2.ONE
		_multi(q, refl, _shader_mat(REFLECT_SHADER), false)
	_mountains(rng, kind)


## Um predio (e as vezes recuo no topo, luz de aviacao e letreiro). Devolve a altura.
func _building(rng: RandomNumberGenerator, z: float, yaw: float, side: float, dist: float, hmin: float, hmax: float,
		blds: Array, lights: Array, signs: Array, near: bool) -> float:
	var w: float = rng.randf_range(14.0, 34.0)
	var d: float = rng.randf_range(14.0, 34.0)
	var h: float = rng.randf_range(hmin, hmax)
	var c: Vector3 = path.world_point(z, side * dist / Track.ROAD_HALF_WIDTH_M, 0.0)
	var wall: Color = Color.from_hsv(rng.randf_range(0.55, 0.75), rng.randf_range(0.15, 0.45), rng.randf_range(0.06, 0.16))
	wall.a = rng.randf()                                             # estilo das janelas (shader)
	var by := Basis(Vector3.UP, yaw)
	var n0: Vector3i = Vector3i(blds.size(), lights.size(), signs.size())
	var sink: float = 4.0 + _deck                                     # base enterrada (abaixo do chao/viaduto)
	blds.append([Transform3D(by * Basis.from_scale(Vector3(w, h, d)), c + Vector3.UP * (h * 0.5 - sink)), wall])
	var top: float = h - sink
	if rng.randf() < 0.4:                                            # recuo no topo
		var h2: float = h * rng.randf_range(0.15, 0.35)
		blds.append([Transform3D(by * Basis.from_scale(Vector3(w * 0.6, h2, d * 0.6)), c + Vector3.UP * (top + h2 * 0.5)), wall])
		top += h2
	if h > 70.0:                                                     # luz de aviacao (pisca)
		lights.append([Transform3D(by * Basis.from_scale(Vector3.ONE * 1.2), c + Vector3.UP * (top + 0.8)), Color(1.0, 0.1, 0.1, rng.randf())])
	if near and rng.randf() < 0.35:                                  # letreiro de neon na fachada da pista
		var sw: float = rng.randf_range(4.0, 9.0)
		var sh: float = rng.randf_range(10.0, minf(26.0, h * 0.6))
		var face: Vector3 = c - path.right_at(z) * side * (w * 0.5 + 0.3)
		var col: Color = SIGN_COLORS[rng.randi() % SIGN_COLORS.size()]
		signs.append([Transform3D(by * Basis.from_scale(Vector3(0.3, sh, sw)), face + Vector3.UP * rng.randf_range(sh * 0.6, maxf(h - sh, sh * 0.7))), col])
	if _blocked(c, maxf(w, d) * 0.6):              # T-154: em cima da ferrovia -> tira (o sorteio dos outros nao muda)
		blds.resize(n0.x)
		lights.resize(n0.y)
		signs.resize(n0.z)
	return h


## T-154: o ponto (com raio r) cai num corredor de `keep_out` ([a, b, meia_largura] no plano XZ)?
func _blocked(c: Vector3, r: float) -> bool:
	var p := Vector2(c.x, c.z)
	for k in keep_out:
		if Geometry2D.get_closest_point_to_segment(p, k[0], k[1]).distance_to(p) < float(k[2]) + r:
			return true
	return false


func _box() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	return box


func _shader_mat(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	mat.shader = sh
	return mat


func _glow_mat(blink: bool) -> ShaderMaterial:
	var m: ShaderMaterial = _shader_mat(GLOW_SHADER)
	m.set_shader_parameter("blink", 1.0 if blink else 0.0)
	m.set_shader_parameter("energy", tod.neon_energy if not blink else maxf(tod.neon_energy, 0.6))
	return m


func _multi(mesh: Mesh, items: Array, mat: Material, shadows: bool) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Montanhas: cones achatados bem longe (do lado da terra no litoral). T-169: com o kit, macicos de verdade.
func _mountains(rng: RandomNumberGenerator, kind: StringName) -> void:
	if BackdropKit.mountains_available():
		_massifs(rng, kind)
		return
	var mmesh := CylinderMesh.new()
	mmesh.top_radius = 0.0
	mmesh.bottom_radius = 1.0
	mmesh.height = 1.0
	mmesh.radial_segments = 7
	var count: int = 90 if kind == &"mountain" else 40
	var items: Array = []
	for i in count:
		var zz: float = rng.randf_range(0.0, path.track.length_m)
		var sd: float = -1.0 if (kind == &"coast" or rng.randf() < 0.5) else 1.0
		var c2: Vector3 = path.world_point(zz, sd * rng.randf_range(300.0 if kind == &"mountain" else 520.0, 800.0) / Track.ROAD_HALF_WIDTH_M, 0.0)
		var hh: float = rng.randf_range(90.0, 420.0 if kind == &"mountain" else 260.0)
		var rr: float = rng.randf_range(160.0, 380.0)
		items.append([Transform3D(Basis.from_scale(Vector3(rr, hh, rr)), c2 + Vector3.UP * (hh * 0.5 - 6.0)), Color.WHITE])
	var m := StandardMaterial3D.new()
	m.albedo_color = tod.mountain_color
	m.roughness = 1.0
	_multi(mmesh, items, m, false)


## T-169: macicos nevados (BackdropKit, "Fundo Montanha Gelo") no lugar dos cones: menos copias e maiores, um
## MultiMesh por modelo (4 chamadas). Montanha: 16 macicos dos dois lados; litoral (so a terra): 10; cidade: 6.
## Modo baixo: metade. Cada copia: 750-1250 m de largura (altura = 65-95% da do modelo: 20-37% da largura); o pe do
## macico fica a 260-560 m da pista (420-560 fora da montanha).
var massif_count: int = 0


func _massifs(rng: RandomNumberGenerator, kind: StringName) -> void:
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	var count: int = 16 if kind == &"mountain" else (10 if kind == &"coast" else 6)   # cidade: os predios escondem
	if q <= 0:
		count /= 2
	var L: float = path.track.length_m
	var groups: Array = [[], [], [], []]
	for i in count:
		var zz: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(count) * L       # espalhados ao longo da rota
		var sd: float = -1.0 if (kind == &"coast" or i % 2 == 0) else 1.0
		var w: float = rng.randf_range(750.0, 1250.0)
		var dist: float = w * 0.5 + rng.randf_range(260.0 if kind == &"mountain" else 420.0, 560.0)   # pe longe da pista
		var c2: Vector3 = path.world_point(zz, sd * dist / Track.ROAD_HALF_WIDTH_M, 0.0)
		for _k in 12:                                   # a pista faz curva: empurra para fora ate o pe ficar longe dela
			if _min_track_dist(c2) >= w * 0.55 + 180.0:
				break
			dist += 120.0
			c2 = path.world_point(zz, sd * dist / Track.ROAD_HALF_WIDTH_M, 0.0)
		c2.y = -6.0 - _deck
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, w * rng.randf_range(0.65, 0.95), w))
		groups[i % 4].append([Transform3D(b, c2), Color.WHITE])
	var mat: ShaderMaterial = BackdropKit.mountain_material(tod, kind)
	for k in 4:
		_multi(BackdropKit.mountain_mesh(k), groups[k], mat, false)
	massif_count = count


## Menor distancia (no plano) de `p` a pista, amostrada a cada 40 m (so para posicionar o cenario de fundo).
func _min_track_dist(p: Vector3) -> float:
	var best: float = INF
	var z: float = 0.0
	while z <= path.track.length_m:
		var q: Vector3 = path.world_point(z, 0.0, 0.0)
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
		z += 40.0
	return best


func _building_chance(kind: StringName) -> float:
	match kind:
		&"coast":
			return 0.35
		&"mountain":
			return 0.08
	return 0.75


## Chao do mundo alem da grama: mar animado (litoral) ou terra escura.
func _add_ground(kind: StringName) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	mi.mesh = plane
	if kind == &"coast":
		var wm: ShaderMaterial = _shader_mat(WATER_SHADER)
		if BackdropKit.water_available():           # T-169: ondas do pacote "Agua" (mapa de normais repetivel)
			wm.set_shader_parameter("waves", BackdropKit.water_normal())
			wm.set_shader_parameter("deep", tod.water_color)
			mi.material_override = wm
			mi.position = Vector3(0, -1.2 - RoadMesh.deck_height(kind), -1400)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			return
		var n := FastNoiseLite.new()
		n.frequency = 0.04
		var nt := NoiseTexture2D.new()
		nt.noise = n
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 6.0
		nt.width = 256
		nt.height = 256
		wm.set_shader_parameter("waves", nt)
		wm.set_shader_parameter("deep", tod.water_color)
		mi.material_override = wm
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = tod.land_color
		m.roughness = 0.9
		mi.material_override = m
	mi.position = Vector3(0, -1.2 - RoadMesh.deck_height(kind), -1400)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
