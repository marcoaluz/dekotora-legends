extends SceneTree
## Depuracao (T-141): faiscas e pedacos de batida na frente de uma camera, grava PNG. Rodar COM janela:
##   godot --path game -s res://tools_dev/fx_probe.gd -- --out=C:/pasta/fx.png


func _initialize() -> void:
	var out: String = "user://fx_probe.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	await process_frame
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.15)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 2, 7)
	cam.look_at(Vector3(0, 1, 0))
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_.mesh = pm
	root.add_child(floor_)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-50, 30, 0)
	var fx := Fx3D.new()
	root.add_child(fx)
	var truck := TruckNode.new()
	root.add_child(truck)
	truck.position = Vector3(0, 0, -14)
	truck.rotation.y = PI                     # frente (-Z local) virada para a camera
	var imp := ImpactFx.new()
	root.add_child(imp)
	var tn: Array[TruckNode] = [truck]
	imp.setup(fx, tn, [12.0] as Array[float], null)
	await create_timer(0.5).timeout
	imp.on_event({"type": "traffic", "truck": 0, "zone": "front", "force": 15.0, "thrown": true}, 0)
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("FX_PROBE: ", out)
	quit()
