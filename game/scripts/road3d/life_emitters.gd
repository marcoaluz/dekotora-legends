class_name LifeEmitters
extends Node3D
## T-189 (vida): point sources with a particle effect, served by a small POOL of emitters that follow the player
## (only the nearest sources are alive, so a long route costs the same as a short one):
##   smoke   -> factory chimneys (coast: land side; city: behind the blocks) and village smoke in the mountains
##   steam   -> drains on the shoulder (ground-level roads), a thin white puff
##   insects -> swarms around the street lamps at night (sources = the light pools of Roadside3D)
## Sources are placed once per route with a fixed seed (same every race). Only visual (Settings.fx_life).

const KINDS: Dictionary = {        # pool size, range (m) in which a source may get an emitter
	"smoke": [4, 1600.0],
	"steam": [3, 160.0],
	"insects": [6, 130.0],
}
const CHIMNEY_H: float = 62.0
const LAMP_HEAD_H: float = 8.6     # m above the light pool (lamp_post / lamp_bridge heads)

var sources: Dictionary = {"smoke": [], "steam": [], "insects": []}   # kind -> Array[Vector3]
var _pools: Dictionary = {}        # kind -> Array[CPUParticles3D]
var _owner_of: Dictionary = {}     # CPUParticles3D -> source index (-1 = free)
var _t: float = 0.0
var _tod: TimeOfDay


## Places the sources. `roadside` = the built Roadside3D (light pools); `bridges`/`tunnels` = no drains there.
func setup(path: TrackPath, route_id: String, scenery: StringName, tod: TimeOfDay, q: int, roadside: Node,
		tunnels: Array[Vector2], bridges: Array[Vector2]) -> void:
	_tod = tod
	var rng := RandomNumberGenerator.new()
	rng.seed = 1891 + route_id.hash()
	var hw: float = Track.ROAD_HALF_WIDTH_M
	var length: float = path.track.length_m
	var deck: float = RoadMesh.deck_height(scenery)
	var z: float = 300.0
	while z < length - 200.0:                                    # chimneys / village smoke
		var lat: float
		if scenery == &"coast":
			lat = -rng.randf_range(160.0, 380.0)                  # land side (the sea is on the right)
		else:
			lat = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(180.0, 420.0)
		var base: Vector3 = path.world_point(z, lat / hw, -deck)
		if scenery == &"mountain":
			sources["smoke"].append(base + Vector3.UP * 4.0)
		else:
			var chimney: Vector3 = base - Vector3.UP * 6.0
			add_child(_chimney(chimney, tod))
			sources["smoke"].append(chimney + Vector3.UP * CHIMNEY_H)
		z += rng.randf_range(650.0, 1100.0)
	if deck <= 0.0:                                              # drains on the shoulder (ground-level roads)
		z = 220.0
		while z < length - 100.0:
			var on_bridge: bool = false
			for b in bridges:
				on_bridge = on_bridge or (z > b.x - 20.0 and z < b.x + b.y + 20.0)
			if not RoadMesh.in_tunnel(z, tunnels, 40.0) and not on_bridge:
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				sources["steam"].append(path.world_point(z, side * 1.06, 0.05))
			z += rng.randf_range(380.0, 620.0)
	if tod.lamps_on and roadside != null:                        # insects at the lamps (light pools)
		for mi in roadside.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
			if mm == null or not (mm.mesh is PlaneMesh):
				continue
			for i in mm.instance_count:
				var tr: Transform3D = (mi as MultiMeshInstance3D).transform * mm.get_instance_transform(i)
				if tr.origin != Vector3.ZERO:                      # headless MultiMesh keeps no transforms
					sources["insects"].append(tr.origin + Vector3.UP * LAMP_HEAD_H)
	var scale: int = 1 if q >= 2 else 0
	for kind in KINDS:
		var arr: Array[CPUParticles3D] = []
		var n: int = int(KINDS[kind][0]) if scale == 1 else maxi(int(KINDS[kind][0]) / 2, 1)
		if (sources[kind] as Array).is_empty():
			n = 0
		for i in n:
			var p: CPUParticles3D = _make(kind, tod)
			p.emitting = false
			p.visible = false
			add_child(p)
			arr.append(p)
			_owner_of[p] = -1
		_pools[kind] = arr


