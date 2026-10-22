extends "res://tools_dev/model_sheet_t186.gd"
## T-193: one picture of each model imported from the new folders of docs/Modelos, with the game's materials
## (trains through RailKit, buildings through CityModels, cars with the traffic paint), daylight, 1.7 m post for scale.
## Usage (needs a window): godot --path game --resolution 640x480 -s res://tools_dev/model_sheet_t193.gd -- --out=ABS_FOLDER
## then join with make_compare_sheet.gd.

const T193: Array[String] = ["train_loco_b", "train_wagon_log", "train_wagon_flat", "train_wagon_semi", "train_wagon_box",
	"train_wagon_box_b", "car_lp_coupe", "car_lp_hatch", "car_skyline", "bldg_small", "bldg_med01", "bldg_med02", "bldg_big01",
	"bldg_bigwide01", "bldg_bigwide02", "bldg_sky01", "bldg_sky02", "city_skyline"]


func _init() -> void:
	super._init()
	var only: bool = false
	for a in OS.get_cmdline_user_args():
		only = only or a.begins_with("--only=")
	if not only:
		MODELS.assign(T193)


func _show(name: String) -> void:
	if _holder != null:
		_holder.queue_free()
	_holder = Node3D.new()
	root.add_child(_holder)
	var tod: TimeOfDay = TimeOfDay.by_id(&"day")
	var size := Vector3.ONE
	if name.begins_with("train_"):
		var m: ArrayMesh = RailKit.mesh(name, tod)
		_mesh(m, Vector3.ZERO)
		size = m.get_aabb().size
		_holder.rotation_degrees.y = 60.0
	elif name.begins_with("car_"):
		var n: Node3D = (load("res://assets/vehicles/traffic/%s.glb" % name) as PackedScene).instantiate() as Node3D
		n.position = Vector3(0, 0, 2.3)
		_holder.add_child(n)
		_holder.rotation_degrees.y = 35.0
		size = Vector3(4.6, 1.5, 4.6)
	else:
		var src: ArrayMesh = GlbMesh.merged("res://assets/scenery/city/%s.glb" % name)
		var tex: String = CityModels.SKYLINE_TEX if name == "city_skyline" else CityModels.ATLAS
		var mat: ShaderMaterial = CityModels.material(tex, tod)
		var m := ArrayMesh.new()
		for s in src.get_surface_count():
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
			m.surface_set_material(s, mat)
		_mesh(m, Vector3.ZERO)
		size = m.get_aabb().size
		_holder.rotation_degrees.y = 30.0
	_post(Vector3(-maxf(size.x, size.z) * 0.6 - 0.6, 0, 1.0))
	_frame(size.y, maxf(size.x, size.z))
