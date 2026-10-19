extends SceneTree
## Depuracao (T-141/T-144): efeitos na frente de uma camera, grava PNG. Rodar COM janela:
##   godot --path game -s res://tools_dev/fx_probe.gd -- --out=C:/pasta/fx.png [--brake]
## Sem --brake: batida de frente (faiscas, clarao, pedacos). Com --brake: caminhao andando e freando forte
## (fumaca dos pneus e marcas), camera atras e acima como na corrida.


func _initialize() -> void:
	var out: String = "user://fx_probe.png"
	var brake: bool = "--brake" in OS.get_cmdline_user_args()
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
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 400)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.2, 0.2)
	floor_.material_override = fm
	root.add_child(floor_)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-50, 30, 0)
	var truck := TruckNode.new()
	root.add_child(truck)
	if brake:
		var bfx := BrakeFx.new()
		root.add_child(bfx)
		var t := TruckSim.new()
		t.hard_braking = true
		t.brake_intensity = 0.7
		t.speed = 25.0
		var z: float = 100.0
		for k in 50:                      # 50 quadros a 60/s andando para -Z
			z -= 25.0 / 60.0
			truck.position = Vector3(0, 0, z)
			cam.position = truck.position + Vector3(0, 6.0, 15.0)
			cam.look_at(truck.position + Vector3(0, 1.5, -14.0))
			bfx.update_truck(0, truck, t, cam.global_position, 1.0 / 60.0, true)
			await process_frame
	else:
		cam.position = Vector3(0, 2, 7)
		cam.look_at(Vector3(0, 1, 0))
		var fx := Fx3D.new()
		root.add_child(fx)
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
