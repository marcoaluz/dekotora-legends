class_name RoadMeshNarrow
extends RefCounted
## Segmentos da estrada onde a pista estreita para 2 faixas (T-153), usados pelo RoadMesh. A geometria vem do MESMO
## perfil que a simulacao usa (LaneSections.profile: face das muretas e linha de borda), entao o caminhao para onde a
## mureta esta desenhada:
## - asfalto das 3 faixas cortado na mureta da direita (a faixa da direita some no afunilamento), acostamentos
##   estreitos, linha de borda nova continua (corre na frente da mureta) e a linha antiga contornando o zebrado;
## - muretas que entram em diagonal dos dois lados (no tunel antigo: pre-iluminadas; no viaduto antigo e na ponte: a
##   face de fora desce ate a borda do tabuleiro, sem barreira de som, concreto mais velho);
## - ponte (RouteDef.bridges): sem chao embaixo (o mar do cenario aparece), guarda-corpo de concreto dos dois lados com
##   corrimao de metal (pilares no SectionStructures3D).
## O zebrado (listras diagonais) vai na superficie das linhas do pedaco (mesmo material: brilha igual a noite).

const OLD_CONCRETE := Color(0.74, 0.71, 0.66)   # viaduto antigo / ponte: concreto mais escuro e amarelado
const ZEBRA_EVERY: float = 3.2                  # m entre listras
const ZEBRA_W: float = 0.55                     # m de largura de cada listra (ao longo da pista)
const ZEBRA_SLANT: float = 2.4                  # m que a ponta de fora avanca (listra em diagonal)


