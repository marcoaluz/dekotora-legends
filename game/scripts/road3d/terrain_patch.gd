class_name TerrainPatch
extends Node3D
## T-188: ground with relief beside the road on the pilot stretch (replaces RoadMesh's flat grass and sand there).
## Road-aligned grid (rows every ROW_M along the road, columns at LATS metres from the centre line), heights from
## TerrainField, one material (ScenicShaders.terrain: grass in 3 tones, dirt, rock, forest canopy, sand, street).
## Indexed mesh with smooth normals, one MeshInstance3D per side and per CHUNK_ROWS rows (frustum culling).
## The far-shore strip of the coast (under the skyline across the bay) is built here too.

const ROW_M: float = 10.0
const CHUNK_ROWS: int = 25
const START: float = RoadMesh.BARRIER_IN             # under the barrier: no gap with the road
const LATS: PackedFloat32Array = [13.0, 16.0, 20.0, 24.0, 28.0, 34.0, 40.0, 46.0, 54.0, 64.0, 76.0, 90.0, 106.0,
	125.0, 147.0, 172.0, 200.0, 232.0, 268.0, 305.0, 345.0]
const SEA_LATS: PackedFloat32Array = [13.0, 17.0, 21.0, 24.0, 28.0, 33.0, 39.5, 50.0, 70.0]
const SHORE_LATS: PackedFloat32Array = [350.0, 360.0, 370.0, 380.0, 400.0, 430.0, 470.0, 520.0, 580.0, 650.0]

var field: TerrainField
var path: TrackPath
var tri_count: int = 0                                 # tests / measures


func build(field_: TerrainField, tod: TimeOfDay) -> void:
	field = field_
	path = field.path
	var z0: float = field.zone.x
	var z1: float = minf(field.zone.y, path.track.length_m - 1.0)
	if field.zone.y >= path.track.length_m - 1.0:
		z1 = path.end_m() - 1.0                        # T-195: o chao segue pela continuacao (cidade destino)
	if z1 <= z0:
		return
	var mat: ShaderMaterial = ScenicShaders.terrain(tod)
	var rows: int = int(ceil((z1 - z0) / ROW_M))
	var r0: int = 0
	while r0 < rows:
		var r1: int = mini(r0 + CHUNK_ROWS, rows)
		var za: float = z0 + float(r0) * ROW_M
		var zb: float = minf(z0 + float(r1) * ROW_M, z1)
		if field.kind == &"city":
			var both: PackedFloat32Array = PackedFloat32Array()
			for k in range(LATS.size() - 1, -1, -1):
				both.append(-LATS[k])
			both.append(0.0)
			both.append_array(LATS)
			_strip(za, zb, both, mat)
		else:
			_strip(za, zb, _negated(LATS), mat)
			_strip(za, zb, SEA_LATS if field.kind == &"coast" else LATS, mat)
			if field.kind == &"coast":
				_strip(za, zb, SHORE_LATS, mat)
		r0 = r1


func _negated(lats: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(lats.size() - 1, -1, -1):
		out.append(-lats[k])
	return out


## One grid from za to zb across the given laterals (sorted from left to right).
func _strip(za: float, zb: float, lats: PackedFloat32Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nz: int = int(ceil((zb - za) / ROW_M)) + 1
	var nl: int = lats.size()
	for r in nz:
		var z: float = minf(za + float(r) * ROW_M, zb)
		for c in nl:
			var lat: float = lats[c]
			var p: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, 0.0)
			var wp := Vector2(p.x, p.z)
			var h: float = field.rel_height(z, lat, wp)
			st.set_color(field.paint(lat, h, wp))
			st.add_vertex(p + Vector3.UP * (h - field.deck))
	for r in nz - 1:
		for c in nl - 1:
			var a: int = r * nl + c
			var b: int = a + 1
			var d: int = a + nl
			var e: int = d + 1
			for i in [a, d, b, b, d, e]:                  # clockwise seen from above = Godot front face (up)
				st.add_index(i)
			tri_count += 2
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
