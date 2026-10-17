class_name Tunnel3D
extends Node3D
## Tuneis (RouteDef.tunnels = [Vector2(inicio_m, comprimento_m)]): paredes de azulejo e teto em arco,
## fila de luzes de sodio no teto, placas verdes de emergencia, boca de concreto nas duas pontas e, por
## fora, morro (montanha) ou caixa de concreto (cidade).
## Iluminacao barata: paredes "pre-iluminadas" (sem sombreamento, cor por vertice com as faixas de luz) e,
## com o jogador dentro, o sol/ambiente apagam e uma luz laranja pisca sobre o caminhao no ritmo das
## lampadas (efeito estroboscopico classico de tunel a noite).

const LAMP_EVERY: float = 6.0
const FADE_M: float = 30.0
const PORTAL_H: float = 16.0
## Perfil do arco (lateral m, altura m), do lado direito; espelhado para o esquerdo.
const ARCH: Array = [[13.6, 0.0], [13.6, 5.0], [11.1, 7.4], [6.0, 8.0], [0.0, 8.2]]

var path: TrackPath
var tunnels: Array[Vector2] = []
var amount: float = 0.0                 # 0..1: quanto o jogador esta dentro de um tunel (acende as luzes do caminhao)
var _sun: DirectionalLight3D
var _env: Environment
var _sun_base: float = 1.0
var _amb_base: float = 1.0
var _bg_base: float = 1.0
var _omni: OmniLight3D


func build(path_: TrackPath, tunnels_: Array[Vector2], kind: StringName, sun: DirectionalLight3D, env: Environment) -> void:
	path = path_
	tunnels = tunnels_
	_sun = sun
	_env = env
	_sun_base = sun.light_energy if sun != null else 1.0
	_amb_base = env.ambient_light_energy if env != null else 1.0
	_bg_base = env.background_energy_multiplier if env != null else 1.0
	if tunnels.is_empty():
		return
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var portal := SurfaceTool.new()
	portal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := SurfaceTool.new()
	outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lamps: Array = []
	for t in tunnels:
		_tube(inner, t)
		_portal(portal, t.x, 1.0)
		_portal(portal, t.x + t.y, -1.0)
		_cover(outer, t, kind)
		_caps(portal if kind == &"city" else outer, t, kind)
		var z: float = t.x + 2.0
		while z < t.x + t.y - 1.0:
			for side in [-1.0, 1.0]:
				lamps.append([_xf(z, side * 3.2, 7.92, Vector3(0.35, 0.1, 1.5)), Color(1.0, 0.62, 0.22)])
			if fmod(z - t.x, 96.0) < LAMP_EVERY:                          # placa verde de emergencia na parede
				lamps.append([_xf(z, -13.45, 2.6, Vector3(0.06, 0.6, 1.0)), Color(0.15, 0.95, 0.4)])
			z += LAMP_EVERY
	_add_mesh(inner, _inner_mat())
	_add_mesh(portal, _outer_mat(&"city"), false)
	_add_mesh(outer, _outer_mat(kind))
	_add_lamps(lamps)
	_omni = OmniLight3D.new()
	_omni.light_color = Color(1.0, 0.6, 0.25)
	_omni.omni_range = 20.0
	_omni.light_energy = 0.0
	_omni.visible = false
	add_child(_omni)


## Chamado a cada quadro com o z do jogador e a posicao do caminhao (apaga o sol, liga a luz que pisca).
func track_player(z: float, truck_pos: Vector3) -> void:
	if tunnels.is_empty():
		amount = 0.0
		return
	var f: float = 0.0
	for t in tunnels:
		var d: float = minf(z - t.x, t.x + t.y - z)
		f = maxf(f, clampf(d / FADE_M + 0.5, 0.0, 1.0))
	if _sun != null:
		_sun.light_energy = _sun_base * (1.0 - 0.95 * f)
	if _env != null:
		_env.ambient_light_energy = _amb_base * (1.0 - 0.85 * f)
		_env.background_energy_multiplier = _bg_base * (1.0 - 0.7 * f)   # tira o reflexo azul do ceu no cromo e na pintura
	amount = f
	_omni.visible = f > 0.01
	if _omni.visible:
		var phase: float = fmod(z, LAMP_EVERY) / LAMP_EVERY
		_omni.light_energy = f * (1.4 + 1.6 * pow(0.5 + 0.5 * cos(phase * TAU), 3.0))
		_omni.global_position = truck_pos + Vector3.UP * 7.0


func _edge(z: float, lat: float, h: float) -> Vector3:
	return path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, h)


func _xf(z: float, lat: float, h: float, size: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, path.yaw_at(z)) * Basis.from_scale(size), _edge(z, lat, h))


## Luz pintada nas paredes: claro perto de cada lampada, escuro entre elas; faixa suja embaixo.
func _lit(z: float, h: float) -> Color:
	var lamp: float = 0.5 + 0.5 * cos(fmod(z, LAMP_EVERY) / LAMP_EVERY * TAU)
	var tile := Color(0.62, 0.52, 0.4) if h > 1.2 else Color(0.3, 0.26, 0.22)
	var near_top: float = clampf(h / 8.2, 0.3, 1.0)
	return tile * (0.45 + 0.55 * lamp) * near_top