static func segment(rm: RoadMesh, sts: Dictionary, i: int, j: int, tunnel: bool, bridge: bool, band: bool, q: int) -> void:
	var pi: Vector3 = rm.profile(i)
	var pj: Vector3 = rm.profile(j)
	var z: float = float(i) * Track.SEG_LEN
	var ev: TrackEvents.Event = LaneSections.at(rm.path.track.events, z, Track.SEG_LEN)
	var old: bool = bridge or (ev != null and ev.look == "old_viaduct")
	var rs: SurfaceTool = sts["troad"] if tunnel else sts["road"]
	var asph: float = RoadMesh.LANE_W * float(RoadMesh.LANES) * 0.5          # 5,4 m
	var gw: float = Track.ROAD_HALF_WIDTH_M + RoadMesh.RUMBLE_W + RoadMesh.SHOULDER_W
	var age: float = 0.9 if old else 1.0
	# asfalto: as 3 faixas com trilhas de roda, a da direita cortada na mureta
	for lane in RoadMesh.LANES:
		var x0: float = -asph + float(lane) * RoadMesh.LANE_W
		var tint: Color = rm._lane_tint(i, lane) * age
		for b in RoadMesh.LANE_BANDS.size():
			var a0: float = x0 + float(RoadMesh.LANE_BANDS[b][0])
			var a1: float = x0 + (float(RoadMesh.LANE_BANDS[b + 1][0]) if b + 1 < RoadMesh.LANE_BANDS.size() else RoadMesh.LANE_W)
			var m: float = float(RoadMesh.LANE_BANDS[b][1])
			var c := Color(tint.r * m, tint.g * m, tint.b * m)
			if a0 >= pi.y and a0 >= pj.y:
				continue
			rm._strip2(rs, i, j, minf(a0, pi.y), minf(a1, pi.y), minf(a0, pj.y), minf(a1, pj.y), 0.0, 0.0, c)
	# acostamentos (cinza claro ate gw, mais escuro ate a mureta), cortados nas muretas
	var shoulder: Color = Color(0.86, 0.86, 0.88) * (rm._lane_tint(i, 9) if tunnel else Color.WHITE) * age
	var gray := Color(0.7, 0.7, 0.72) * age
	_side_strip(rm, rs, i, j, -1.0, asph, gw, pi.x, pj.x, shoulder)
	_side_strip(rm, rs, i, j, -1.0, gw, RoadMesh.BARRIER_IN, pi.x, pj.x, gray)
	_side_strip(rm, rs, i, j, 1.0, asph, gw, pi.y, pj.y, shoulder)
	_side_strip(rm, rs, i, j, 1.0, gw, RoadMesh.BARRIER_IN, pi.y, pj.y, gray)
	_lines(rm, sts, i, j, pi, pj, band)
	# muretas nas faces que a simulacao usa
	var drop: bool = rm._deck > 0.0 or bridge
	var bcol: Color = (Color(0.62, 0.52, 0.4) * rm._lane_tint(i, 9)) if tunnel else (OLD_CONCRETE if old else Color.WHITE)
	var bst: SurfaceTool = sts["tbarrier"] if tunnel else sts["barrier"]
	var coast_rail: bool = rm.kind == &"coast" and not bridge and not tunnel
	rm._barrier2(bst, i, j, pi.x, pj.x, -1.0, bcol, drop)
	if coast_rail:                                                            # litoral em terra: guard-rail como no resto
		rm._blade2(sts["rail"], i, j, pi.y + 0.3, pj.y + 0.3, 0.55, 0.85)
		rm._blade2(sts["rail"], i, j, pi.y + 0.3, pj.y + 0.3, 0.3, 0.42)
	else:
		rm._barrier2(bst, i, j, pi.y, pj.y, 1.0, bcol, drop)
	if bridge or (old and rm._deck > 0.0):                                   # corrimao de metal em cima do guarda-corpo
		for side in [-1.0, 1.0]:
			var li: float = (pi.x if side < 0.0 else pi.y) + 0.3
			var lj: float = (pj.x if side < 0.0 else pj.y) + 0.3
			rm._blade2(sts["rail"], i, j, side * li, side * lj, 1.02, 1.12)
	# alem das muretas
	var bo: float = RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W
	if bridge:
		return                                                               # ponte: o mar aparece embaixo
	if rm._deck > 0.0:                                                       # viaduto: o chao la embaixo
		rm._strip(sts["ground"], i, j, -bo - RoadMesh.GRASS_WIDTH, -bo, -rm._deck, -rm._deck)
		rm._strip(sts["ground"], i, j, bo, bo + RoadMesh.GRASS_WIDTH, -rm._deck, -rm._deck)
		rm._strip2(sts["ground"], i, j, -bo, -pi.x - RoadMesh.BARRIER_W, -bo, -pj.x - RoadMesh.BARRIER_W, -rm._deck, -rm._deck)
		rm._strip2(sts["ground"], i, j, pi.y + RoadMesh.BARRIER_W, bo, pj.y + RoadMesh.BARRIER_W, bo, -rm._deck, -rm._deck)
		return
	rm._strip2(sts["ground"], i, j, -bo - RoadMesh.GRASS_WIDTH, -pi.x, -bo - RoadMesh.GRASS_WIDTH, -pj.x)
	if rm.kind == &"coast":
		var sea: float = gw + RoadMesh.COAST_GRASS
		rm._strip2(sts["ground"], i, j, pi.y, sea, pj.y, sea)
		rm._strip(sts["sand"], i, j, sea, sea + RoadMesh.COAST_SAND, 0.0, -RoadMesh.SEA_DROP)
	else:
		rm._strip2(sts["ground"], i, j, pi.y, bo + RoadMesh.GRASS_WIDTH, pj.y, bo + RoadMesh.GRASS_WIDTH)


## Faixa do lado `side` entre l0 e l1 (m, positivos), cortada na mureta (face em wi no segmento i, wj no j).
static func _side_strip(rm: RoadMesh, st: SurfaceTool, i: int, j: int, side: float, l0: float, l1: float, wi: float,
		wj: float, col: Color) -> void:
	if l0 >= wi and l0 >= wj:
		return
	rm._strip2(st, i, j, side * minf(l0, wi), side * minf(l1, wi), side * minf(l0, wj), side * minf(l1, wj), 0.0, 0.0, col)


