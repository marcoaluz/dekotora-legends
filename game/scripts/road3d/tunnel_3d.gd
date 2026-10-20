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
## T-153: tunel ANTIGO de 2 faixas (dentro de um trecho LaneSections): arco estreito e baixo em volta das muretas do
## trecho (meia largura e altura relativas), concreto escurecido sem azulejo, lampadas fracas nas paredes a cada
## OLD_LAMP_EVERY m, boca de pedra com a placa do nome (扁額).
const OLD_ARCH: Array = [[1.0, 0.0], [1.0, 3.7], [0.88, 5.1], [0.62, 6.0], [0.32, 6.45], [0.0, 6.6]]
const OLD_LAMP_EVERY: float = 12.0
const OLD_NAME := "湯坂隧道"                   # nome ficticio (隧道 = jeito antigo de dizer tunel)
const OLD_STONE := Color(0.36, 0.33, 0.29)
const OLD_LAMP := Color(1.0, 0.64, 0.28)       # T-155: lampada amarelada do tunel antigo (antes 0,9/0,5/0,16, apagada)
var _pools: Array[Transform3D] = []             # T-155: pocas de luz no asfalto do tunel antigo (TunnelLightPools)

var path: TrackPath
var tunnels: Array[Vector2] = []
var narrow: Array[bool] = []           # T-153: tunel antigo de 2 faixas (por indice de `tunnels`)
var _arch: Array = []                  # perfil completo de cada tunel (esquerda -> direita, [lateral, altura])
var _prev_amount: float = 0.0
signal exited                          # o jogador saiu de um tunel (clarao na camera)
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
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_stone: bool = false
	for n in tunnels.size():
		var t: Vector2 = tunnels[n]
		_arch = _arch_of(t)
		var old: bool = _is_narrow(t)
		narrow.append(old)
		_tube(inner, t, old)
		_portal(stone if old else portal, t.x, 1.0, old)
		_portal(stone if old else portal, t.x + t.y, -1.0, old)
		has_stone = has_stone or old
		_cover(outer, t, kind)
		_caps(portal if kind == &"city" else outer, t, kind)
		if old:
			_old_lamps(t, lamps)
			for e in [[t.x, 1.0], [t.x + t.y, -1.0]]:
				_name_plaque(float(e[0]), float(e[1]))
			continue
		var z: float = t.x + 2.0
		while z < t.x + t.y - 1.0:
			for side in [-1.0, 1.0]:
				lamps.append([_xf(z, side * 3.2, 7.92, Vector3(0.35, 0.1, 1.5)), Color(1.0, 0.62, 0.22)])
			if fmod(z - t.x, 96.0) < LAMP_EVERY:                          # placa verde de emergencia na parede
				lamps.append([_xf(z, -13.45, 2.6, Vector3(0.06, 0.6, 1.0)), Color(0.15, 0.95, 0.4)])
			z += LAMP_EVERY
	_add_mesh(inner, _inner_mat())
	_add_mesh(portal, _outer_mat(&"city"), false)
	if has_stone:
		_add_mesh(stone, _outer_mat(&"stone"), false)
	_add_mesh(outer, _outer_mat(kind))
	_add_lamps(lamps)
	TunnelLightPools.build(self, _pools)
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
	if _prev_amount > 0.5 and f <= 0.5 and f < _prev_amount:
		exited.emit()
	_prev_amount = f
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
## Tunel antigo (T-153): concreto escurecido, lampadas mais espacadas e mais fracas.
func _lit(z: float, h: float, old: bool = false) -> Color:
	var every: float = OLD_LAMP_EVERY if old else LAMP_EVERY
	var lamp: float = 0.5 + 0.5 * cos(fmod(z, every) / every * TAU)
	if old:   # T-155: um pouco mais claro (antes 0,3 + 0,7 x lampada; quase preto entre as lampadas)
		var conc := Color(0.45, 0.41, 0.36) if h > 1.0 else Color(0.24, 0.22, 0.2)
		return conc * (0.42 + 0.78 * lamp * lamp) * clampf(1.25 - h / 9.0, 0.5, 1.0)
	var tile := Color(0.62, 0.52, 0.4) if h > 1.2 else Color(0.3, 0.26, 0.22)
	var near_top: float = clampf(h / 8.2, 0.3, 1.0)
	return tile * (0.45 + 0.55 * lamp) * near_top


