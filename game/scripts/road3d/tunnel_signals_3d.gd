class_name TunnelSignals3D
extends Node3D
## Semaforos de controle de faixa nos tuneis (車線規制信号, T-164; ideia do Tunnel.obj de docs/Modelos/Road_pontes,
## refeito por codigo seguindo a curva): um portico na boca e a cada EVERY_M dentro de cada tunel, com um sinal por
## faixa: seta verde para baixo (faixa livre) ou X vermelho (faixa fechada). Decisao do Marco (T-159): o X acompanha
## os eventos de faixa fechada (acidente, obras, estreitamento) que comecam ate AHEAD_M depois do portico ou que ja
## estao fechando a faixa ali. No tunel antigo de 2 faixas (T-153) ha so 2 sinais. So visual (a lista de eventos e a
## mesma da simulacao, inclusive online). Custo: 2 chamadas por tunel a vista (caixas + faces acesas), ~40
## triangulos por portico. --no-lane-signals desliga.

const EVERY_M: float = 200.0
const ENTRY_M: float = 6.0              # primeiro portico logo depois da boca
const END_GAP: float = 40.0
const AHEAD_M: float = 600.0
const H_NEW: float = 6.4                # base dos sinais (o teto dos tuneis novos fica a ~8 m no meio)
const H_OLD: float = 4.9                # tunel antigo (teto de 6,6 m)
const BOX: Vector3 = Vector3(1.1, 1.1, 0.35)
const RANGE_M: float = 420.0
const HOUSING := Color(0.09, 0.1, 0.11)
const STEEL := Color(0.42, 0.44, 0.47)

var gantries: Array = []                # [{z, states: Array[bool] (true = X vermelho), lanes: Array[int]}] (testes)

static var _tex: ImageTexture


static func enabled() -> bool:
	return not "--no-lane-signals" in OS.get_cmdline_user_args()


## Estado de cada faixa (1..3) num portico em z: true = fechada (X vermelho).
static func closed_lanes(evs: TrackEvents, z: float) -> Array[bool]:
	var out: Array[bool] = [false, false, false]
	if evs == null:
		return out
	for ev in evs.list:
		if ev.kind == TrackEvents.Kind.SECTION:
			continue
		if ev.z - z > AHEAD_M or ev.end_z() < z:
			continue
		for l in range(ev.lo, ev.hi + 1):
			if l >= Lanes.FIRST and l <= Lanes.LAST:
				out[l - Lanes.FIRST] = true
	return out


func build(path: TrackPath, tunnels: Array[Vector2], tod: TimeOfDay) -> void:
	if not enabled() or tunnels.is_empty():
		return
	var evs: TrackEvents = path.track.events
	for t in tunnels:
		var box := SurfaceTool.new()
		box.begin(Mesh.PRIMITIVE_TRIANGLES)
		var face := SurfaceTool.new()
		face.begin(Mesh.PRIMITIVE_TRIANGLES)
		var z: float = t.x + ENTRY_M
		while z < t.x + t.y - END_GAP:
			var sec: TrackEvents.Event = LaneSections.at(evs, z)
			var old: bool = sec != null and sec.look == "tunnel"
			var lanes: Array[int] = [1, 2]
			if not old:
				lanes.append(3)
			var states: Array[bool] = closed_lanes(evs, z)
			var h: float = H_OLD if old else H_NEW
			var b := Basis(Vector3.UP, path.yaw_at(z))
			# viga de aco atravessando as faixas
			var x0: float = Lanes.X[lanes[0]] * Track.ROAD_HALF_WIDTH_M - 1.0
			var x1: float = Lanes.X[lanes[-1]] * Track.ROAD_HALF_WIDTH_M + 1.0
			var mid: Vector3 = path.world_point(z, (x0 + x1) * 0.5 / Track.ROAD_HALF_WIDTH_M, h + BOX.y + 0.12)
			_box(box, b, mid, Vector3(x1 - x0, 0.18, 0.18), STEEL)
			for l in lanes:
				var lat: float = Lanes.X[l]
				var c: Vector3 = path.world_point(z, lat, h + BOX.y * 0.5)
				_box(box, b, c, BOX, HOUSING)
				var back: Vector3 = -path.forward_at(z).normalized()
				_face(face, path.right_at(z).normalized(), back, c + back * (BOX.z * 0.5 + 0.01), states[l - 1])
			gantries.append({"z": z, "states": states, "lanes": lanes})
			z += EVERY_M
		_commit(box, _housing_mat())
		_commit(face, _face_mat(tod))
	if "--fps-log" in OS.get_cmdline_user_args():
		print("SINAIS: porticos de faixa nos tuneis ", gantries.size())


func _commit(st: SurfaceTool, mat: Material) -> void:
	var mesh: ArrayMesh = st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = RANGE_M
	add_child(mi)


## Face acesa virada para quem chega (-z da pista = de onde o caminhao vem). Atlas: esquerda seta, direita X.
func _face(st: SurfaceTool, right: Vector3, back: Vector3, c: Vector3, red: bool) -> void:
	var r: Vector3 = right * (BOX.x * 0.42)
	var u: Vector3 = Vector3.UP * (BOX.y * 0.42)
	var u0: float = 0.5 if red else 0.0
	var q: Array = [c - r - u, c + r - u, c + r + u, c - r + u]
	var uv: Array = [Vector2(u0, 1), Vector2(u0 + 0.5, 1), Vector2(u0 + 0.5, 0), Vector2(u0, 0)]
	var order: Array = [0, 1, 2, 0, 2, 3] if (r.cross(u)).dot(back) > 0.0 else [0, 2, 1, 0, 3, 2]   # frente para quem chega
	for i in order:
		st.set_normal(back)
		st.set_uv(uv[i])
		st.add_vertex(q[i])


func _box(st: SurfaceTool, b: Basis, c: Vector3, size: Vector3, col: Color) -> void:
	var half: Vector3 = size * 0.5
	for f in TrackEvents3D.CUBE:
		var n: Vector3 = (b * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var p: Array[Vector3] = []
		for v in q:
			p.append(c + b * ((v as Vector3) * half))
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(p[i])


func _housing_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	return m


func _face_mat(tod: TimeOfDay) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = atlas()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.6, 1.6, 1.6)          # acima de 1: o brilho (glow) pega o sinal dentro do tunel
	return m


## Atlas 128 x 64 desenhado no codigo: seta verde para baixo (esquerda) e X vermelho (direita), fundo preto.
static func atlas() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(128, 64, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.02, 0.02))
	var green := Color(0.2, 1.0, 0.45)
	var red := Color(1.0, 0.12, 0.1)
	for y in 64:
		for x in 64:
			var fx: float = (float(x) - 31.5) / 32.0
			var fy: float = (float(y) - 31.5) / 32.0
			var shaft: bool = absf(fx) < 0.16 and fy > -0.72 and fy < 0.15         # haste da seta
			var head: bool = fy >= 0.05 and fy < 0.72 and absf(fx) < (0.72 - fy) * 0.95   # ponta para baixo
			if shaft or head:
				img.set_pixel(x, y, green)
			var d1: float = absf(fx - fy) / 1.4142
			var d2: float = absf(fx + fy) / 1.4142
			if (d1 < 0.12 or d2 < 0.12) and absf(fx) < 0.7 and absf(fy) < 0.7:
				img.set_pixel(64 + x, y, red)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
