extends TestCase
## T-241: in the real race scene (no window): holding "look" moves only the camera (every race camera), the mirror
## hides while looking, releasing returns to the race camera; the touch eye button feeds the look.

const IN_TREE := true


func _snapshot(sim: RaceSim) -> Array:
	var out: Array = [sim.time]
	for t in sim.trucks:
		out.append_array([t.z, t.x, t.speed, t.rpm, t.gear])
	return out


func test_look_moves_only_the_camera_in_every_mode() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.last_duel_key = ""
	gs.pending_route = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	gs.pending_contract = {}
	var race: Node = (load("res://scenes/race/race3d.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(race)
	var camv: RaceCamView = race._camv
	check(camv != null and camv.look_badge != null, "olhar montado")
	if camv == null or race.sim == null:
		race.free()
		return
	camv._save = false
	(race._intro as DuelIntro).skip()
	race._countdown = 0.0
	var sim: RaceSim = race.sim
	var before: Array = _snapshot(sim)
	var cam: Camera3D = race._cam
	var input: LocalInput = race.input
	var pz: float = race._player_z()
	var fwd: Vector3 = race.path.forward_at(pz)
	var truck_mid: Vector3 = race.path.world_point(pz + sim.trucks[race.player].length * 0.5, race._player_x(), 0.0)
	camv.rig.mode = RaceCamRig.Mode.STANDARD
	camv.mirror.set_enabled(true)
	for n in 10:
		race._update_camera(0.05)
	var normal_pos: Vector3 = cam.global_position
	check((normal_pos - truck_mid).dot(fwd) < 0.0, "camera normal atras do caminhao")
	check(camv.mirror.active(), "retrovisor ligado antes de olhar")
	# hold BACK
	input.touch_look = RaceLook.Dir.BACK
	for n in 12:
		race._update_camera(0.05)
	check((cam.global_position - truck_mid).dot(fwd) > 8.0, "olhando para tras: camera na frente da cabine")
	check((-cam.global_basis.z).dot(fwd) < -0.6, "... e virada para tras")
	check(not camv.mirror.active(), "retrovisor some enquanto olha")
	check(camv.look_badge.visible, "aviso OLHANDO PARA TRAS na tela")
	# LEFT / RIGHT
	input.touch_look = RaceLook.Dir.LEFT
	for n in 12:
		race._update_camera(0.05)
	var right_v: Vector3 = race.path.right_at(pz)
	check((-cam.global_basis.z).dot(right_v) < -0.5, "esquerda: olha para a esquerda")
	input.touch_look = RaceLook.Dir.RIGHT
	for n in 12:
		race._update_camera(0.05)
	check((-cam.global_basis.z).dot(right_v) > 0.5, "direita: olha para a direita")
	# release
	input.touch_look = RaceLook.Dir.NONE
	for n in 12:
		race._update_camera(0.05)
	check(not camv.look.looking(), "soltou: parou de olhar")
	check(cam.global_position.distance_to(normal_pos) < 3.0, "voltou para a camera normal (%.1f m)" % cam.global_position.distance_to(normal_pos))
	check(camv.mirror.active(), "retrovisor volta")
	check(not camv.look_badge.visible, "aviso some")
	# every race camera: valid pose while looking and after
	var bad: int = 0
	for m in RaceCamRig.IDS.size():
		camv.rig.mode = m
		for d in [RaceLook.Dir.BACK, RaceLook.Dir.LEFT, RaceLook.Dir.NONE]:
			input.touch_look = d
			for n in 8:
				race._update_camera(0.05)
				if not (cam.global_position.is_finite() and cam.fov > 5.0 and cam.fov < 100.0):
					bad += 1
		if camv.look.looking():
			bad += 1
	check_eq(bad, 0, "todas as cameras: pose valida olhando e depois de soltar")
	check_eq(_snapshot(sim), before, "olhar nao muda a simulacao")
	race.free()
	gs.last_duel_key = ""
	gs.pending_route = null
	gs.new_profile()


func _touch(tc: TouchControls, idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	tc._input(e)


func _drag(tc: TouchControls, idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	tc._input(e)


func test_touch_eye_button_hold_and_slide() -> void:
	var tc := TouchControls.new()
	var input := LocalInput.new()
	tc.target = input
	Engine.get_main_loop().root.add_child(tc)
	var b: Dictionary = tc._buttons
	var c: Vector2 = b["look"]["center"]
	var r: float = float(b["look"]["radius"])
	_touch(tc, 0, c, true)
	check_eq(input.touch_look, RaceLook.Dir.BACK, "segurar o olho = tras")
	check_eq(input.look_dir(), RaceLook.Dir.BACK, "LocalInput entrega o olhar")
	_drag(tc, 0, c + Vector2(r * 1.2, 0))
	check_eq(input.touch_look, RaceLook.Dir.RIGHT, "deslizar para a direita")
	_drag(tc, 0, c - Vector2(r * 1.2, 0))
	check_eq(input.touch_look, RaceLook.Dir.LEFT, "deslizar para a esquerda")
	_drag(tc, 0, b["right"]["center"])             # the slide crosses the right arrow: still the eye, no lane change
	check_eq(input.touch_steer, 0.0, "o dedo do olho nunca vira seta")
	_drag(tc, 0, c)
	check_eq(input.touch_look, RaceLook.Dir.BACK, "de volta ao centro = tras")
	# another finger on the throttle at the same time
	_touch(tc, 1, b["throttle"]["center"], true)
	check_eq(input.touch_throttle, 1.0, "acelera junto")
	check_eq(input.touch_look, RaceLook.Dir.BACK, "e continua olhando")
	_touch(tc, 0, c, false)
	check_eq(input.touch_look, RaceLook.Dir.NONE, "soltou = volta")
	check_eq(input.touch_throttle, 1.0, "o acelerador nao solta junto")
	# a finger that slides INTO the eye button from an arrow does not start a look
	_touch(tc, 2, b["right"]["center"], true)
	_drag(tc, 2, c)
	check_eq(input.touch_look, RaceLook.Dir.NONE, "entrar deslizando no olho nao olha")
	_touch(tc, 2, c, false)
	_touch(tc, 1, b["throttle"]["center"], false)
	tc.free()