## Linhas: divisao 1/2 normal, divisao 2/3 so enquanto a faixa da direita existe, borda esquerda normal, borda direita
## nova (continua, em diagonal no afunilamento) e a borda antiga contornando o zebrado.
static func _lines(rm: RoadMesh, sts: Dictionary, i: int, j: int, pi: Vector3, pj: Vector3, band: bool) -> void:
	var z: float = float(i) * Track.SEG_LEN
	var sharp: bool = absf(rm.path.track.curves[i]) >= RoadFurniture.SHARP_CURVE
	var half_w: float = RoadMesh.LANE_W * 0.5
	for side in [-1.0, 1.0]:
		var c: float = side * half_w
		if rm._lane_ends(z, side):
			continue
		if side > 0.0 and (pi.z < half_w + 0.9 or pj.z < half_w + 0.9):
			continue                                                        # a faixa da direita acabou: sem divisao
		if sharp:
			rm._strip(sts["yline"], i, j, c - 0.08, c + 0.08, 0.02, 0.02)
		elif band:
			rm._strip(sts["line"], i, j, c - 0.08, c + 0.08, 0.02, 0.02)
	var e: float = RoadMesh.LANE_W * float(RoadMesh.LANES) * 0.5 - 0.25
	rm._strip(sts["line"], i, j, -e - 0.1, -e + 0.1, 0.02, 0.02)              # borda esquerda
	rm._strip2(sts["line"], i, j, pi.z - 0.1, pi.z + 0.1, pj.z - 0.1, pj.z + 0.1, 0.02, 0.02)   # borda direita nova
	if pi.z < e - 0.25 and pj.z < e - 0.25 and pi.y > e + 0.5 and pj.y > e + 0.5:
		rm._strip(sts["line"], i, j, e - 0.1, e + 0.1, 0.02, 0.02)          # borda antiga: contorno do zebrado
	_zebra(rm, sts["line"], i, j)


## Listras diagonais do zebrado entre a linha de borda nova e a borda antiga (ou a mureta, o que vier antes), na
## superficie das linhas. Cada listra nasce no segmento em que comeca.
static func _zebra(rm: RoadMesh, st: SurfaceTool, i: int, j: int) -> void:
	var z0: float = float(i) * Track.SEG_LEN
	var z1: float = float(j) * Track.SEG_LEN
	var zs: float = ceilf(z0 / ZEBRA_EVERY) * ZEBRA_EVERY
	var evs: TrackEvents = rm.path.track.events
	var e: float = LaneSections.EDGE_LINE_M - 0.15
	while zs < z1:
		var a: Vector3 = LaneSections.profile(evs, zs)
		var b: Vector3 = LaneSections.profile(evs, zs + ZEBRA_SLANT)
		var in_a: float = a.z + 0.18
		var out_b: float = minf(e, b.y - 0.45)
		if out_b - in_a > 0.6 and minf(e, a.y - 0.45) - in_a > 0.3:
			var p0: Vector3 = rm.path.world_point(zs, in_a / Track.ROAD_HALF_WIDTH_M, 0.022)
			var p1: Vector3 = rm.path.world_point(zs + ZEBRA_W, (LaneSections.profile(evs, zs + ZEBRA_W).z + 0.18) / Track.ROAD_HALF_WIDTH_M, 0.022)
			var p2: Vector3 = rm.path.world_point(zs + ZEBRA_SLANT + ZEBRA_W, out_b / Track.ROAD_HALF_WIDTH_M, 0.022)
			var p3: Vector3 = rm.path.world_point(zs + ZEBRA_SLANT, out_b / Track.ROAD_HALF_WIDTH_M, 0.022)
			rm._quad(st, p0, p3, p2, p1)
		zs += ZEBRA_EVERY