func _tube(st: SurfaceTool, t: Vector2) -> void:
	var z: float = t.x
	var step: float = Track.SEG_LEN
	while z < t.x + t.y:
		var z1: float = minf(z + step, t.x + t.y)
		for side in [-1.0, 1.0]:
			for k in ARCH.size() - 1:
				var p0: Array = ARCH[k]
				var p1: Array = ARCH[k + 1]
				var a: Vector3 = _edge(z, side * float(p0[0]), float(p0[1]))
				var b: Vector3 = _edge(z, side * float(p1[0]), float(p1[1]))
				var c: Vector3 = _edge(z1, side * float(p1[0]), float(p1[1]))
				var d: Vector3 = _edge(z1, side * float(p0[0]), float(p0[1]))
				var tri: Array = [a, b, c, a, c, d] if side > 0.0 else [a, c, b, a, d, c]
				for v in tri:
					var vz: float = z if (v == a or v == b) else z1
					st.set_color(_lit(vz, v.y - path.center_at(vz).y))
					st.add_vertex(v)
		z = z1


## Boca do tunel: placa de concreto com o furo do arco. `facing` = 1 na entrada, -1 na saida.
func _portal(st: SurfaceTool, z: float, facing: float) -> void:
	var w: float = 30.0
	var pts: Array = []
	for side in [-1.0, 1.0]:
		for k in ARCH.size() - 1:
			var p0: Array = ARCH[k]
			var p1: Array = ARCH[k + 1]
			pts.append([side * float(p0[0]), float(p0[1]), side * float(p1[0]), float(p1[1])])
	for p in pts:                                                        # do arco ate o topo
		_face(st, z, facing, [Vector2(p[0], p[1]), Vector2(p[2], p[3]), Vector2(p[2], PORTAL_H), Vector2(p[0], PORTAL_H)])
	_face(st, z, facing, [Vector2(-w, 0), Vector2(-13.6, 0), Vector2(-13.6, PORTAL_H), Vector2(-w, PORTAL_H)])
	_face(st, z, facing, [Vector2(13.6, 0), Vector2(w, 0), Vector2(w, PORTAL_H), Vector2(13.6, PORTAL_H)])


## Poligono (lateral, altura) no plano da boca; normal virada para fora do tunel (material sem cull).
func _face(st: SurfaceTool, z: float, facing: float, poly: Array, col: Color = Color(0.3, 0.3, 0.32)) -> void:
	var v: Array = []
	for p in poly:
		v.append(_edge(z, (p as Vector2).x, (p as Vector2).y))
	var n: Vector3 = -path.forward_at(z) * facing
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var geo: Vector3 = (v[tri[2]] - v[tri[0]]).cross(v[tri[1]] - v[tri[0]])   # sentido horario = frente no Godot
		if geo.dot(n) < 0.0:
			tri = [tri[0], tri[2], tri[1]]
		for k in tri:
			st.set_normal(n)
			st.set_color(col)
			st.set_uv(Vector2((poly[k] as Vector2).x, -(poly[k] as Vector2).y) / 4.0)
			st.add_vertex(v[k])


## Muro de concreto em volta da boca, fechando as pontas do morro/laje (sem tapar o furo).
func _caps(st: SurfaceTool, t: Vector2, kind: StringName) -> void:
	var top: float = _cover_top(kind)
	var spread: float = _cover_spread(kind)
	var col := Color(0.3, 0.3, 0.32) if kind == &"city" else Color(0.22, 0.28, 0.2)   # concreto ou encosta
	for e in [[t.x, 1.0], [t.x + t.y, -1.0]]:
		var zc: float = e[0]
		_face(st, zc, e[1], [Vector2(-spread, 0), Vector2(-30, 0), Vector2(-30, top), Vector2(-30, top)], col)
		_face(st, zc, e[1], [Vector2(30, 0), Vector2(spread, 0), Vector2(30, top), Vector2(30, top)], col)
		if top > PORTAL_H:
			_face(st, zc, e[1], [Vector2(-30, PORTAL_H), Vector2(30, PORTAL_H), Vector2(30, top), Vector2(-30, top)], col)


func _cover_top(kind: StringName) -> float:
	return PORTAL_H if kind == &"city" else 24.0


func _cover_spread(kind: StringName) -> float:
	return 80.0 if kind != &"city" else 30.0


## Por fora: morro sobre o tunel (montanha) ou laje de concreto (cidade).
func _cover(st: SurfaceTool, t: Vector2, kind: StringName) -> void:
	var z: float = t.x
	var top: float = _cover_top(kind)
	var spread: float = _cover_spread(kind)
	var col := Color(0.32, 0.38, 0.26) if kind != &"city" else Color(0.55, 0.55, 0.57)
	while z < t.x + t.y:
		var z1: float = minf(z + 8.0, t.x + t.y)
		for seg in [[-spread, 0.0, -30.0, top], [-30.0, top, 30.0, top], [30.0, top, spread, 0.0]]:
			var a: Vector3 = _edge(z, seg[0], seg[1])
			var b: Vector3 = _edge(z, seg[2], seg[3])
			var c: Vector3 = _edge(z1, seg[2], seg[3])
			var d: Vector3 = _edge(z1, seg[0], seg[1])
			for v in [a, c, b, a, d, c]:
				st.set_color(col)
				st.set_uv(Vector2(v.x, v.z) / 8.0)
				st.add_vertex(v)
		z = z1


func _inner_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _outer_mat(kind: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tex: String = "res://assets/textures/grass.png" if kind != &"city" else "res://assets/textures/concrete_streaks.png"
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex) as Texture2D
	return m


func _add_mesh(st: SurfaceTool, mat: Material, normals: bool = true) -> void:
	if normals:
		st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_lamps(items: Array) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var m := ShaderMaterial.new()                            # acima de 1: entra no brilho (glow)
	var sh := Shader.new()
	sh.code = "shader_type spatial;
render_mode unshaded;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() { ALBEDO = tint.rgb * 3.0; }
"
	m.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
