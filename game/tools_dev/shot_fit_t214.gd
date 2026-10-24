extends SceneTree
## Prints de perto do encaixe do deque e da viseira (T-214/T-215), sem a garagem: um caminhao, as pecas pedidas e uma
## camera mirando o teto da cabine. Precisa de janela (nao use --headless).
## Uso (raiz do projeto):
##   godot --path game --resolution 960x600 -s res://tools_dev/shot_fit_t214.gd -- --body=base --cab=americana
##       --parts=deck_pods_round,deck_led_box,visor_v_chevron --top=deck_led_box --view=side|q34|front|back
##       [--color=id:cor] [--led=id:luz] [--neon=id:luz] [--night] --out=ABS.png

var _frames: int = 0
var _out: String = ""
var _t: TruckNode
var _parts: PackedStringArray = []
var _styles: Dictionary = {}
var _night: bool = false
var _view: String = "q34"


func _initialize() -> void:
	var body: String = "base"
	var cab: String = "chata"
	var parts: PackedStringArray = []
	var top: String = ""
	var night: bool = false
	var styles: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--body="):
			body = v
		elif a.begins_with("--cab="):
			cab = v
		elif a.begins_with("--parts="):
			parts = v.split(",")
		elif a.begins_with("--top="):
			top = v
		elif a.begins_with("--view="):
			_view = v
		elif a == "--night":
			night = true
		elif a.begins_with("--out="):
			_out = v
		elif a.begins_with("--color=") or a.begins_with("--led=") or a.begins_with("--neon="):
			var key: String = a.substr(2, a.find("=") - 2)
			var pid: String = v.get_slice(":", 0)
			if not styles.has(pid):
				styles[pid] = {}
			styles[pid][key] = v.get_slice(":", 1)
	if top != "":
		if not styles.has(top):
			styles[top] = {}
		styles[top]["top"] = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.1) if night else Color(0.55, 0.62, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.27, 0.35) if night else Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.5 if night else 1.0
	e.glow_enabled = night
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.25 if night else 1.2
	world.add_child(sun)
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = cab
	t.chrome_mode = "night" if night else "day"
	world.add_child(t)
	_t = t
	_parts = parts
	_styles = styles
	_night = night


func _mount() -> void:
	var t: TruckNode = _t
	var parts: PackedStringArray = _parts
	var styles: Dictionary = _styles
	var night: bool = _night
	var gs: Node = root.get_node("GameState")
	var defs: Array[PartDef] = []
	for id in parts:
		var d: PartDef = gs.part(id)
		if d != null:
			defs.append(d)
	t.apply_loadout(defs, styles)
	t.set_lights_on(night, not night)
	var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(t.body_kind, t.cab_kind))
	var a: Array = TruckSockets.socket(data, "andon").get("anchor", [0, 3, -9])
	var target := Vector3(0.0, float(a[1]) + 0.2, float(a[2]) - 0.6)
	var cam := Camera3D.new()
	cam.fov = 38.0
	var offs: Dictionary = {"side": Vector3(5.5, 0.4, 0.0), "q34": Vector3(3.6, 1.6, -4.2), "front": Vector3(0.0, 0.6, -6.0),
		"back": Vector3(-3.0, 1.8, 4.5)}
	t.get_parent().add_child(cam)
	cam.look_at_from_position(target + offs.get(_view, offs["q34"]), target)
	cam.current = true


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 2:
		_mount()
	if _frames == 14:
		var img: Image = root.get_viewport().get_texture().get_image()
		if _out != "":
			img.save_png(_out)
			print("SHOT ", _out)
		return true
	return false
