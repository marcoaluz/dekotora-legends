class_name KitProps3D
extends Node3D
## Pecas fixas do kit da T-146 (RoadsideKit), so visuais e deterministicas (so dependem da pista):
## - OUTDOORS (painel grande em pernas de trelica, do "Placao") fora da mureta, ~1 a cada 1,15 km, virados um pouco
##   para a pista; arte trocavel em PNG (assets/scenery/billboards/ad_0N.png ou user://billboards/ad_0N.png).
##   Acesos a noite (arte sem luz por pixel). No viaduto as pernas descem ate o chao (modelo alto).
## - Muro listrado amarelo e preto (barreira de concreto do pacote "Metal and Concrete Barriers") na ponta da mureta,
##   dos dois lados, na boca de cada tunel (como nas vias expressas japonesas).
## Custo: por outdoor visivel 2 chamadas (estrutura + arte); muros das bocas 1 chamada por tunel visivel.

const EVERY_M: float = 1150.0
const FIRST_M: float = 700.0
const LATERAL_M: float = 26.0            # longe das arvores (ate ~23 m) e dos predios (>= 95 m)
const TURN: float = 0.32                 # rad: vira o painel para a pista
const RANGE_M: float = 900.0

var counts: Dictionary = {}
var _boards: MeshBatch
var _walls: MeshBatch


func build(path: TrackPath, kind: StringName, tod: TimeOfDay, tunnels: Array[Vector2]) -> void:
	if not RoadsideKit.enabled():
		return
	_boards = MeshBatch.new(EVERY_M, RANGE_M)
	_walls = MeshBatch.new(EVERY_M, 520.0)
	var deck: float = RoadMesh.deck_height(kind)
	_billboards(path, kind, tod, tunnels, deck)
	_portals(path, tod, tunnels)
	_boards.commit(self)
	_walls.commit(self)
	if "--fps-log" in OS.get_cmdline_user_args():
		print("KIT: outdoors e bocas de tunel ", counts, "  triangulos=", _boards.tris + _walls.tris)


func _billboards(path: TrackPath, kind: StringName, tod: TimeOfDay, tunnels: Array[Vector2], deck: float) -> void:
	var L: float = path.track.length_m
	var model: String = "billboard_tall" if deck > 0.0 else "billboard_low"
	var mesh: ArrayMesh = RoadsideKit.mesh(model, tod)
	if mesh == null:
		return
	var leg: float = float(RoadsideKit.BILL_LEG[model])
	var level: float = 1.05 if tod.lamps_on else lerpf(0.8, 0.95, tod.day_amount)   # aceso a noite
	var z: float = FIRST_M
	var k: int = 0
	while z < L - 200.0:
		var g: float = fposmod(z - RoadSigns.GANTRY_FIRST, RoadSigns.GANTRY_EVERY)
		if RoadMesh.in_tunnel(z, tunnels, 150.0) or minf(g, RoadSigns.GANTRY_EVERY - g) < 70.0 \
				or LaneSections.at(path.track.events, z, 60.0) != null:       # T-153: nem na ponte nem no trecho estreito
			z += 90.0                                        # escapa do tunel/portico mais adiante
			continue
		var side: float = -1.0 if kind == &"coast" or k % 2 == 0 else 1.0   # litoral: o mar fica a direita
		var b := Basis(Vector3.UP, path.yaw_at(z) - side * TURN)
		var base: Vector3 = path.world_point(z, side * LATERAL_M / Track.ROAD_HALF_WIDTH_M, -deck)
		_boards.add(mesh, Transform3D(b, base), z)
		_art(b, base + Vector3.UP * (leg + RoadsideKit.BILL_ART.y * 0.5) + b.z * 0.02, k % RoadsideKit.ART_COUNT + 1, level)
		counts["billboard"] = int(counts.get("billboard", 0)) + 1
		k += 1
		z += EVERY_M


func _art(b: Basis, c: Vector3, i: int, level: float) -> void:
	var tex: Texture2D = RoadsideKit.art(i)
	if tex == null:
		return
	var q := QuadMesh.new()
	q.size = RoadsideKit.BILL_ART
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(level, level, level)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = RANGE_M
	mi.transform = Transform3D(b, c)
	add_child(mi)


## Muro listrado na ponta da mureta, antes da boca de cada tunel (T-155: maior e na frente da mureta; antes eram 2
## pecas de 1,3 m em cima da mureta de 0,85 m, quase escondidas): 4 pecas em fila, a da boca mais alta (2,3 m),
## descendo ate a altura de uma barreira, mais largas e com a face listrada um pouco para dentro da pista.
const PORTAL_STEPS: Array[float] = [1.75, 1.5, 1.25, 1.0]    # altura de cada peca (x 1,3 m), da boca para fora
const PORTAL_WIDE: float = 1.3                               # largura x 0,51 m
const PORTAL_OUT: float = 0.15                               # face da peca alem da face da mureta (m, para a pista)


func _portals(path: TrackPath, tod: TimeOfDay, tunnels: Array[Vector2]) -> void:
	var mesh: ArrayMesh = RoadsideKit.mesh("barrier_wall", tod)
	if mesh == null:
		return
	var half_w: float = RoadsideKit.WALL_W * PORTAL_WIDE * 0.5
	for t in tunnels:
		for n in PORTAL_STEPS.size():
			var z: float = t.x - RoadsideKit.JERSEY_LEN * (n + 0.5) - 0.2
			var b := Basis(Vector3.UP, path.yaw_at(z)) * Basis.from_scale(Vector3(PORTAL_WIDE, PORTAL_STEPS[n], 1.0))
			var p: Vector3 = LaneSections.profile(path.track.events, z)      # T-153: tunel antigo, muretas do trecho
			for side in [-1.0, 1.0]:
				var lat: float = (p.x if side < 0.0 else p.y) - PORTAL_OUT + half_w
				_walls.add(mesh, Transform3D(b, path.world_point(z, side * lat / Track.ROAD_HALF_WIDTH_M, 0.0)), z)
				counts["portal_wall"] = int(counts.get("portal_wall", 0)) + 1
