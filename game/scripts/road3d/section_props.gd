class_name SectionProps
extends RefCounted
## Sinalizacao de um trecho de 2 faixas (T-153), nos lotes do TrackEvents3D (as mesmas 3 chamadas de um evento):
##  - painel de LED "この先 2車線 / 追越車線 終わり" 600 m antes do afunilamento (lado direito, como os eventos);
##  - losango de faixa que acaba (direita) + "車線減少" + 400 m e 200 m;
##  - placa azul "この先 2車線" com o desenho das faixas na esquerda, logo antes do afunilamento;
##  - setas pintadas em diagonal na faixa da direita (entre na fila) e chapas listradas na mureta que entra.
## O asfalto, as linhas, o zebrado e as muretas sao do RoadMesh (RoadMeshNarrow), no MESMO perfil da simulacao.

const M: float = Track.ROAD_HALF_WIDTH_M
const LEFT_BOARD_LAT: float = -(RoadMesh.BARRIER_IN - 1.1)
const WHITE_P := Color(0.93, 0.93, 0.9)


static func build(b: TrackEvents3D, ev: TrackEvents.Event, k: int) -> void:
	_led(b, ev.z - 600.0)
	for d in [[400.0, "d400"], [200.0, "d200"]]:
		var z: float = ev.z - float(d[0])
		if z > 30.0:
			EventProps._diamond(b, z, "warn_narrow_r", "aux_narrow", String(d[1]))
			b.count("sign")
	_blue_board(b, ev.z - 90.0)
	_arrows(b, ev)
	_wall_stripes(b, ev)
	b.count("section")


static func _led(b: TrackEvents3D, z: float) -> void:
	if z < 30.0:
		return
	var bs: Basis = b.basis(z)
	var c: Vector3 = b.pt(z, EventProps.BOARD_LAT, 4.2)
	b.face(bs, c, Vector2(3.0, 1.5), "vms_lanes2")
	b.box(bs, c - bs.z * 0.06, Vector3(3.1, 1.6, 0.1), Color("#2a2c31"))
	for sx in [-1.0, 1.0]:
		var base: Vector3 = b.pt(z, EventProps.BOARD_LAT, 0.0) + bs.x * sx - bs.z * 0.15
		b.box(Basis(), base + Vector3.UP * 2.1, Vector3(0.12, 4.2, 0.12), EventProps.POST)
	b.count("sign")


static func _blue_board(b: TrackEvents3D, z: float) -> void:
	if z < 30.0:
		return
	var bs: Basis = b.basis(z, 0.08)
	var c: Vector3 = b.pt(z, LEFT_BOARD_LAT, 3.6)
	b.face(bs, c, Vector2(2.6, 1.3), "board_lanes2")
	b.box(bs, c - bs.z * 0.05, Vector3(2.7, 1.4, 0.06), EventProps.POST)
	for sx in [-0.9, 0.9]:
		var base: Vector3 = b.pt(z, LEFT_BOARD_LAT + sx, 0.0) - bs.z * 0.1
		b.box(Basis(), base + Vector3.UP * 1.45, Vector3(0.11, 2.9, 0.11), EventProps.POST)
	b.count("sign")


## Setas pintadas na faixa da direita apontando para a do meio (antes de a faixa fechar).
static func _arrows(b: TrackEvents3D, ev: TrackEvents.Event) -> void:
	var lane_c: float = Lanes.X[Lanes.LAST] * M
	var last: float = ev.block_z[Lanes.LAST] - 12.0
	for dz in [-60.0, -20.0, 15.0]:
		var z0: float = ev.z + dz
		if z0 > last:
			continue
		var tail: Vector3 = b.pt(z0, lane_c + 0.4, 0.03)
		var tip_z: float = z0 + 5.5
		var tip_lat: float = lane_c - 0.9
		var neck: Vector3 = b.pt(tip_z - 1.4, tip_lat + 0.45, 0.03)
		var side_v: Vector3 = b.path.right_at(z0) * 0.16
		b.paint_tri(tail - side_v, neck - side_v, neck + side_v, WHITE_P)
		b.paint_tri(tail - side_v, neck + side_v, tail + side_v, WHITE_P)
		var wing: Vector3 = b.path.right_at(z0) * 0.6
		b.paint_tri(neck - wing, b.pt(tip_z, tip_lat, 0.03), neck + wing, WHITE_P)


## Chapas listradas (amarelo e preto) na face da mureta da direita onde ela atravessa o acostamento e a faixa.
static func _wall_stripes(b: TrackEvents3D, ev: TrackEvents.Event) -> void:
	var zz: float = ev.z
	while zz < ev.full_z():
		var w0: float = LaneSections.profile(b.events, zz).y
		var w1: float = LaneSections.profile(b.events, zz + 2.4).y
		if w0 < 9.6 and w1 > LaneSections.RIGHT_WALL_M + 0.4:
			var slope: float = atan((w0 - w1) / 2.4)                  # the wall comes in: its face looks back a little
			var bs: Basis = b.basis(zz + 1.2, -(PI * 0.5 - slope))
			b.face(bs, b.pt(zz + 1.2, (w0 + w1) * 0.5 - 0.06, 0.52), Vector2(2.3, 0.45), "barricade")
		zz += 2.6
