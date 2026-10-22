class_name RainFx
extends Node3D
## T-189: rain (Settings.fx_rain, optional, also on the phone where it already existed): the drops stay in
## LightStreaks; here come the SPRAY of water behind each truck (grows with the speed), the splash ring of drops on
## the road around the camera and the rain sound. The wet road is the time preset (UltraLook.tune_tod: lower
## roughness; on Ultra the SSR reflects the lights). Only visual/sound.

const SPRAY_FROM: float = 8.0       # m/s: below this no spray
const SOUND := "amb_rain_loop"

var _sprays: Array[CPUParticles3D] = []
var _splash: CPUParticles3D
var _sound: AudioStreamPlayer


func setup(trucks: Array, cam: Camera3D, tod: TimeOfDay, q: int) -> void:
	name = "RainFx"
	for t in trucks:
		var p: CPUParticles3D = _spray(tod, q)
		(t as Node3D).add_child(p)
		_sprays.append(p)
	if cam != null:
		_splash = _ground_splash(q)
		cam.add_child(_splash)
	if RaceAudio.has_sound(SOUND):
		var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")
		_sound = AudioStreamPlayer.new()
		_sound.stream = bus.call("stream", SOUND) if bus != null else null
		_sound.bus = "SFX"
		_sound.volume_db = -12.0
		add_child(_sound)
		if _sound.stream != null:
			_sound.play()


static func _soft_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true                   # T-185 trap
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = LifeEmitters._soft_tex()
	return m


## Mist thrown up by the rear wheels (truck origin = rear, local +Z = behind).
static func _spray(tod: TimeOfDay, q: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "RainSpray"
	p.local_coords = false
	p.amount = 90 if q >= 2 else 40
	p.lifetime = 0.7
	p.emitting = false
	p.position = Vector3(0.0, 0.5, 0.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.1, 0.2, 0.3)
	p.direction = Vector3(0.0, 0.5, 1.0)
	p.spread = 25.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0.0, -2.0, 0.0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, 3.0))
	p.scale_amount_curve = curve
	var c: Color = Color(0.85, 0.88, 0.92).lerp(Color(0.45, 0.48, 0.55), 1.0 - tod.day_amount)
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.16))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.material = _soft_mat(Color.WHITE)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -2, -4), Vector3(12, 8, 20))
	return p


## Small splashes of the drops on the road around the camera.
static func _ground_splash(q: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "RainSplash"
	p.local_coords = false
	p.amount = 90 if q >= 2 else 40
	p.lifetime = 0.25
	p.position = Vector3(0.0, -4.0, -16.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12.0, 0.1, 16.0)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.09
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.9, 1.0, 0.6))
	g.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	p.color_ramp = g
	var quad := QuadMesh.new()
	quad.material = _soft_mat(Color.WHITE)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-20, -10, -40), Vector3(40, 20, 60))
	return p


## `speeds[k]` = speed of truck k (m/s).
func update(speeds: Array[float]) -> void:
	for k in mini(_sprays.size(), speeds.size()):
		var p: CPUParticles3D = _sprays[k]
		var v: float = speeds[k]
		var on: bool = v > SPRAY_FROM
		if on != p.emitting:
			p.emitting = on
		if on:
			p.initial_velocity_min = 2.0 + v * 0.12
			p.initial_velocity_max = 4.0 + v * 0.2
