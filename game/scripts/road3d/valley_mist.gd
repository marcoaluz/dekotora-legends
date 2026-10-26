class_name ValleyMist
extends Node3D
## T-217: mist in the mountain valleys (perspective with fog, as in the original): big soft horizontal sheets
## between the hills (high, far) and a few low ones hugging the slopes near the road, drifting slowly. One MultiMesh
## (1 draw call); fades out near the camera so no sheet edge is ever seen up close. Colour from the time of day.

const EVERY_M: float = 120.0
const VIEW_M: float = 1600.0

var count: int = 0


func build(path: TrackPath, field: TerrainField, tod: TimeOfDay, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var items: Array = []
	var z: float = 150.0
	while z < path.track.length_m - 80.0:
		for side in [-1.0, 1.0]:
			var far: bool = rng.randf() < 0.65
			var lat: float = side * (rng.randf_range(120.0, 320.0) if far else rng.randf_range(60.0, 110.0))
			var p: Vector3 = path.world_point(z + rng.randf_range(-40.0, 40.0), lat / Track.ROAD_HALF_WIDTH_M, 0.0)
			var ground: float = p.y
			if field != null:
				var h: float = field.height_at(Vector2(p.x, p.z))
				if not is_nan(h):
					ground = h
			p.y = maxf(ground, path.center_at(z).y) + (rng.randf_range(14.0, 40.0) if far else rng.randf_range(4.0, 12.0))
			var w: float = rng.randf_range(140.0, 240.0) if far else rng.randf_range(60.0, 110.0)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, 1.0, w * rng.randf_range(0.45, 0.7)))
			items.append([Transform3D(b, p), Color(rng.randf(), 0.0, 0.0, 0.8 if far else 0.55)])
		z += EVERY_M
	if items.is_empty():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var day: float = tod.day_amount if tod != null else 1.0
	var tint: Color = tod.fog_color if tod != null else Color(0.8, 0.85, 0.9)
	tint = tint.lerp(Color(0.92, 0.94, 0.96), 0.45 * day)
	tint.a = lerpf(0.22, 0.42, day)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = LandmarkFx.mist_mat(tint)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	count = items.size()
