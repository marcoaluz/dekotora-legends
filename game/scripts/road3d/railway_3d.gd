class_name Railway3D
extends Node3D
## Ferrovia ao lado da rodovia (T-154, so visual): via dupla com lastro e dormentes (textura), 4 trilhos, muro do lado
## da pista, porticos de catenaria com os fios, viaduto de concreto com pilares (cidade e cruzamentos sobre a pista),
## bocas de tunel com morro/predio nas pontas e os trens (Trains3D + RailTraffic).
## Custo: uma superficie por bloco de 300 m (material rail_bed: lastro, trilho, muro, fio e tabuleiro na MESMA textura)
## + uma por bloco das pecas (MeshBatch: porticos, pilares, bocas) + 1 por morro visivel; tudo cortado por distancia.
## Nada aqui conversa com a simulacao: a mesma corrida com e sem ferrovia (--no-rail) e identica.

const CHUNK_PTS: int = 150           # pontos (2 m) por bloco (300 m)
const MAST_EVERY: float = 50.0
const PIER_EVERY: float = 30.0
const RANGE_M: float = 560.0
const BED_HALF: float = 5.5
const SHOULDER: float = 7.2          # pe do aterro (linha no chao)
const DECK_HALF: float = 6.3         # tabuleiro do viaduto
const DECK_DEPTH: float = 2.2
const WALL_LAT: float = 7.0          # muro do lado da pista
const WALL_H: float = 1.6
const WIRE_H: float = 5.0            # fio de contato acima do trilho
const MESSENGER_H: float = 6.2
const CONCRETE_TINT := Color(0.74, 0.74, 0.76)   # muro e guarda-corpo um pouco mais escuros que o tabuleiro
const RAILS: Array[float] = [-2.5335, -1.4665, 1.4665, 2.5335]   # 2 vias a +-2 m, bitola 1,067 m

var lines: Array[RailLine] = []
var traffic: RailTraffic
var trains: Trains3D
var path: TrackPath
var tod: TimeOfDay
var counts: Dictionary = {}
var tris: int = 0
var _items: Array = []               # pecas da linha em construcao: [ArrayMesh, Transform3D, s]
var _quality: int = 1


func build(path_: TrackPath, route_id: String, kind: StringName, tod_: TimeOfDay) -> void:
	path = path_
	tod = tod_
	if not RailKit.enabled():
		return
	_quality = int(Settings.quality)
	lines = RailwayLayout.lines_for(route_id, kind, path)
	if lines.is_empty():
		return
	for li in lines.size():
		_build_line(lines[li], li, kind)
	traffic = RailTraffic.new(lines, route_id.hash() & 0x7fffffff, RailwayLayout.main_train(route_id))
	_debug_flags()
	trains = Trains3D.new()
	add_child(trains)
	trains.setup(traffic, tod)
	if "--fps-log" in OS.get_cmdline_user_args():
		print("FERROVIA: ", counts, "  linhas=", lines.size(), "  triangulos=", tris)


## Chamado a cada quadro pela corrida (relogio da tela).
func update(dt: float, player_z: float, player_speed: float, cam_pos: Vector3) -> void:
	if traffic == null:
		return
	traffic.update(dt, player_z, player_speed)
	trains.refresh(cam_pos)


func _debug_flags() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--train="):
			traffic.force_type = RailTraffic.Type.LRT if a.substr(8) == "lrt" else RailTraffic.Type.FREIGHT
		elif a.begins_with("--train-dir="):
			traffic.force_dir = 1.0 if a.substr(12) == "same" else -1.0


