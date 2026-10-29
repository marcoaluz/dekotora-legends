extends SceneTree
## Prints do caminhao inteiro com as pecas da oficina (T-231: traseira, foguete, contorno do bau), sem a garagem.
## Precisa de janela (nao use --headless). Um processo so para varios prints (--batch).
## Uso (raiz do projeto):
##   godot --path game --resolution 960x600 -s res://tools_dev/shot_t231.gd -- --body=base --cab=chata
##       --parts=rb_torpedo,rocket_led,boxlight_dash_r --view=back34|back|side|front|q34|roof|roof_back|rear_low
##       [--night] [--color=id:cor] [--led=id:luz] [--neon=id:luz] [--state=id:dent|broken] --out=ABS.png
##       T-239: [--signal=-1|1|2] (seta acesa no print) [--brake] (freio apertado)
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
		"out": "", "styles": {}, "states": {}, "fov": 38.0, "signal": 0, "brake": false, "decals": []}
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
		elif a.begins_with("--signal="):
			j["signal"] = int(v)
		elif a == "--brake":
			j["brake"] = true
		elif a == "--ghost":                       # T-263: monta as pecas e as esconde (ver o que sobra da lataria)
			j["ghost"] = true
		elif a.begins_with("--out="):
			j["out"] = v
		elif a.begins_with("--decal="):            # T-234: --decal=id:lugar:cor (lugar side_l|side_r|rear|cab)
			var dd: Dictionary = DecalCatalog.make(v.get_slice(":", 0), v.get_slice(":", 1))
			if v.get_slice_count(":") > 2:
				dd["color"] = "#" + v.get_slice(":", 2)
			if v.get_slice_count(":") > 3:
				dd["size"] = float(v.get_slice(":", 3))
			(j["decals"] as Array).append(dd)
		elif a.begins_with("--state="):
			j["states"][v.get_slice(":", 0)] = v.get_slice(":", 1)
		elif a.begins_with("--color=") or a.begins_with("--led=") or a.begins_with("--neon=") or a.begins_with("--side=") or a.begins_with("--art="):
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
	if not (j["decals"] as Array).is_empty():
		t.apply_decals(j["decals"])
	t.set_mural_glow(0.5 if bool(j["night"]) else 0.0)
	for pid in j["states"]:
		t.set_part_state(String(pid), String(j["states"][pid]))
	if bool(j.get("ghost", false)):
		for n in t.find_children("acc_*", "Node3D", true, false):
			(n as Node3D).visible = false
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
		# T-234: grade e interior de perto, calota da frente, escapamento, buzina no topo da carga
		"front_close": [Vector3(-1.7, 1.9, front - 3.4), Vector3(0.0, 1.7, front + 0.2)],
		"wheel_close": [Vector3(3.4, 0.9, front + 0.6), Vector3(1.1, 0.5, front + 1.4)],
		"stack34": [Vector3(4.6, 2.8, front + 1.0), Vector3(1.2, 2.1, front + 3.3)],
		"horn34": [Vector3(-3.4, 5.4, front + 0.4), Vector3(0.0, 3.6, front + 4.0)],
		"horn_back": [Vector3(-2.4, 5.6, front + 8.5), Vector3(0.0, 3.6, front + 3.8)],
		"ref34": [Vector3(-3.4, 2.4, front - 4.4), Vector3(0.0, 1.75, front + 1.0)],
		"grille_side": [Vector3(-2.4, 1.5, front - 1.2), Vector3(0.0, 1.35, front + 0.25)],
		"visor_close": [Vector3(-2.2, 3.7, front - 2.9), Vector3(0.0, 3.0, front + 0.4)],
		"decal_side": [Vector3(-14.0, 2.6, mid), Vector3(0.0, 2.0, mid)],
		# T-263: retrovisor de perto (frente, lado, topo, de tras para ver o vao) e escada como na referencia 111-113
		"mirror_close": [Vector3(-3.1, 2.7, front - 1.7), Vector3(-1.3, 2.1, front + 0.35)],
		"mirror_front": [Vector3(-1.9, 2.3, front - 4.2), Vector3(-1.25, 2.1, front + 0.3)],
		"mirror_side": [Vector3(-4.6, 2.3, front + 0.35), Vector3(-1.2, 2.15, front + 0.35)],
		"mirror_top": [Vector3(-1.75, 5.4, front + 0.75), Vector3(-1.3, 2.2, front + 0.4)],
		"mirror_back": [Vector3(-2.7, 2.5, front + 2.2), Vector3(-1.25, 2.1, front + 0.2)],
		"ladder_ref": [Vector3(5.4, 5.3, front - 1.6), Vector3(0.2, 2.5, front + 2.6)],
		"ladder_side": [Vector3(6.5, 2.6, front + 3.0), Vector3(0.6, 2.2, front + 3.0)],
		"ladder_top": [Vector3(1.9, 7.2, front + 1.2), Vector3(0.6, 2.6, front + 3.0)],
		"ladder_front": [Vector3(0.6, 3.4, front - 7.0), Vector3(0.0, 2.6, front + 2.0)],
		# T-264: para-choque grande como nas capturas 054-062 (3/4 frente-esquerda, baixa e perto), frente, lado e topo
		"fb_ref": [Vector3(-2.15, 1.3, front - 2.25), Vector3(0.5, 0.52, front + 0.5)],
		"fb_front": [Vector3(0.0, 1.0, front - 4.6), Vector3(0.0, 0.62, front)],
		"fb_side": [Vector3(-4.2, 0.8, front + 0.6), Vector3(0.0, 0.55, front + 0.6)],
		"fb_top": [Vector3(-0.6, 3.6, front - 1.7), Vector3(0.0, 0.5, front + 0.25)],
	}
	var v: Array = views.get(String(j["view"]), views["back34"])
	# T-263: vistas do retrovisor relativas ao ponto de encaixe da esquerda (cada cabine tem a coluna num lugar)
	var sock: Node3D = t.model.find_child("SOCKET_mirror_stay_l", true, false) as Node3D if t.model != null else null
	var lsock: Node3D = t.model.find_child("SOCKET_ladder_r", true, false) as Node3D if t.model != null else null
	if String(j["view"]).begins_with("lad_") and lsock != null:      # T-263: escada de perto (ponto = pe da escada direita, na lateral da cabine)
		var q: Vector3 = lsock.global_position
		var lrel: Dictionary = {
			"lad_close": [Vector3(2.6, 1.5, -2.6), Vector3(0.0, 0.9, 0.0)],
			"lad_34": [Vector3(4.8, 3.2, -4.4), Vector3(0.0, 1.3, 0.8)],          # T-267: escada da carga com a cabine
			"lad_side": [Vector3(5.2, 1.6, 0.4), Vector3(0.0, 1.3, 0.4)],         # T-267: de lado, a quina inteira
			"lad_hi": [Vector3(1.9, 3.5, -1.9), Vector3(0.0, 1.3, 0.0)],
			"lad_gap": [Vector3(3.4, 0.9, 0.0), Vector3(0.0, 0.9, 0.0)],
			"lad_back": [Vector3(1.4, 1.0, 1.6), Vector3(0.0, 0.9, -0.1)],
		}
		if lrel.has(String(j["view"])):
			v = [q + lrel[String(j["view"])][0], q + lrel[String(j["view"])][1]]
	if String(j["view"]).begins_with("mirror_") and sock != null:
		var p: Vector3 = sock.global_position
		var rel: Dictionary = {
			"mirror_close": [Vector3(-1.8, 0.6, -2.0), Vector3(-0.05, 0.0, -0.1)],
			"mirror_front": [Vector3(-0.6, 0.2, -4.5), Vector3(0.0, 0.0, -0.1)],
			"mirror_side": [Vector3(-3.4, 0.2, 0.0), Vector3(0.0, 0.0, -0.1)],
			"mirror_top": [Vector3(-0.45, 3.2, -0.35), Vector3(-0.05, 0.0, -0.3)],
			"mirror_back": [Vector3(-1.45, 0.4, 2.1), Vector3(0.0, 0.0, -0.1)],
			"mirror_root": [Vector3(-0.9, 0.35, 1.1), Vector3(0.0, 0.0, 0.0)],
			"mirror_upper": [Vector3(-0.9, 1.6, -0.5), Vector3(0.0, 0.7, -0.1)],
		}
		if rel.has(String(j["view"])):
			var r: Array = rel[String(j["view"])]
			v = [p + r[0], p + r[1]]
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
	if _frames == 14:                         # T-239: seta (reacende agora: comeca acesa) e freio
		var tn: TruckNode = _job["truck"]
		tn.set_signal(0)
		tn.set_signal(int(_job["signal"]))
		if bool(_job["brake"]) and tn.has_method("set_brake"):
			tn.call("set_brake", true, 1.0)
	if _frames == 16:
		var img: Image = root.get_viewport().get_texture().get_image()
		if String(_job["out"]) != "":
			img.save_png(String(_job["out"]))
			print("SHOT ", _job["out"], " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					" tri=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))   # T-232: custo
		_job = {}
	return false
