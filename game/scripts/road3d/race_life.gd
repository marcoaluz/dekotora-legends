class_name RaceLife
extends Node3D
## T-189: the "life" of the race scenery, everything only visual (no sim, no network, never an obstacle) and behind
## Settings.fx_life (off by default on the phone):
##   wind on trees and bushes (LifeWind), falling leaves near the camera, bird flocks by day (LifeBirds),
##   factory/village smoke, drain steam and insects at the lamps (LifeEmitters), cloud shadows (CloudShadows, PC).
## The race calls build() once, attach_camera() once and update() every frame.

var wind_nodes: int = 0
var _birds: LifeBirds
var _emit: LifeEmitters
var _clouds: CloudShadows
var _leaves: CPUParticles3D
var _tod: TimeOfDay
var _scenery: StringName
var _q: int = 1


static func enabled() -> bool:
	var s: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	return s != null and bool(s.get("fx_life"))


func build(path: TrackPath, route_id: String, scenery: StringName, tod: TimeOfDay, q: int, roadside: Node,
		tunnels: Array[Vector2], bridges: Array[Vector2]) -> void:
	name = "RaceLife"
	_tod = tod
	_scenery = scenery
	_q = q
	if roadside != null:
		wind_nodes = LifeWind.apply(roadside)
	var flocks: int = 0
	if tod.day_amount >= 0.2:
		flocks = 4 if q >= 3 else (3 if q >= 2 else 2)
		_birds = LifeBirds.new()
		_birds.name = "Birds"
		add_child(_birds)
		_birds.setup(path, route_id, scenery, tod, flocks)
	_emit = LifeEmitters.new()
	_emit.name = "Emitters"
	add_child(_emit)
	_emit.setup(path, route_id, scenery, tod, q, roadside, tunnels, bridges)
	if CloudShadows.available(tod):
		_clouds = CloudShadows.new()
		_clouds.name = "CloudShadows"
		add_child(_clouds)
		_clouds.setup(path, route_id, tod)
	print("LIFE_T189 %s wind=%d flocks=%d smoke=%d steam=%d insects=%d clouds=%s" % [route_id, wind_nodes, flocks,
		_emit.sources["smoke"].size(), _emit.sources["steam"].size(), _emit.sources["insects"].size(), _clouds != null])


## Falling leaves ahead of the camera (day/dusk, not on the city viaduct).
func attach_camera(cam: Camera3D) -> void:
	if cam == null or _tod == null or _tod.day_amount < 0.2 or _scenery == &"city":
		return
	_leaves = CPUParticles3D.new()
	_leaves.name = "Leaves"
	_leaves.local_coords = false
	_leaves.amount = 40 if _q >= 2 else 18
	_leaves.lifetime = 5.0
	_leaves.preprocess = 3.0
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(16.0, 5.0, 30.0)
	_leaves.position = Vector3(0.0, 3.0, -32.0)
	_leaves.direction = Vector3(1.0, -0.2, 0.6)
	_leaves.spread = 35.0
	_leaves.initial_velocity_min = 1.0
	_leaves.initial_velocity_max = 3.0
	_leaves.gravity = Vector3(0.6, -0.7, 0.4)
	_leaves.angle_min = 0.0
	_leaves.angle_max = 360.0
	_leaves.angular_velocity_min = -220.0
	_leaves.angular_velocity_max = 220.0
	_leaves.scale_amount_min = 0.7
	_leaves.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color("#5f7a2a"))
	g.set_color(1, Color("#b8862e"))
	g.add_point(0.5, Color("#8a6a2a"))
	_leaves.color_initial_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.09)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true                 # T-185 trap
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	quad.material = mat
	_leaves.mesh = quad
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leaves.visibility_aabb = AABB(Vector3(-60, -30, -90), Vector3(120, 60, 140))
	cam.add_child(_leaves)


func update(dt: float, player_z: float, cam_pos: Vector3) -> void:
	if _birds != null:
		_birds.update(dt, player_z)
	if _emit != null:
		_emit.update(dt, cam_pos)
	if _clouds != null:
		_clouds.update(dt, player_z)
