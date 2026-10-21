class_name WreckFx
extends Node3D
## T-183: what a crashed traffic car looks like. Presentation only: reads TrafficSim.Car.wrecked and crash_t (which
## come in the snapshot online), never changes the simulation.
##  - hazard lights: 4 amber lamps on the corners (WreckProps), all blinking together at the turn signal rhythm
##    (SignalBlink.HALF_S, ~1.5 Hz) by the visual clock. 2 draw calls per wreck; the blink only swaps the shared
##    materials on each edge (no per-car work per frame).
##  - light smoke from the hood during SMOKE_S s after the crash (behind Settings.fx_impact; amount by quality).
##  - warning triangle on the road TRIANGLE_DIST m behind the car, TRIANGLE_AFTER s after the crash and only once the
##    car stopped (the drawn position stops changing: works the same online, where the car speed is not sent).
## Traffic3D owns it: show_wreck(i, node, model, car, dt) for each wrecked car every frame, clear(i) when the car stops being a wreck.

const SMOKE_S: float = 12.0
const SMOKE_LIFE: float = 2.2
const SMOKE_AMOUNT: Array[int] = [6, 10, 14]
const TRIANGLE_AFTER: float = 3.0
const TRIANGLE_DIST: float = 9.0          # m behind the rear of the car
const TRIANGLE_MAX_X: float = 0.85        # x units: never outside the shoulder
const STILL_S: float = 0.3                # s without moving = the car stopped (places the triangle)

var path: TrackPath
var lit: bool = false                     # lamps lit now (tests)
var _kits: Dictionary = {}                # car index -> {lamps, glow, smoke, tri}
var _shapes: Dictionary = {}              # model name -> [lamps ArrayMesh, glow ArrayMesh]
var _lamp_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _tri_mesh: ArrayMesh
var _tri_mat: StandardMaterial3D
var _puff_mat: StandardMaterial3D
var _puff_mesh: QuadMesh
var _fx: bool = true
var _amount: int = 10
var _smoke_off: Dictionary = {}           # car index -> s since the smoke stopped (free after SMOKE_LIFE)


func setup(path_: TrackPath) -> void:
	path = path_
	_lamp_mat = WreckProps.lamp_material()
	_glow_mat = WreckProps.glow_material()
	_tri_mesh = WreckProps.triangle_mesh()
	_tri_mat = WreckProps.triangle_material()
	var st: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	if st != null:
		_fx = bool(st.get("fx_impact"))
		_amount = SMOKE_AMOUNT[clampi(int(st.get("quality")), 0, 2)]
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.albedo_texture = (_glow_mat.albedo_texture as GradientTexture2D)
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2(1.6, 1.6)
	_set_lit(true)


func has_kit(i: int) -> bool:
	return _kits.has(i)


func kit_count() -> int:
	return _kits.size()


## Compiles the materials at the start of the race (drawn hidden under the asphalt, see ImpactFx.warmup).
func warmup(hidden_pos: Vector3) -> void:
	var nodes: Array[Node3D] = []
	for pair in [[WreckProps.lamps_mesh(PackedVector3Array([Vector3.ZERO])), _lamp_mat],
			[WreckProps.glow_mesh(PackedVector3Array([Vector3.ZERO])), _glow_mat], [_tri_mesh, _tri_mat]]:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		mi.material_override = pair[1]
		add_child(mi)
		mi.global_position = hidden_pos
		nodes.append(mi)
	if _fx:
		var p: CPUParticles3D = _make_smoke()
		p.global_position = hidden_pos
		nodes.append(p)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		for n in nodes:
			n.queue_free())


## Blink by the visual clock (s). Call once per frame, after show_wreck().
func blink(now_s: float) -> void:
	var on: bool = SignalBlink.is_lit_at(now_s)
	if on != lit:
		_set_lit(on)


func _set_lit(on: bool) -> void:
	lit = on
	_lamp_mat.albedo_color = WreckProps.AMBER if on else WreckProps.AMBER_OFF
	_glow_mat.albedo_color = Color(WreckProps.AMBER, 1.0 if on else 0.0)


