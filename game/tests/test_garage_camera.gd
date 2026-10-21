extends TestCase
## Garagem: a camera nunca gira sozinha. So arrasto (com inercia curta), pinca/roda dao zoom, abas movem ao angulo da vista.

const IN_TREE := true


func _stage() -> GarageStage:
	Engine.get_main_loop().root.get_node("GameState").new_profile()
	var stage := GarageStage.new()
	Engine.get_main_loop().root.add_child(stage)
	return stage


func _run(stage: GarageStage, seconds: float) -> void:
	for i in int(seconds * 60.0):
		stage._process(1.0 / 60.0)


func _drag(stage: GarageStage, rel: Vector2, vel: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	stage._unhandled_input(press)
	var mv := InputEventMouseMotion.new()
	mv.relative = rel
	mv.velocity = vel
	stage._unhandled_input(mv)
	var rel_ev := InputEventMouseButton.new()
	rel_ev.button_index = MOUSE_BUTTON_LEFT
	rel_ev.pressed = false
	stage._unhandled_input(rel_ev)


func test_idle_camera_does_not_move() -> void:
	var stage := _stage()
	for v in ["default", "front", "hero"]:
		if v == "hero":
			stage.focus_hero()
		else:
			stage.focus_view(v)
		_run(stage, 5.0)        # chega ao angulo da vista
		var p: Vector3 = stage.cam.global_position
		_run(stage, 10.0)       # parada por 10 s sem tocar
		check(stage.cam.global_position.distance_to(p) < 0.001, "%s: camera parada nao se mexe em 10 s" % v)
	stage.queue_free()


func test_drag_has_short_inertia_then_stops() -> void:
	var stage := _stage()
	stage.focus_default()
	_run(stage, 5.0)
	var az0: float = stage._az
	_drag(stage, Vector2(20, 0), Vector2(600, 0))
	var az1: float = stage._az
	check(not is_equal_approx(az0, az1), "arrastar gira")
	_run(stage, 0.05)
	check(absf(stage._az_vel) > 1.0, "inercia ainda ativa logo apos soltar")
	_run(stage, 2.0)
	check_eq(stage._az_vel, 0.0, "inercia acabou")
	var az2: float = stage._az
	_run(stage, 10.0)
	check_near(stage._az, az2, 0.0001, "depois da inercia nao volta nem gira")
	stage.queue_free()


func test_zoom_wheel_and_pinch_clamped() -> void:
	var stage := _stage()
	for i in 40:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP
		w.pressed = true
		stage._unhandled_input(w)
	check_near(stage._zoom_goal, GarageStage.ZOOM_MIN, 0.0001, "roda: limite perto")
	for i in 2:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = true
		t.position = Vector2(100 + i * 100, 100)
		stage._unhandled_input(t)
	for step in 40:
		for i in 2:
			var d := InputEventScreenDrag.new()
			d.index = i
			d.position = Vector2(100 + i * (100 - step * 2.0 - 2.0 + 100.0 * 0.0) + (0 if i == 0 else 0), 100)
			stage._unhandled_input(d)
	check(stage._zoom_goal <= GarageStage.ZOOM_MAX and stage._zoom_goal >= GarageStage.ZOOM_MIN, "pinca dentro dos limites")
	stage.queue_free()
