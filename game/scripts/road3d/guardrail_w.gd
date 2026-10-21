class_name GuardrailW
extends RefCounted
## Guard-rail em "W" (T-163) varrido ao longo da pista, sem emenda nas curvas: o PERFIL e o do guard-rail do kit
## "road" (CGTrader; PontesKit.profile(), gravado pelo build_road_pontes_kit.py) e a textura e a do kit reduzida
## (aco galvanizado). Postes de perfil a cada 4 m atras da lamina. Vai na superficie "rail" do RoadMesh (mesmo
## material dos corrimaos): nenhuma chamada de desenho a mais. Custo: ~14 triangulos por 4 m + 8 por poste.
## `lat` = face dos postes (m do centro); a lamina fica do lado da pista dela (profundidade do perfil).

const STEP_SEGS: int = 2                  # um anel do perfil a cada 2 segmentos (4 m)


## Lamina do segmento i ao j (lat_i/lat_j = face dos postes em i/j, sempre positiva; side = -1 esquerda, +1 direita).
static func sweep(rm: RoadMesh, st: SurfaceTool, i: int, j: int, lat_i: float, lat_j: float, side: float) -> void:
	var prof: Array = PontesKit.profile()
	var zi: float = float(i) * Track.SEG_LEN
	var zj: float = float(j) * Track.SEG_LEN
	var ui: float = zi / PontesKit.GR_LEN
	var uj: float = zj / PontesKit.GR_LEN
	rm._used[st] = true
	for k in prof.size() - 1:
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		var a: Vector3 = rm._edge(i, side * (lat_i - float(p0[0])), float(p0[1]))
		var b: Vector3 = rm._edge(i, side * (lat_i - float(p1[0])), float(p1[1]))
		var c: Vector3 = rm._edge(j, side * (lat_j - float(p1[0])), float(p1[1]))
		var d: Vector3 = rm._edge(j, side * (lat_j - float(p0[0])), float(p0[1]))
		var uv := [Vector2(ui, float(p0[2])), Vector2(ui, float(p1[2])), Vector2(uj, float(p1[2])), Vector2(uj, float(p0[2]))]
		var vs := [a, b, c, d]
		for n in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_uv(uv[n])
			st.add_vertex(vs[n])
	var zp: float = ceilf(zi / PontesKit.GR_POST_EVERY) * PontesKit.GR_POST_EVERY
	while zp < zj - 0.01:                                               # postes atras da lamina
		var t: float = (zp - zi) / maxf(zj - zi, 0.001)
		_post(rm, st, zp, lerpf(lat_i, lat_j, t), side)
		zp += PontesKit.GR_POST_EVERY


static func _post(rm: RoadMesh, st: SurfaceTool, z: float, lat: float, side: float) -> void:
	var path: TrackPath = rm.path
	var hw: float = Track.ROAD_HALF_WIDTH_M
	var top: float = PontesKit.GR_POST_TOP
	var f := func(dz: float, dl: float, h: float) -> Vector3:
		return path.world_point(z + dz, side * (lat + dl) / hw, h)
	var v0: float = PontesKit.GR_POST_V.x
	var v1: float = PontesKit.GR_POST_V.y
	# frente (para a pista), dois lados e o topo: [cantos], u de 0 a 0,05
	var faces: Array = [
		[f.call(-0.075, 0.0, 0.0), f.call(-0.075, 0.0, top), f.call(0.075, 0.0, top), f.call(0.075, 0.0, 0.0)],
		[f.call(-0.075, 0.1, 0.0), f.call(-0.075, 0.1, top), f.call(-0.075, 0.0, top), f.call(-0.075, 0.0, 0.0)],
		[f.call(0.075, 0.0, 0.0), f.call(0.075, 0.0, top), f.call(0.075, 0.1, top), f.call(0.075, 0.1, 0.0)],
		[f.call(-0.075, 0.0, top), f.call(-0.075, 0.1, top), f.call(0.075, 0.1, top), f.call(0.075, 0.0, top)]]
	var uv := [Vector2(0.0, v1), Vector2(0.0, v0), Vector2(0.05, v0), Vector2(0.05, v1)]
	for q in faces:
		for n in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0.8, 0.8, 0.8))
			st.set_uv(uv[n])
			st.add_vertex(q[n])


## Faces (lateral em m, altura em m) da frente da lamina num ponto: para testes (nao cruza a mureta, fica na pista?).
static func front_laterals(lat: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in PontesKit.profile():
		out.append(lat - float(p[0]))
	return out