## Perfil completo do tunel (esquerda -> direita, [lateral m, altura m]): o arco normal espelhado ou, no tunel antigo
## (T-153), o arco estreito em volta das muretas do trecho de 2 faixas.
## T-155: ARCH/OLD_ARCH vao do PE ao TOPO; o perfil sobe pela esquerda e desce pela direita (antes comecava no topo,
## descia pela esquerda e pulava do pe esquerdo para a parede direita a meia altura: uma chapa inclinada atravessava o
## tunel, a boca ficava fechada (pe = topo = centro) e as lampadas do tunel antigo iam para o meio da pista).
func _arch_of(t: Vector2) -> Array:
	var out: Array = []
	var prof: Array = OLD_ARCH if _is_narrow(t) else ARCH
	var c: float = 0.0
	var half: float = 1.0
	if _is_narrow(t):
		var p: Vector3 = LaneSections.profile(path.track.events, t.x + t.y * 0.5)
		var left: float = -(p.x + RoadMesh.BARRIER_W + 0.25)
		var right: float = p.y + RoadMesh.BARRIER_W + 0.25
		c = (left + right) * 0.5
		half = (right - left) * 0.5
	for k in prof.size():                                            # esquerda: pe -> topo
		out.append([c - float(prof[k][0]) * half, float(prof[k][1])])
	for k in range(prof.size() - 2, -1, -1):                         # direita: topo -> pe (sem repetir o topo)
		out.append([c + float(prof[k][0]) * half, float(prof[k][1])])
	return out


## T-153: o tunel inteiro fica dentro de um trecho de 2 faixas (mureta da direita no lugar estreito).
func _is_narrow(t: Vector2) -> bool:
	for zz in [t.x, t.x + t.y * 0.5, t.x + t.y]:
		if LaneSections.profile(path.track.events, zz).y > LaneSections.RIGHT_WALL_M + 0.05:
			return false
	return true


func _tube(st: SurfaceTool, t: Vector2, old: bool = false) -> void:
	var z: float = t.x
	var step: float = Track.SEG_LEN
	while z < t.x + t.y:
		var z1: float = minf(z + step, t.x + t.y)
		for k in _arch.size() - 1:
			var p0: Array = _arch[k]
			var p1: Array = _arch[k + 1]
			var a: Vector3 = _edge(z, float(p0[0]), float(p0[1]))
			var b: Vector3 = _edge(z, float(p1[0]), float(p1[1]))
			var c: Vector3 = _edge(z1, float(p1[0]), float(p1[1]))
			var d: Vector3 = _edge(z1, float(p0[0]), float(p0[1]))
			for v in [a, c, b, a, d, c]:                                  # material sem cull: a ordem nao importa
				var vz: float = z if (v == a or v == b) else z1
				st.set_color(_lit(vz, v.y - path.center_at(vz).y, old))
				st.add_vertex(v)
		z = z1