func _build_line(l: RailLine, li: int, kind: StringName) -> void:
	var elevated: bool = l.ground > 0.0 or l.kind == RailLine.Kind.CROSSING
	_items.clear()
	_masts(l)
	if elevated:
		_piers(l, li)
	if l.end_portals.x == 1:
		_portal_end(l, 0.0, -1.0, kind)
	if l.end_portals.y == 1:
		_portal_end(l, l.length(), 1.0, kind)
	var n: int = l.pts.size()
	var start: int = 0
	while start < n - 1:
		var end: int = mini(start + CHUNK_PTS, n - 1)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(start, end, 2):                     # secoes de 4 m (curvas suaves: raio >= 400 m)
			_section(st, l, i, mini(i + 2, end), elevated)
		st.generate_normals()
		var all := SurfaceTool.new()                     # lastro + pecas do bloco (porticos, pilares, bocas)
		all.begin(Mesh.PRIMITIVE_TRIANGLES)
		all.append_from(st.commit(), 0, Transform3D.IDENTITY)
		var s0: float = l.cum[start] if start > 0 else -INF
		var s1: float = l.cum[end] if end < n - 1 else INF
		for it in _items:
			if float(it[2]) >= s0 and float(it[2]) < s1 and it[0] != null:
				all.append_from(it[0], 0, it[1])
		var mesh: ArrayMesh = all.commit()
		tris += mesh.surface_get_array_len(0) / 3
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = RailKit.material("rail_bed", tod)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = RANGE_M if _quality >= 1 else 400.0
		add_child(mi)
		counts["blocos"] = int(counts.get("blocos", 0)) + 1
		start = end


## Perfil da via entre os pontos i e j: segmentos [lat0, h0, v0, lat1, h1, v1] (h relativo ao trilho).
func _section(st: SurfaceTool, l: RailLine, i: int, j: int, elevated: bool) -> void:
	var segs: Array = []
	var foot: float = 6.0 if elevated else SHOULDER
	var fh: float = -0.55 if elevated else -0.6
	segs.append([-foot, fh, 0.004, -BED_HALF, -0.17, 0.004])                       # talude
	segs.append([-BED_HALF, -0.17, 0.0, BED_HALF, -0.17, RailKit.BED_V])            # lastro + dormentes
	segs.append([BED_HALF, -0.17, RailKit.BED_V - 0.004, foot, fh, RailKit.BED_V - 0.004])
	for r in RAILS:
		segs.append([r - 0.035, 0.0, RailKit.V_RAIL_TOP.x, r + 0.035, 0.0, RailKit.V_RAIL_TOP.y])
		segs.append([r + 0.035, 0.0, RailKit.V_RAIL_SIDE.y, r + 0.04, -0.17, RailKit.V_RAIL_SIDE.x])
	var c := RailKit.V_CONCRETE
	if elevated:                                                                    # tabuleiro + guarda-corpo
		for sd in [-1.0, 1.0]:
			segs.append([sd * 6.0, -0.55, c.x, sd * DECK_HALF, -0.55, c.x + 0.01])
			segs.append([sd * DECK_HALF, -DECK_DEPTH, c.x, sd * DECK_HALF, 0.6, c.y, CONCRETE_TINT])
			segs.append([sd * DECK_HALF, 0.6, c.y, sd * (DECK_HALF - 0.2), 0.6, c.y, CONCRETE_TINT])
			segs.append([sd * (DECK_HALF - 0.2), 0.6, c.y, sd * (DECK_HALF - 0.2), -0.55, c.x, CONCRETE_TINT])
		segs.append([-DECK_HALF, -DECK_DEPTH, RailKit.V_UNDER.x, DECK_HALF, -DECK_DEPTH, RailKit.V_UNDER.y])
	elif l.kind == RailLine.Kind.PARALLEL:                                          # muro do lado da pista
		var w: float = -l.side * WALL_LAT                                           # a pista fica do outro lado
		segs.append([w, -0.7, c.x, w, -0.5 + WALL_H, c.y, CONCRETE_TINT])
		segs.append([w, -0.5 + WALL_H, c.y, w - signf(w) * 0.2, -0.5 + WALL_H, c.y, CONCRETE_TINT])
	if _quality >= 1:                                                               # fios (contato e mensageiro)
		for tr in [-2.0, 2.0]:
			for h in [WIRE_H, MESSENGER_H]:
				segs.append([tr, h, RailKit.V_WIRE.x, tr, h + 0.06, RailKit.V_WIRE.y])
	var pi: Vector3 = l.pts[i]
	var pj: Vector3 = l.pts[j]
	var ri: Vector3 = Vector3(-l.dirs[i].z, 0.0, l.dirs[i].x)
	var rj: Vector3 = Vector3(-l.dirs[j].z, 0.0, l.dirs[j].x)
	var ui: float = l.cum[i] / RailKit.BED_U_M
	var uj: float = l.cum[j] / RailKit.BED_U_M
	for s in segs:
		var a: Vector3 = pi + ri * float(s[0]) + Vector3.UP * float(s[1])
		var b: Vector3 = pi + ri * float(s[3]) + Vector3.UP * float(s[4])
		var cc: Vector3 = pj + rj * float(s[3]) + Vector3.UP * float(s[4])
		var d: Vector3 = pj + rj * float(s[0]) + Vector3.UP * float(s[1])
		var ua := Vector2(ui, 1.0 - float(s[2]))
		var ub := Vector2(ui, 1.0 - float(s[5]))
		var uc := Vector2(uj, 1.0 - float(s[5]))
		var ud := Vector2(uj, 1.0 - float(s[2]))
		for k in [[a, ua], [cc, uc], [b, ub], [a, ua], [d, ud], [cc, uc]]:
			st.set_color(s[6] if s.size() > 6 else Color.WHITE)
			st.set_uv(k[1])
			st.add_vertex(k[0])