## Car `i` (drawn by `node`, model `model`) is a wreck: lamps, smoke and triangle from its crash time.
func show_wreck(i: int, node: Node3D, model: String, c: TrafficSim.Car, dt: float) -> void:
	var kit: Dictionary = _kits.get(i, {})
	if kit.is_empty():
		kit = _make_kit(node, model)
		_kits[i] = kit
	_update_smoke(i, kit, node, c, dt)
	var moved: bool = absf(c.z - float(kit["last_z"])) > 0.002 or absf(c.x - float(kit["last_x"])) > 0.0005
	kit["still_t"] = 0.0 if moved else float(kit["still_t"]) + dt    # the sim steps at 30/s: one frame is not enough
	kit["last_z"] = c.z
	kit["last_x"] = c.x
	if c.crash_t >= TRIANGLE_AFTER and float(kit["still_t"]) >= STILL_S and kit.get("tri") == null and path != null:
		kit["tri"] = _place_triangle(c)


## Car `i` is not a wreck anymore (it came back as a new car ahead): removes everything.
func clear(i: int) -> void:
	var kit: Dictionary = _kits.get(i, {})
	for k in ["lamps", "glow", "smoke", "tri"]:
		var n: Node = kit.get(k)
		if n != null and is_instance_valid(n):
			n.queue_free()
	_kits.erase(i)
	_smoke_off.erase(i)


func _make_kit(node: Node3D, model: String) -> Dictionary:
	if not _shapes.has(model):
		var pts: PackedVector3Array = WreckProps.lamp_points(WreckProps.body_aabb(node))
		_shapes[model] = [WreckProps.lamps_mesh(pts), WreckProps.glow_mesh(pts)]
	var lamps := MeshInstance3D.new()
	lamps.name = "wreck_lamps"
	lamps.mesh = _shapes[model][0]
	lamps.material_override = _lamp_mat
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lamps)
	var glow := MeshInstance3D.new()
	glow.name = "wreck_glow"
	glow.mesh = _shapes[model][1]
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	return {"lamps": lamps, "glow": glow, "smoke": null, "tri": null, "last_z": -1e9, "last_x": 0.0, "still_t": 0.0}


func _update_smoke(i: int, kit: Dictionary, node: Node3D, c: TrafficSim.Car, dt: float) -> void:
	if not _fx:
		return
	var p: CPUParticles3D = kit.get("smoke")
	var on: bool = c.crash_t < SMOKE_S
	if on and p == null:
		p = _make_smoke()
		kit["smoke"] = p
	if p == null:
		return
	if on:
		var b: float = clampf(1.0 - c.crash_t / SMOKE_S, 0.0, 1.0)      # thins out over time
		p.emitting = true
		p.color = Color(0.5, 0.5, 0.52, 0.5 + 0.4 * b)
		var hood := Vector3(0.0, 1.0, -c.length * 0.78)                 # front = -Z in the car frame
		p.global_position = node.global_transform * hood
		return
	p.emitting = false
	var off: float = float(_smoke_off.get(i, 0.0)) + dt
	_smoke_off[i] = off
	if off > SMOKE_LIFE:
		p.queue_free()
		kit["smoke"] = null
		_smoke_off.erase(i)
		kit["smoke_done"] = true


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _puff_mesh
	p.material_override = _puff_mat
	p.amount = _amount
	p.lifetime = SMOKE_LIFE
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 1.3
	p.scale_amount_max = 2.2
	p.gravity = Vector3(0.0, 0.5, 0.0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Triangle on the road behind the car (in the car's line, inside the shoulders), facing the traffic that comes.
func _place_triangle(c: TrafficSim.Car) -> Node3D:
	var z: float = Wreck.footprint(c).position.x - TRIANGLE_DIST
	var x: float = clampf(c.x, -TRIANGLE_MAX_X, TRIANGLE_MAX_X)
	var mi := MeshInstance3D.new()
	mi.name = "wreck_triangle"
	mi.mesh = _tri_mesh
	mi.material_override = _tri_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var fwd: Vector3 = path.forward_at(z)
	mi.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, -0.18), path.world_point(z, x, 0.0))
	return mi