## Boca do tunel: placa de concreto (pedra no tunel antigo) com o furo do arco. `facing` = 1 na entrada, -1 na saida.
func _portal(st: SurfaceTool, z: float, facing: float, old: bool = false) -> void:
	var col: Color = OLD_STONE if old else Color(0.3, 0.3, 0.32)
	var lf: float = float(_arch[0][0])
	var rf: float = float(_arch[_arch.size() - 1][0])
	var c: float = (lf + rf) * 0.5
	var w: float = 30.0 + absf(c)                                       # cobre ate os muros laterais (_caps, em +-30)
	var top: float = PORTAL_H if not old else 10.0
	var lw: float = (lf - 2.6) if old else lf                            # tunel antigo: so a moldura de pedra em volta do arco
	var rw: float = (rf + 2.6) if old else rf
	for k in _arch.size() - 1:                                          # do arco ate o topo
		var p0: Array = _arch[k]
		var p1: Array = _arch[k + 1]
		_face(st, z, facing, [Vector2(p0[0], p0[1]), Vector2(p1[0], p1[1]), Vector2(p1[0], top), Vector2(p0[0], top)], col)
	if old:
		_face(st, z, facing, [Vector2(lw, 0), Vector2(lf, 0), Vector2(lf, top), Vector2(lw, top)], col)
		_face(st, z, facing, [Vector2(rf, 0), Vector2(rw, 0), Vector2(rw, top), Vector2(rf, top)], col)
		var hill := Color(0.24, 0.3, 0.21)                              # o morro em volta e por cima da boca de pedra
		_face(st, z, facing, [Vector2(c - w, 0), Vector2(lw, 0), Vector2(lw, PORTAL_H), Vector2(c - w, PORTAL_H)], hill)
		_face(st, z, facing, [Vector2(rw, 0), Vector2(c + w, 0), Vector2(c + w, PORTAL_H), Vector2(rw, PORTAL_H)], hill)
		_face(st, z, facing, [Vector2(lw, top), Vector2(rw, top), Vector2(rw, PORTAL_H), Vector2(lw, PORTAL_H)], hill)
		return
	_face(st, z, facing, [Vector2(c - w, 0), Vector2(lf, 0), Vector2(lf, top), Vector2(c - w, top)], col)
	_face(st, z, facing, [Vector2(rf, 0), Vector2(c + w, 0), Vector2(c + w, top), Vector2(rf, top)], col)


## Tunel antigo: lampadas fracas nas paredes, alternando os lados; placa verde de emergencia mais rara.
func _old_lamps(t: Vector2, lamps: Array) -> void:
	var lf: float = float(_arch[0][0])
	var rf: float = float(_arch[_arch.size() - 1][0])
	var z: float = t.x + 4.0
	var n: int = 0
	while z < t.x + t.y - 2.0:
		var side_lat: float = (lf + 0.12) if n % 2 == 0 else (rf - 0.12)
		var inward: float = 1.0 if n % 2 == 0 else -1.0
		# T-155: lampada maior e mais clara (antes quase nao aparecia) + poca de luz fraca no asfalto embaixo dela
		lamps.append([_xf(z, side_lat + 0.12 * inward, 3.4, Vector3(0.2, 0.3, 1.3)), OLD_LAMP])
		_pools.append(Transform3D(Basis(Vector3.UP, path.yaw_at(z)), _edge(z, side_lat + 2.4 * inward, 0.05)))
		if n % 10 == 5:
			lamps.append([_xf(z + 3.0, lf + 0.08, 2.4, Vector3(0.06, 0.5, 0.8)), Color(0.15, 0.85, 0.35)])
		z += OLD_LAMP_EVERY * 0.5
		n += 1


## Placa com o nome do tunel antigo em cima da boca (扁額 de pedra clara com letras escuras).
func _name_plaque(z: float, facing: float) -> void:
	var lf: float = float(_arch[0][0])
	var rf: float = float(_arch[_arch.size() - 1][0])
	var c: float = (lf + rf) * 0.5
	var turn: float = 0.0 if facing > 0.0 else PI
	var b := Basis(Vector3.UP, path.yaw_at(z) + turn)
	var pos: Vector3 = _edge(z, c, 8.2) - path.forward_at(z) * facing * 0.12
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.6, 1.3)
	bg.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.74, 0.66)
	m.roughness = 0.95
	bg.material_override = m
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.visibility_range_end = 320.0
	bg.transform = Transform3D(b, pos)
	add_child(bg)
	var l := Label3D.new()
	l.text = OLD_NAME
	l.font = load(RoadFurniture.SIGN_FONT) as Font
	l.font_size = 96
	l.pixel_size = 0.0095
	l.modulate = Color(0.12, 0.1, 0.09)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.visibility_range_end = 320.0
	l.transform = Transform3D(b, pos - path.forward_at(z) * facing * 0.02)
	add_child(l)


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
				st.set_normal(Vector3.UP)          # T-155: os muros (_caps) poem normal na mesma malha; generate_normals refaz
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
	var tex: String = "res://assets/textures/grass.png" if kind != &"city" and kind != &"stone" else "res://assets/textures/concrete_streaks.png"
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