func _masts(l: RailLine) -> void:
	var mast: ArrayMesh = RailKit.bed_mesh("rail_mast")
	var s: float = 20.0
	var step: float = MAST_EVERY if _quality >= 1 else MAST_EVERY * 2.0
	while s < l.length() - 10.0:
		var base: Vector3 = l.point(s) + Vector3.UP * -0.5
		_items.append([mast, Transform3D(Basis.looking_at(l.dir(s), Vector3.UP), base), s])
		counts["porticos"] = int(counts.get("porticos", 0)) + 1
		s += step


func _piers(l: RailLine, li: int) -> void:
	var col: ArrayMesh = RailKit.bed_mesh("rail_pier")
	var cap: ArrayMesh = RailKit.bed_mesh("rail_pier_cap")
	var s: float = PIER_EVERY * 0.5
	while s < l.length():
		var p: Vector3 = l.point(s)
		var z: float = l.z_at(s)
		if _clear_of_road(p, z) and _clear_of_lines(p, li):
			var b := Basis.looking_at(l.dir(s), Vector3.UP)
			var top: Vector3 = p + Vector3.UP * -DECK_DEPTH
			var ground: float = path.center_at(z).y - l.ground - 0.5
			var h: float = top.y - 1.3 - ground
			_items.append([cap, Transform3D(b, top), s])
			if h > 0.2:
				_items.append([col, Transform3D(b * Basis.from_scale(Vector3(1.0, h, 1.0)), Vector3(top.x, ground, top.z)), s])
			counts["pilares"] = int(counts.get("pilares", 0)) + 1
		s += PIER_EVERY


## Pilar longe da pista e da mureta (o viaduto passa por cima sem apoio no meio).
func _clear_of_road(p: Vector3, z: float) -> bool:
	var c: Vector3 = path.center_at(z)
	return absf((p - c).dot(path.right_at(z))) > RoadMesh.BARRIER_IN + 4.0


func _clear_of_lines(p: Vector3, li: int) -> bool:
	for k in lines.size():
		if k == li:
			continue
		for q in lines[k].pts:
			if Vector2(p.x - q.x, p.z - q.z).length_squared() < 81.0:
				return false
	return true


## Boca de tunel na ponta `s` da linha; `into` = +1 se o tunel continua no sentido de s crescente.
func _portal_end(l: RailLine, s: float, into: float, kind: StringName) -> void:
	var f: Vector3 = l.dir(s) * into
	var o: Vector3 = l.point(s) + Vector3.UP * -0.5
	var b := Basis.looking_at(f, Vector3.UP)
	_items.append([RailKit.bed_mesh("rail_portal"), Transform3D(b, o), s])
	counts["bocas"] = int(counts.get("bocas", 0)) + 1
	var ground: float = path.center_at(l.z_at(s)).y - l.ground - 0.6
	var near_road: float = 30.0
	if l.kind == RailLine.Kind.PARALLEL:
		near_road = clampf(l.offset - 17.0, 6.0, 30.0)
	var hw_road: float = near_road
	var r: Vector3 = Vector3(-f.z, 0.0, f.x)             # direita de quem entra no tunel
	var road_right: bool = l.kind == RailLine.Kind.PARALLEL and (path.center_at(l.z_at(s)) - o).dot(r) > 0.0
	var hl: float = 30.0 if road_right else hw_road
	var hr: float = hw_road if road_right else 30.0
	if l.kind == RailLine.Kind.CROSSING:
		hl = 30.0
		hr = 30.0
	var city: bool = kind == &"city"
	RailMound.add_mound(self, o, f, r, ground, o.y + 11.0, hl, hr, city, tod)
