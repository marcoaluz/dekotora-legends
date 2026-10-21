class_name SlopeForest
extends Node3D
## T-188: trees on the hills of the pilot stretch (beyond the roadside groves of RoadsideTrees, which stay at 15-34 m).
## Cheap cards (2 crossed quads = 4 triangles, conifer or broadleaf half of tree_cards.png) only where TerrainField
## paints forest; the canopy texture of the terrain fills the distance. One MultiMesh per side and per CHUNK_M of
## road, cut at VIEW_M. Deterministic (seeded).

const CHUNK_M: float = 200.0
const VIEW_M: float = 1300.0
const LAT: Vector2 = Vector2(52.0, 330.0)
const STEP_M: float = 9.0               # one try every STEP_M along the road, per side, per lateral band

var count: int = 0
var _mesh: ArrayMesh


func build(field: TerrainField, tod: TimeOfDay, seed_: int) -> void:
	var path: TrackPath = field.path
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + 31
	var conifer: float = 0.8 if field.kind == &"mountain" else 0.15
	var groups: Dictionary = {}                            # chunk key -> Array [Transform3D, Color custom]
	var z: float = field.zone.x
	while z < field.zone.y:
		for side in [-1.0, 1.0]:
			if field.kind == &"coast" and side > 0.0:
				continue                                   # the sea
			for band in 4:
				var lat: float = side * rng.randf_range(LAT.x + band * 70.0, LAT.x + (band + 1) * 70.0)
				var zz: float = z + rng.randf_range(0.0, STEP_M)
				var roll: float = rng.randf()
				var p: Vector3 = path.world_point(zz, lat / Track.ROAD_HALF_WIDTH_M)
				var wp := Vector2(p.x, p.z)
				var rel: float = field.rel_height(zz, lat, wp)
				var forest: float = field.paint(lat, rel, wp).g
				if roll > forest * 0.85:
					continue
				var tall: float = rng.randf_range(8.0, 15.0)
				var wide: float = tall * rng.randf_range(0.5, 0.65)
				var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(wide, tall, wide))
				var at: Vector3 = Vector3(p.x, p.y + rel - field.deck - 0.4, p.z)
				var kind_sel: float = 0.0 if rng.randf() < conifer else 1.0
				var key: int = int(zz / CHUNK_M) * 2 + (0 if side < 0.0 else 1)
				if not groups.has(key):
					groups[key] = []
				groups[key].append([Transform3D(b, at), Color(kind_sel, rng.randf_range(0.8, 1.1), 0.0, 0.0)])
				count += 1
		z += STEP_M
	var mat: ShaderMaterial = ScenicShaders.cards(tod)
	for key in groups:
		_multi(groups[key], mat)


func _multi(items: Array, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true                                   # Compatibility: custom data without colours arrives as COLOR
	mm.use_custom_data = true
	mm.mesh = _cards()
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VIEW_M
	mi.visibility_range_end_margin = 40.0
	add_child(mi)


## Two crossed unit quads standing on y = 0 (1 m wide, 1 m tall), UV v = 0 at the top.
func _cards() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		var a: Vector3 = -axis * 0.5
		var b: Vector3 = axis * 0.5
		var quad: Array = [[a, Vector2(0, 1)], [b + Vector3.UP, Vector2(1, 0)], [b, Vector2(1, 1)],
			[a, Vector2(0, 1)], [a + Vector3.UP, Vector2(0, 0)], [b + Vector3.UP, Vector2(1, 0)]]
		for v in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	_mesh = st.commit()
	return _mesh
