class_name LifeBirds
extends MultiMeshInstance3D
## T-189 (vida): flocks of birds crossing the sky by day (gulls on the coast, dark birds elsewhere). One MultiMesh for
## every bird; the wings flap in the shader (phase per copy). Each flock flies straight with a slow turn and is sent
## ahead again when it falls behind the player. Seeded by the route: same flocks every race. Only visual.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.08, 0.08, 0.1);
varying float shade;
void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float rate = 7.0 + INSTANCE_CUSTOM.y * 4.0;
	float glide = step(0.55, sin(TIME * 0.6 + ph));             // flocks glide for a while, then flap
	float flap = sin(TIME * rate + ph) * mix(1.0, 0.15, glide);
	float span = abs(VERTEX.x);
	VERTEX.y += flap * span * 0.55;
	shade = 1.0 - span * 0.25;
}
void fragment() {
	ALBEDO = tint * shade;
}
"""

const FLOCK_MIN: int = 6
const FLOCK_MAX: int = 13

var path: TrackPath
var _flocks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _total: int = 0


## `count` flocks (0 = none). Gulls (white, bigger) on the coast.
func setup(path_: TrackPath, route_id: String, scenery: StringName, tod: TimeOfDay, count: int) -> void:
	path = path_
	_rng.seed = 1890 + route_id.hash()
	var gulls: bool = scenery == &"coast"
	for f in count:
		var n: int = _rng.randi_range(FLOCK_MIN, FLOCK_MAX)
		var fl: Dictionary = {"n": n, "first": _total, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "turn": 0.0, "off": []}
		for b in n:                                          # loose V: rows behind the leader
			var row: int = (b + 1) / 2
			var side: float = 1.0 if b % 2 == 0 else -1.0
			fl["off"].append(Vector3(side * row * _rng.randf_range(1.6, 2.6), _rng.randf_range(-0.8, 0.8), row * _rng.randf_range(1.8, 2.8)))
		_flocks.append(fl)
		_total += n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true            # T-186 trap: custom data without colours arrives as COLOR in Compatibility
	mm.use_custom_data = true
	mm.mesh = _wing_mesh(1.9 if gulls else 1.4)
	mm.instance_count = _total
	for i in _total:
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf(), 0.0, 0.0))
	multimesh = mm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	var c: Color = Color(0.92, 0.92, 0.9) if gulls else Color(0.07, 0.07, 0.09)
	mat.set_shader_parameter("tint", c.lerp(Color(0.1, 0.08, 0.12), 0.7 * (1.0 - tod.day_amount)))
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e5, -200, -1e5), Vector3(2e5, 600, 2e5))


## Bird = a flat "V": body point in the middle, two wings swept back (x = span).
static func _wing_mesh(span: float) -> ArrayMesh:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.18), Vector3(-span * 0.5, 0, 0.12), Vector3(0, 0, 0.1),
		Vector3(0, 0, -0.18), Vector3(0, 0, 0.1), Vector3(span * 0.5, 0, 0.12)])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _respawn(fl: Dictionary, player_z: float, first: bool) -> void:
	var z: float = player_z + (_rng.randf_range(40.0, 450.0) if first else _rng.randf_range(250.0, 550.0))
	z = clampf(z, 0.0, path.track.length_m - 1.0)
	var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var lat: float = side * _rng.randf_range(30.0, 150.0)
	var base: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, _rng.randf_range(14.0, 42.0))
	var across: Vector3 = -path.right_at(z) * side                   # crosses the road towards the other side
	var dir: Vector3 = across.rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7)).normalized()
	fl["pos"] = base
	fl["vel"] = dir * _rng.randf_range(8.0, 13.0)
	fl["turn"] = _rng.randf_range(-0.08, 0.08)


func update(dt: float, player_z: float) -> void:
	if multimesh == null or path == null:
		return
	var mm: MultiMesh = multimesh
	var far_ahead: Vector3 = path.center_at(player_z)
	for fl in _flocks:
		if fl["vel"] == Vector3.ZERO:
			_respawn(fl, player_z, true)
		var p: Vector3 = fl["pos"]
		var rel: Vector3 = p - far_ahead
		var ahead: float = rel.dot(path.forward_at(player_z))
		if ahead < -120.0 or rel.length() > 1400.0:
			_respawn(fl, player_z, false)
		var v: Vector3 = (fl["vel"] as Vector3).rotated(Vector3.UP, float(fl["turn"]) * dt)
		fl["vel"] = v
		fl["pos"] = p + v * dt
		var b := Basis.looking_at(v.normalized(), Vector3.UP)
		var offs: Array = fl["off"]
		var t: float = Time.get_ticks_msec() * 0.001
		for i in int(fl["n"]):
			var o: Vector3 = offs[i]
			var wob := Vector3(sin(t * 0.9 + i) * 0.4, sin(t * 1.3 + i * 2.1) * 0.5, 0.0)
			mm.set_instance_transform(int(fl["first"]) + i, Transform3D(b, fl["pos"] + b * (o + wob)))
