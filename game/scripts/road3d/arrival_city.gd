class_name ArrivalCity
extends Node3D
## T-195: the destination city after the finish line (only drawn; ArrivalLayout has the data). The road itself, its
## barriers, the ground and the viaduct piers go on by themselves (RoadMesh / TerrainPatch / ViaductPiers3D read
## TrackPath.end_m()). Here:
## - finish gantry at the line (two steel posts, checkered beam, "ゴール" + CHEGADA, lit at night);
## - city blocks on both sides of the avenue (CityBlocks, the same lots, facades, neon and textured buildings of the
##   city route; coast: only the land side, the sea stays on the right);
## - lamps along the avenue (Roadside3D.extra_objects, the same lamps and light pools);
## - a gateway building straddling the avenue near the end of the drawn road (the avenue runs under it into the city),
##   the skyline of the city behind it and a wide ground disc under everything: no edge of the world, no black void.

const GANTRY_H: float = 7.2
const GATE_H: float = 46.0
const GATE_SPAN: float = 34.0
const DISC_R: float = 3600.0

var block_count: int = 0          # tests / log
var skyline_count: int = 0
var path: TrackPath
var _boxes: Array = []            # [Transform3D, Color] facade boxes (CityLook.facade)
var _dark: Array = []             # [Transform3D, Color] props colour (CityLook.props)


func build(path_: TrackPath, route_id: String, kind: StringName, tod: TimeOfDay, keep_out: Array, roadside: Roadside3D) -> void:
	path = path_
	var L: float = path.track.length_m
	var end: float = path.end_m()
	if end <= L + 1.0:
		return
	var deck: float = RoadMesh.deck_height(kind)
	_gantry(L, tod)
	var field := TerrainField.new(path, &"city", Vector2(L + ArrivalLayout.CITY_FROM_M, end - 40.0), keep_out, 195)
	field.deck = deck
	var blocks := CityBlocks.new()
	blocks.force_city = true
	blocks.sides = ArrivalLayout.city_sides(kind)
	add_child(blocks)
	blocks.build(field, tod, keep_out, 195 + route_id.hash() % 1000)
	block_count = blocks.building_count
	if roadside != null:
		var z: float = L + 24.0
		while z < end - ArrivalLayout.GATE_BEFORE_END_M - 20.0:
			for side in [-1.0, 1.0]:
				roadside.extra_objects.append({"z": z, "x": side * (RoadMesh.BARRIER_IN + 0.35) / Track.ROAD_HALF_WIDTH_M,
					"kind": "lamp_post"})
			z += ArrivalLayout.LAMP_EVERY_M
	_gate(end - ArrivalLayout.GATE_BEFORE_END_M, deck)
	_skyline(end, deck, tod)
	_disc(end, kind, deck, tod)
	_commit(tod)
	print("ARRIVAL_T195 %s fim=%.0f m continuacao=%.0f m predios=%d skyline=%d" % [route_id, end, end - L, block_count,
		skyline_count])


## Finish gantry: 2 posts outside the barriers and a beam with a checkered band and the text.
func _gantry(z: float, tod: TimeOfDay) -> void:
	var b := Basis(Vector3.UP, path.yaw_at(z))
	var half: float = RoadMesh.BARRIER_IN + 1.2
	var steel := Color("#3a3d44")
	for side in [-1.0, 1.0]:
		var p: Vector3 = path.world_point(z, side * half / Track.ROAD_HALF_WIDTH_M, GANTRY_H * 0.5)
		_dark.append([Transform3D(b * Basis.from_scale(Vector3(0.7, GANTRY_H, 0.7)), p), steel])
	var beam: Vector3 = path.world_point(z, 0.0, GANTRY_H + 0.9)
	_dark.append([Transform3D(b * Basis.from_scale(Vector3(half * 2.0 + 0.7, 1.9, 0.5)), beam), steel])
	var band := MeshInstance3D.new()                         # checkered band on both faces of the beam
	var q := QuadMesh.new()
	q.size = Vector2(half * 2.0, 1.5)
	band.mesh = q
	band.material_override = _checker_material(tod)
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.transform = Transform3D(b, beam + b * Vector3(0.0, 0.0, 0.27))      # +Z local = toward the driver
	add_child(band)
	var col: Color = Color(1.0, 0.86, 0.35) if tod == null or tod.day_amount > 0.5 else Color(1.0, 0.55, 0.2)
	var top: Vector3 = beam + Vector3.UP * 2.1 + b * Vector3(0.0, 0.0, 0.3)
	var t: Label3D = MenuBackdrop.neon(self, "ゴール  " + Tr.t("race.arrival_gate"), top, col, 0.035, 64, 0.0)
	t.basis = b
	t.outline_size = 6