## Every 0.3 s: the nearest sources in range get an emitter (kept if they already had one).
func update(dt: float, cam_pos: Vector3) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.3
	for kind in _pools:
		var pool: Array = _pools[kind]
		if pool.is_empty():
			continue
		var list: Array = sources[kind]
		var reach: float = float(KINDS[kind][1])
		var near: Array = []
		for i in list.size():
			var d: float = (list[i] as Vector3).distance_to(cam_pos)
			if d < reach:
				near.append([d, i])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var want: Dictionary = {}
		for k in mini(near.size(), pool.size()):
			want[int(near[k][1])] = true
		for p in pool:                                           # free the emitters whose source left
			if int(_owner_of[p]) >= 0 and not want.has(int(_owner_of[p])):
				_owner_of[p] = -1
				p.emitting = false
				p.visible = false
		for p in pool:
			if int(_owner_of[p]) >= 0:
				want.erase(int(_owner_of[p]))
		for idx in want:
			for p in pool:
				if int(_owner_of[p]) < 0:
					_owner_of[p] = idx
					p.global_position = list[idx]
					p.visible = true
					p.restart()
					p.emitting = true
					break


## Red and white factory chimney with a red light at the top at night.
static func _chimney(base: Vector3, tod: TimeOfDay) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.height = CHIMNEY_H
	cm.top_radius = 1.5
	cm.bottom_radius = 2.4
	cm.radial_segments = 12
	cm.rings = 1
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float night = 0.0;
void fragment() {
	float band = step(0.5, fract(UV.y * 7.0));
	float top = step(UV.y, 0.3);
	vec3 red = vec3(0.62, 0.1, 0.08);
	ALBEDO = mix(vec3(0.78, 0.78, 0.76), red, top * band + (1.0 - top) * 0.0) * mix(1.0, 0.85, UV.y);
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.05, 0.02) * night * 4.0 * step(UV.y, 0.015);
}
"""
	mat.shader = sh
	mat.set_shader_parameter("night", 1.0 - tod.day_amount)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = base + Vector3.UP * CHIMNEY_H * 0.5
	mi.visibility_range_end = 3000.0
	return mi


static func _soft_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _make(kind: String, tod: TimeOfDay) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true                 # T-185 trap: without it unborn particles show full size, black
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_tex()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var day: float = tod.day_amount
	var ramp := Gradient.new()
	match kind:
		"smoke":
			p.amount = 26
			p.lifetime = 10.0
			p.preprocess = 10.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 1.2
			p.direction = Vector3.UP
			p.spread = 10.0
			p.initial_velocity_min = 2.4
			p.initial_velocity_max = 3.4
			p.gravity = Vector3(1.1, 0.15, 0.7)          # the wind bends the plume
			p.damping_min = 0.15
			p.damping_max = 0.25
			p.scale_amount_min = 5.0
			p.scale_amount_max = 7.0
			quad.size = Vector2(1, 1)
			var c: Color = Color(0.86, 0.86, 0.86).lerp(Color(0.25, 0.27, 0.33), 1.0 - day)
			ramp.set_color(0, Color(c.r, c.g, c.b, 0.55))
			ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
			var curve := Curve.new()
			curve.add_point(Vector2(0.0, 0.35))
			curve.add_point(Vector2(1.0, 2.6))
			p.scale_amount_curve = curve
			p.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 120, 160))
		"steam":
			p.amount = 14
			p.lifetime = 2.6
			p.preprocess = 2.6
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.25
			p.direction = Vector3.UP
			p.spread = 18.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0.25, 0.2, 0.15)
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.0
			quad.size = Vector2(1, 1)
			var curve2 := Curve.new()
			curve2.add_point(Vector2(0.0, 0.4))
			curve2.add_point(Vector2(1.0, 2.2))
			p.scale_amount_curve = curve2
			var w: Color = Color(0.92, 0.93, 0.95).lerp(Color(0.55, 0.58, 0.66), 1.0 - day)
			ramp.set_color(0, Color(w.r, w.g, w.b, 0.38))
			ramp.set_color(1, Color(w.r, w.g, w.b, 0.0))
			p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 10, 12))
		_:                                               # insects
			p.amount = 34
			p.lifetime = 1.6
			p.preprocess = 1.6
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.9
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.6
			p.gravity = Vector3.ZERO
			p.angular_velocity_min = 0.0
			p.tangential_accel_min = 1.5                 # circling around the light
			p.tangential_accel_max = 3.0
			p.damping_min = 0.4
			p.damping_max = 0.8
			p.scale_amount_min = 0.10
			p.scale_amount_max = 0.16
			quad.size = Vector2(1, 1)
			ramp.set_color(0, Color(3.0, 2.6, 1.6, 1.0))
			ramp.add_point(0.8, Color(3.0, 2.6, 1.6, 0.9))
			ramp.set_color(1, Color(3.0, 2.6, 1.6, 0.0))
			p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.color_ramp = ramp
	return p
