extends Node3D
## Ferramenta (V6): mostra um caminhao com o cromo por matcap (ou o PBR antigo com --pbr), na noite da
## corrida. Abrir: godot --path game res://scenes/tools/chrome_compare.tscn  [-- --time=day --pbr]

func _ready() -> void:
	var tid: StringName = &"night"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--time="):
			tid = StringName(a.substr(7))
	var tod: TimeOfDay = TimeOfDay.by_id(tid)
	WorldEnv.create(self, false, tod)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#2a2a30")
	fm.roughness = 0.6
	floor_mi.material_override = fm
	add_child(floor_mi)
	for k in 1:
		var t := TruckNode.new()
		t.body_kind = "leve"
		var matcap: bool = not ("--pbr" in OS.get_cmdline_user_args())
		t.chrome_mode = ("day" if tod.day_amount > 0.5 else "night") if matcap else ""
		t.position = Vector3.ZERO
		add_child(t)
		var defs: Array[PartDef] = []
		var gs: Node = get_node("/root/GameState")
		for pid in ["fb_basic", "rb_chrome", "grille_frame_chrome", "hub_chrome", "aux_round_lamps_pair"]:
			var d: PartDef = gs.part(pid)
			if d != null:
				defs.append(d)
		t.apply_loadout(defs)
		var lamp := OmniLight3D.new()                      # um poste de sodio por perto
		lamp.light_color = Color(1.0, 0.62, 0.3)
		lamp.light_energy = 2.0
		lamp.omni_range = 14.0
		lamp.position = t.position + Vector3(0, 7, -14)
		add_child(lamp)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(4.0, 2.2, -14.5)
	cam.look_at(Vector3(0, 1.2, -8.5), Vector3.UP)
	var l := Label.new()
	l.text = "cromo PBR antigo" if "--pbr" in OS.get_cmdline_user_args() else "cromo matcap (V6)"
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 22)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(l)