static func _checker_material(tod: TimeOfDay) -> StandardMaterial3D:
	var img := Image.create(32, 4, false, Image.FORMAT_RGB8)
	for x in 32:
		for y in 4:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.06))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var night: float = 1.0 - (tod.day_amount if tod != null else 1.0)
	m.emission_enabled = night > 0.2
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.9 * night
	return m


## Gateway building over the avenue: two towers beside the road joined by a bridge block above it; dark recess under
## the bridge so the avenue seems to go on into the city.
func _gate(z: float, deck: float) -> void:
	var b := Basis(Vector3.UP, path.yaw_at(z))
	var ground: float = -deck
	var wall := Color("#a7a299")
	wall.a = (3.0 + 0.5) / 16.0 + 0.5
	for side in [-1.0, 1.0]:
		var w: float = 24.0
		var lat: float = side * (GATE_SPAN * 0.5 + w * 0.5)
		var h: float = GATE_H + deck + (8.0 if side > 0.0 else 0.0)
		var p: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, ground + h * 0.5)
		_boxes.append([Transform3D(b * Basis.from_scale(Vector3(w, h, 30.0)), p), wall])
	var bridge_h: float = GATE_H - 9.0
	var pb: Vector3 = path.world_point(z, 0.0, 9.0 + bridge_h * 0.5)
	var upper := Color("#8e939a")
	upper.a = (5.0 + 0.5) / 16.0
	_boxes.append([Transform3D(b * Basis.from_scale(Vector3(GATE_SPAN + 0.5, bridge_h, 26.0)), pb), upper])
	var ceil_p: Vector3 = path.world_point(z + 4.0, 0.0, 8.7)              # underside of the bridge (dark)
	_dark.append([Transform3D(b * Basis.from_scale(Vector3(GATE_SPAN, 0.6, 34.0)), ceil_p), Color("#1c1d21")])
	for side in [-1.0, 1.0]:                                           # inner walls of the passage
		var pw: Vector3 = path.world_point(z + 4.0, side * (GATE_SPAN * 0.5 - 0.3) / Track.ROAD_HALF_WIDTH_M, 4.5)
		_dark.append([Transform3D(b * Basis.from_scale(Vector3(0.6, 9.0, 34.0)), pw), Color("#2a2b30")])
	var back: Vector3 = path.world_point(z + 20.0, 0.0, 4.5)            # far end of the underpass: the road goes on in the dark
	_dark.append([Transform3D(b * Basis.from_scale(Vector3(GATE_SPAN, 9.4, 0.6)), back), Color("#0d0e11")])


## The skyline of the destination city behind the gateway (the same towers as the city route, docs/Modelos/Cidade).
func _skyline(end: float, deck: float, tod: TimeOfDay) -> void:
	var mesh: ArrayMesh = CityModels.skyline_mesh(tod)
	if mesh == null:
		return
	var c: Vector3 = path.center_at(end)
	var f: Vector3 = path.forward_at(end)
	var r: Vector3 = path.right_at(end)
	var spots: Array = [[520.0, 0.0, 0.0], [760.0, -420.0, 1.9], [700.0, 430.0, 3.6]]
	for s in spots:
		var p: Vector3 = c + f * float(s[0]) + r * float(s[1])
		p.y = c.y - deck - 6.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Vector3.UP, path.yaw_at(end) + float(s[2])) * Basis.from_scale(Vector3.ONE * CityModels.SKYLINE_SCALE), p)
		add_child(mi)
		skyline_count += 1


## Wide flat ground under everything around the arrival (below the terrain and the sea): beyond the terrain grid the
## camera sees ground fading into the fog, not the dark bottom of the sky.
func _disc(end: float, kind: StringName, deck: float, tod: TimeOfDay) -> void:
	var c: Vector3 = path.center_at(lerpf(path.track.length_m, end, 0.6))
	var y: float = c.y - deck - (6.0 if kind == &"coast" else 2.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col: Color = Color(0.0, 0.0, 1.0, 1.0) if kind == &"city" else Color(0.0, 0.25, 0.0, 1.0)
	var n: int = 24
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		for v in [Vector3.ZERO, Vector3(cos(a1), 0.0, sin(a1)), Vector3(cos(a0), 0.0, sin(a0))]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(c.x, y, c.z) + v * DISC_R)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ScenicShaders.terrain(tod)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _commit(tod: TimeOfDay) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multi(box, _boxes, CityLook.facade(tod))
	_multi(box, _dark, CityLook.props())


func _multi(mesh: Mesh, items: Array, mat: Material) -> void:
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
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
