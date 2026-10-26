extends SceneTree
## Prints do caminhao inteiro com as pecas da oficina (T-231: traseira, foguete, contorno do bau), sem a garagem.
## Precisa de janela (nao use --headless). Um processo so para varios prints (--batch).
## Uso (raiz do projeto):
##   godot --path game --resolution 960x600 -s res://tools_dev/shot_t231.gd -- --body=base --cab=chata
##       --parts=rb_torpedo,rocket_led,boxlight_dash_r --view=back34|back|side|front|q34|roof|roof_back|rear_low
##       [--night] [--color=id:cor] [--led=id:luz] [--neon=id:luz] [--state=id:dent|broken] --out=ABS.png
##   ou --batch=ABS.txt (uma linha por print, mesmos argumentos separados por espaco).

var _jobs: Array = []
var _frames: int = 0
var _world: Node3D
var _job: Dictionary = {}


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--batch="):
			for line in FileAccess.get_file_as_string(a.get_slice("=", 1)).split("\n"):
				if line.strip_edges() != "" and not line.begins_with("#"):
					_jobs.append(_parse(line.strip_edges().split(" ", false)))
	if _jobs.is_empty():
		_jobs.append(_parse(args))


static func _parse(args: PackedStringArray) -> Dictionary:
	var j: Dictionary = {"body": "base", "cab": "chata", "parts": PackedStringArray(), "view": "back34", "night": false,
		"out": "", "styles": {}, "states": {}, "fov": 38.0}
	for a in args:
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--body="):
			j["body"] = v
		elif a.begins_with("--cab="):
			j["cab"] = v
		elif a.begins_with("--parts="):
			j["parts"] = v.split(",", false)
		elif a.begins_with("--view="):
			j["view"] = v
		elif a.begins_with("--fov="):
			j["fov"] = float(v)
		elif a == "--night":
			j["night"] = true
		elif a.begins_with("--out="):
			j["out"] = v
		elif a.begins_with("--state="):
			j["states"][v.get_slice(":", 0)] = v.get_slice(":", 1)
		elif a.begins_with("--color=") or a.begins_with("--led=") or a.begins_with("--neon="):
			var key: String = a.substr(2, a.find("=") - 2)
			var pid: String = v.get_slice(":", 0)
			if not j["styles"].has(pid):
				j["styles"][pid] = {}
			j["styles"][pid][key] = v.get_slice(":", 1)
	return j


func _build(j: Dictionary) -> void:
	if _world != null:
		_world.queue_free()
	_world = Node3D.new()
	root.add_child(_world)
	var night: bool = bool(j["night"])
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.05, 0.09) if night else Color(0.55, 0.62, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.27, 0.35) if night else Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.45 if night else 1.0
	e.glow_enabled = night
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.2 if night else 1.2
	_world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.13, 0.15) if night else Color(0.42, 0.42, 0.44)
	floor_mi.material_override = fm
	floor_mi.position = Vector3(0, -0.005, -6)
	_world.add_child(floor_mi)
	var t := TruckNode.new()
	t.body_kind = String(j["body"])
	t.cab_kind = String(j["cab"])
	t.chrome_mode = "night" if night else "day"
	_world.add_child(t)
	j["truck"] = t


func _mount(j: Dictionary) -> void:
	var t: TruckNode = j["truck"]
	var gs: Node = root.get_node("GameState")
	var defs: Array[PartDef] = []
	for id in j["parts"]:
		var d: PartDef = gs.part(id)
		if d != null:
			defs.append(d)
		else:
			push_warning("shot_t231: peca desconhecida " + String(id))
	t.apply_loadout(defs, j["styles"])
	t.set_lights_on(bool(j["night"]), not bool(j["night"]))
	t.set_mural_glow(0.5 if bool(j["night"]) else 0.0)
	for pid in j["states"]:
		t.set_part_state(String(pid), String(j["states"][pid]))
	var front: float = -11.5 - t.front_delta()
	var mid: float = front * 0.5
	var cam := Camera3D.new()
	cam.fov = float(j["fov"])
	var views: Dictionary = {
		"back34": [Vector3(-3.4, 1.5, 5.6), Vector3(0.0, 1.0, 0.0)],
		"back": [Vector3(0.0, 1.7, 7.5), Vector3(0.0, 1.5, 0.0)],
		"rear_low": [Vector3(-1.2, 0.9, 3.6), Vector3(0.0, 0.75, 0.0)],
		"side": [Vector3(17.0, 2.4, mid), Vector3(0.0, 1.8, mid)],
		"side_l": [Vector3(-17.0, 2.4, mid), Vector3(0.0, 1.8, mid)],
		"front": [Vector3(0.0, 2.2, front - 9.0), Vector3(0.0, 1.8, front)],
		"q34": [Vector3(9.0, 4.0, front - 5.5), Vector3(0.0, 1.8, mid * 0.8)],
		"q34_back": [Vector3(-8.5, 5.0, 6.0), Vector3(0.0, 2.0, mid * 0.6)],
		"roof_back": [Vector3(-3.0, 6.2, 5.5), Vector3(0.0, 3.0, mid * 0.5)],
		"roof": [Vector3(0.01, 16.0, mid + 0.01), Vector3(0.0, 3.0, mid)],
		"roof_corner": [Vector3(-2.6, 4.6, 1.8), Vector3(-1.0, 3.2, -0.6)],
		"roof_front": [Vector3(-2.8, 4.8, front + 1.2), Vector3(-0.8, 3.2, front + 3.6)],
		# T-233: frente (para-choque, retrovisor), escada e saia
		"front34": [Vector3(-4.6, 1.5, front - 5.2), Vector3(0.0, 1.1, front + 0.9)],
		"front_low": [Vector3(0.0, 1.3, front - 6.5), Vector3(0.0, 1.05, front)],
		"cab34": [Vector3(-6.0, 3.4, front - 4.6), Vector3(0.0, 2.0, front + 1.6)],
		"ladder34": [Vector3(-5.2, 3.6, front - 2.4), Vector3(-1.2, 2.0, front + 3.6)],
		"skirt": [Vector3(-9.5, 1.3, mid + 1.0), Vector3(0.0, 0.8, mid + 1.0)],
		"skirt34": [Vector3(-6.5, 1.6, front + 0.5), Vector3(-1.0, 0.7, mid + 1.5)],
		"skirt_close": [Vector3(3.6, 0.9, mid - 0.5), Vector3(1.2, 0.5, mid + 0.6)],
		"skirt_top": [Vector3(3.2, 3.0, mid + 0.6), Vector3(1.2, 0.5, mid + 0.6)],
	}
	var v: Array = views.get(String(j["view"]), views["back34"])
	_world.add_child(cam)
	cam.look_at_from_position(v[0], v[1])
	cam.current = true


func _process(_dt: float) -> bool:
	if _job.is_empty():
		if _jobs.is_empty():
			return true
		_job = _jobs.pop_front()
		_build(_job)
		_frames = 0
		return false
	_frames += 1
	if _frames == 2:
		_mount(_job)
	if _frames == 16:
		var img: Image = root.get_viewport().get_texture().get_image()
		if String(_job["out"]) != "":
			img.save_png(String(_job["out"]))
			print("SHOT ", _job["out"], " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					" tri=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))   # T-232: custo
		_job = {}
	return false
