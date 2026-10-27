extends SceneTree
## Sonda da T-246: abre a corrida (mesmos argumentos da captura) e lista toda GeometryInstance3D visivel cuja caixa
## cruza a regiao do para-brisa do caminhao do jogador (em metros do caminhao: frente = -Z).
## Uso: godot --path game -s res://tools_dev/probe_t246.gd -- <args da corrida> [--frames=240]

var _frames: int = 0
var _wait: int = 240
var _hide: PackedStringArray = PackedStringArray()
var _shot: String = ""
var _done: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_wait = int(a.get_slice("=", 1))
		elif a.begins_with("--hide="):
			_hide = a.get_slice("=", 1).split(",")
		elif a.begins_with("--probe-shot="):
			_shot = a.get_slice("=", 1)
	change_scene_to_file("res://scenes/race/race3d.tscn")


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	if _done:
		if _frames >= _wait + 4:
			if _shot != "":
				root.get_viewport().get_texture().get_image().save_png(_shot)
			quit(0)
			return true
		return false
	var scene: Node = current_scene
	var trucks: Array = scene.get("_trucks")
	var player: int = int(scene.get("player")) if scene.get("player") != null else 0
	var truck: Node3D = trucks[player]
	print("systems=", scene.get("sim").trucks[player].systems)
	print("player=", player, " truck=", truck.name, " body=", truck.get("body_kind"), " cab=", truck.get("cab_kind"))
	var box := AABB(Vector3(-1.4, 1.2, -16.0), Vector3(2.8, 2.2, 8.8))
	var inv: Transform3D = truck.global_transform.affine_inverse()
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var b: AABB = inv * g.global_transform * g.get_aabb()
		if not b.intersects(box) or b.size.length() > 40.0:
			continue
		var mat: String = ""
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var m: Mesh = (g as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var mm: Material = (g as MeshInstance3D).get_active_material(s)
				mat += (mm.resource_name if mm != null else "null") + ","
			mat += " mesh=" + m.resource_name + " " + m.get_class()
		print(g.get_class(), " ", scene.get_path_to(g), " pos=", b.position.snapped(Vector3.ONE * 0.01), " size=",
				b.size.snapped(Vector3.ONE * 0.01), " mats=", mat)
		for h in _hide:
			if h != "" and String(g.name).contains(h):
				g.visible = false
				print("  -> escondido")
		if g is CPUParticles3D:
			var cp: CPUParticles3D = g as CPUParticles3D
			print("  emitting=", cp.emitting, " amount=", cp.amount, " mesh=", cp.mesh, " mat=", cp.material_override)
	var pt := Vector2(960, 830)
	for n in scene.find_children("*", "CanvasItem", true, false):
		var ci: CanvasItem = n as CanvasItem
		if ci is Control and ci.is_visible_in_tree():
			var r: Rect2 = (ci as Control).get_global_rect()
			var xf: Transform2D = ci.get_global_transform_with_canvas()
			var sr := xf * Rect2(Vector2.ZERO, (ci as Control).size)
			if sr.has_point(pt):
				print("CONTROL ", scene.get_path_to(ci), " ", ci.get_class(), " rect=", sr)
				for h in _hide:
					if h != "" and String(ci.name).contains(h):
						ci.visible = false
						print("  -> escondido")
	_done = true
	return false
