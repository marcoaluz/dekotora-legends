class_name Overpass3D
extends Node3D
## Viaduto rodoviario cruzando por cima da pista (T-164), feito da Ponte A (docs/Modelos/Road_pontes): modulos de
## 10 m do tabuleiro (overpass_deck.glb = secao da crista da ponte: laje, 5 vigas em I, corrimao; perto da pista)
## e a versao leve (overpass_deck_lite.glb, longe), em linha reta e plana, mais pilares em "T" da mesma ponte
## (PierT) a cada 40 m (colunas simples longe da pista). Tudo numa malha so por viaduto (1 chamada quando a vista).
## O viaduto para antes de passar baixo demais sobre outro trecho da pista (rota em curva). So visual.
## --no-overpass (ou --no-pontes-kit) desliga.

const RANGE_M: float = 950.0
const PIER_FULL: float = 110.0          # pilar em T ate esta distancia do cruzamento; alem, coluna simples
const COLOR := Color(0.78, 0.78, 0.8)

var counts: Dictionary = {}
var tris: int = 0
var spans: Array = []                   # [s_min, s_max] de cada viaduto (para testes)


static func enabled() -> bool:
	return PontesKit.enabled() and not "--no-overpass" in OS.get_cmdline_user_args()


func build(path: TrackPath, route_id: String, tod: TimeOfDay, ground_y: float, rail_lines: Array = []) -> void:
	if not enabled():
		return
	var full: ArrayMesh = GlbMesh.merged(PontesKit.DIR + "overpass_deck.glb")
	var lite: ArrayMesh = GlbMesh.merged(PontesKit.DIR + "overpass_deck_lite.glb")
	if full.get_surface_count() == 0 or lite.get_surface_count() == 0:
		return
	var fa: Array = full.surface_get_arrays(0)
	var la: Array = lite.surface_get_arrays(0)
	for o in OverpassLayout.for_route(route_id):
		var ax: Dictionary = OverpassLayout.axis(path, o)
		var c: Vector3 = ax["c"]
		var d: Vector3 = ax["d"]
		var lat: Vector3 = d.cross(Vector3.UP).normalized()
		var top: float = float(ax["top"])
		var lim: Vector2 = Vector2(_extent(path, c, d, top, -1.0), _extent(path, c, d, top, 1.0))
		spans.append(lim)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var basis := Basis(d, Vector3.UP, d.cross(Vector3.UP))     # x do modulo ao longo do viaduto, z = lateral
		var m: float = lim.x
		while m < lim.y - 0.01:                                       # tabuleiro
			var near: bool = absf(m + 5.0) <= OverpassLayout.FULL_HALF
			_append(st, fa if near else la, Transform3D(basis, c + d * m))
			counts["deck_full" if near else "deck_lite"] = int(counts.get("deck_full" if near else "deck_lite", 0)) + 1
			m += 10.0
		var p: float = -OverpassLayout.PIER_EVERY * 0.5                # pilares em s = +-20, +-60, ...
		while p > lim.x + 4.0:
			p -= OverpassLayout.PIER_EVERY
		p += OverpassLayout.PIER_EVERY
		while p < lim.y - 4.0:
			_pier(st, path, c + d * p, lat, top, ground_y, absf(p) <= PIER_FULL, rail_lines)
			p += OverpassLayout.PIER_EVERY
		var mesh: ArrayMesh = st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		tris += mesh.surface_get_array_len(0) / 3
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = PontesKit.concrete(tod, 0.3)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = RANGE_M
		add_child(mi)
	if "--fps-log" in OS.get_cmdline_user_args():
		print("PONTES: viaduto por cima ", counts, "  triangulos=", tris)


## Ate onde o viaduto vai para um lado (sentido sg) sem passar baixo demais sobre a pista (outro trecho da rota).
static func _extent(path: TrackPath, c: Vector3, d: Vector3, top: float, sg: float) -> float:
	var s: float = 0.0
	while s < OverpassLayout.HALF_LEN:
		var q: Vector3 = c + d * (sg * (s + 10.0))
		var near: Dictionary = nearest_road(path, q)
		if float(near["dist"]) < 16.0 and top - OverpassLayout.BEAM_BOTTOM - float(near["y"]) < OverpassLayout.CLEAR - 0.2:
			break
		s += 10.0
	return sg * s


## Ponto da pista mais perto de q (no plano): {"dist", "y", "z"}.
static func nearest_road(path: TrackPath, q: Vector3) -> Dictionary:
	var best: float = INF
	var bz: float = 0.0
	var z: float = 0.0
	while z <= path.track.length_m:
		var p: Vector3 = path.center_at(z)
		var dd: float = Vector2(q.x - p.x, q.z - p.z).length_squared()
		if dd < best:
			best = dd
			bz = z
		z += 8.0
	return {"dist": sqrt(best), "y": path.center_at(bz).y, "z": bz}


func _append(st: SurfaceTool, arr: Array, xf: Transform3D) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col: Variant = arr[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var has_col: bool = col is PackedColorArray and (col as PackedColorArray).size() == v.size()
	var count: int = idx.size() if not idx.is_empty() else v.size()
	for k in count:
		var i: int = idx[k] if not idx.is_empty() else k
		st.set_color((col as PackedColorArray)[i] if has_col else COLOR)
		st.set_normal(xf.basis * n[i])
		st.add_vertex(xf * v[i])


func _pier(st: SurfaceTool, path: TrackPath, at: Vector3, lat: Vector3, top: float, ground_y: float, t_shape: bool,
		rail_lines: Array) -> void:
	var near: Dictionary = nearest_road(path, at)
	if float(near["dist"]) < OverpassLayout.PIER_ROAD_GAP:
		counts["pier_skip_road"] = int(counts.get("pier_skip_road", 0)) + 1
		return
	for l in rail_lines:
		for q in (l as RailLine).pts:
			if Vector2(q.x - at.x, q.z - at.z).length() < 8.0:
				counts["pier_skip_rail"] = int(counts.get("pier_skip_rail", 0)) + 1
				return
	var foot := Vector3(at.x, ground_y, at.z)
	var h: float = top - OverpassLayout.BEAM_BOTTOM - ground_y
	var b := Basis(lat, Vector3.UP, lat.cross(Vector3.UP))            # x do pilar = atravessando o tabuleiro
	if t_shape:
		PierT.append(st, foot, b, h, 12.05 * 0.74, COLOR * 0.95)
		counts["pier_t"] = int(counts.get("pier_t", 0)) + 1
	else:
		_column(st, foot, b, h)
		counts["pier_col"] = int(counts.get("pier_col", 0)) + 1


## Coluna simples (caixa 2,4 x 1,6 m) para os pilares longe da pista.
func _column(st: SurfaceTool, foot: Vector3, b: Basis, h: float) -> void:
	var half := Vector3(1.2, h * 0.5, 0.8)
	var c: Vector3 = foot + Vector3.UP * h * 0.5
	for f in TrackEvents3D.CUBE:
		var nn: Vector3 = (b * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var pts: Array[Vector3] = []
		for v in q:
			pts.append(c + b * ((v as Vector3) * half))
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(COLOR * 0.92)
			st.set_normal(nn)
			st.add_vertex(pts[i])
