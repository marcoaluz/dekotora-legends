extends SceneTree
## Prints de perto do encaixe do deque e da viseira (T-214/T-215), sem a garagem: um caminhao, as pecas pedidas e uma
## camera mirando o teto da cabine. Precisa de janela (nao use --headless).
## Uso (raiz do projeto):
##   godot --path game --resolution 960x600 -s res://tools_dev/shot_fit_t214.gd -- --body=base --cab=americana
##       --parts=deck_pods_round,deck_led_box,visor_v_chevron --top=deck_led_box --view=side|q34|front|back
##       [--color=id:cor] [--led=id:luz] [--neon=id:luz] [--night] --out=ABS.png
##   ou --batch=ABS.txt (uma linha por print, com os mesmos argumentos separados por espaco): um processo so.

var _jobs: Array = []
var _frames: int = 0
var _world: Node3D
var _job: Dictionary = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--batch="):
			for line in FileAccess.get_file_as_string(a.get_slice("=", 1)).split("\n"):
				if line.strip_edges() != "" and not line.begins_with("#"):
					_jobs.append(_parse(line.strip_edges().split(" ", false)))
	if _jobs.is_empty():
		_jobs.append(_parse(args))


static func _parse(args: PackedStringArray) -> Dictionary:
	var j: Dictionary = {"body": "base", "cab": "chata", "parts": PackedStringArray(), "top": "", "view": "q34",
		"night": false, "out": "", "styles": {}}
	for a in args:
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--body="):
			j["body"] = v
		elif a.begins_with("--cab="):
			j["cab"] = v
		elif a.begins_with("--parts="):
			j["parts"] = v.split(",")
		elif a.begins_with("--top="):
			j["top"] = v
		elif a.begins_with("--view="):
			j["view"] = v
		elif a == "--night":
			j["night"] = true
		elif a.begins_with("--out="):
			j["out"] = v
		elif a.begins_with("--color=") or a.begins_with("--led=") or a.begins_with("--neon="):
			var key: String = a.substr(2, a.find("=") - 2)
			var pid: String = v.get_slice(":", 0)
			if not j["styles"].has(pid):
				j["styles"][pid] = {}
			j["styles"][pid][key] = v.get_slice(":", 1)
	if j["top"] != "":
		if not j["styles"].has(j["top"]):
			j["styles"][j["top"]] = {}
		j["styles"][j["top"]]["top"] = true
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
	e.background_color = Color(0.05, 0.06, 0.1) if night else Color(0.55, 0.62, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.27, 0.35) if night else Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.5 if night else 1.0
	e.glow_enabled = night
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.25 if night else 1.2
	_world.add_child(sun)
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
	t.apply_loadout(defs, j["styles"])
	t.set_lights_on(bool(j["night"]), not bool(j["night"]))
	var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(t.body_kind, t.cab_kind))
	var a: Array = TruckSockets.socket(data, "andon").get("anchor", [0, 3, -9])
	var target := Vector3(0.0, float(a[1]) + 0.2, float(a[2]) - 0.6)
	var cam := Camera3D.new()
	cam.fov = 38.0
	var offs: Dictionary = {"side": Vector3(5.5, 0.4, 0.0), "q34": Vector3(3.6, 1.6, -4.2), "front": Vector3(0.0, 0.6, -6.0),
		"back": Vector3(-3.0, 1.8, 4.5)}
	_world.add_child(cam)
	cam.look_at_from_position(target + offs.get(String(j["view"]), offs["q34"]), target)
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
	if _frames == 14:
		var img: Image = root.get_viewport().get_texture().get_image()
		if String(_job["out"]) != "":
			img.save_png(String(_job["out"]))
			print("SHOT ", _job["out"])
		_job = {}
	return false
