extends SceneTree
## T-186: one picture of each model of the scenery library WITH the game's materials (trees through BackdropKit,
## people through PeopleKit), LOD0 and LOD1 side by side, daylight, a 1.7 m grey post for scale. Needs a window.
## Usage: godot --path game --resolution 640x480 -s res://tools_dev/model_sheet_t186.gd -- --out=ABS_FOLDER
## Writes ABS_FOLDER/<model>.png; then join them with make_compare_sheet.gd.

const ALL: Array[String] = ["tree_leafy", "tree_leafy_b", "tree_leafy_c", "tree_leafy_d", "tree_leafy_e",
	"tree_leafy_f", "palm", "palm_tall", "palm_bent", "tree_pine", "tree_cedar", "tree_round", "bush", "lamp_post",
	"lamp_bridge", "person"]

var MODELS: Array[String] = ALL.duplicate()

var out: String = ""
var _i: int = -1
var _wait: int = 0
var _holder: Node3D
var _cam: Camera3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			MODELS.assign(a.substr(7).split(","))
	if out == "":
		push_error("uso: -- --out=PASTA_ABSOLUTA")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.7, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child.call_deferred(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	root.add_child.call_deferred(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	root.add_child.call_deferred(_cam)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.5, 0.4)
	ground.material_override = gm
	root.add_child.call_deferred(ground)


func _process(_dt: float) -> bool:
	if out == "":
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_png(out.path_join(MODELS[_i] + ".png"))
			print("FOTO ", MODELS[_i])
		return false
	_i += 1
	if _i >= MODELS.size():
		return true
	_show(MODELS[_i])
	_wait = 8
	return false


func _show(name: String) -> void:
	if _holder != null:
		_holder.queue_free()
	_holder = Node3D.new()
	root.add_child(_holder)
	var tod: TimeOfDay = TimeOfDay.by_id(&"day")
	var near: Mesh
	var far: Mesh
	if name.begins_with("tree_leafy"):
		near = BackdropKit.tree_mesh_of(name, tod)
		far = BackdropKit.tree_mesh_of(name + "_lod1", tod)
	elif name == "person":
		_people()
		return
	else:
		near = GlbMesh.merged("res://assets/scenery/%s.glb" % name)
		var p1: String = "res://assets/scenery/%s_lod1.glb" % name
		far = GlbMesh.merged(p1) if ResourceLoader.exists(p1) else null
	var aabb: AABB = near.get_aabb()
	var w: float = maxf(aabb.size.x, aabb.size.z)
	var dx: float = (w * 0.65 + 0.8) if far != null else 0.0
	_mesh(near, Vector3(-dx, 0, 0))
	if far != null:
		_mesh(far, Vector3(dx, 0, 0))
	_post(Vector3(-dx - w * 0.6 - 0.6, 0, 1.0))
	_frame(aabb.size.y, dx * 2.0 + w)


func _people() -> void:
	var xs: Array = []
	var looks: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 5:
		xs.append(PeopleKit.stand(Vector3(-2.4 + k * 1.2, 0, 0), Vector3(0.3 * (k - 2), 0, 1), 1.0))
		looks.append(PeopleKit.look(rng))
	_holder.add_child(PeopleKit.group(xs, looks, TimeOfDay.by_id(&"day")))
	_post(Vector3(-3.6, 0, 0.6))
	_frame(1.8, 7.0)


func _mesh(m: Mesh, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	_holder.add_child(mi)


func _post(at: Vector3) -> void:            # 1.7 m scale post
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 1.7, 0.2)
	mi.mesh = bm
	mi.position = at + Vector3(0, 0.85, 0)
	_holder.add_child(mi)


func _frame(h: float, w: float) -> void:
	var size: float = maxf(h, w * 0.75)
	var d: float = size * 0.5 / tan(deg_to_rad(_cam.fov * 0.5)) * 1.15
	var tgt := Vector3(0, h * 0.5, 0)
	_cam.position = tgt + Vector3(0, size * 0.12, d)
	_cam.look_at(tgt, Vector3.UP)
