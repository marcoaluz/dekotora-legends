extends TestCase
## T-241: look back / left / right (RaceLook): inputs, hold and release, smooth move, poses inside the road,
## touch eye button layout. Pure (no race scene).


func _rig() -> RaceCamRig:
	var track: Track = Track.make_test_track()
	return RaceCamRig.new(TrackPath.new(track), track.events, [] as Array[Vector2])


## World target of a direction (like RaceCamView.apply_look).
func _target(rig: RaceCamRig, dir: int, me: Vector3) -> Array:
	if dir == RaceLook.Dir.NONE:
		return []
	var lp: Array[Vector3] = RaceLook.local_pose(dir, me)
	return [rig.to_world(rig.clamp_point(lp[0], me)), rig.to_world(lp[1])]


func test_keys_and_sticks_pick_the_direction() -> void:
	check_eq(RaceLook.resolve(0.0, 0.0, 0.0), RaceLook.Dir.NONE, "nada apertado")
	check_eq(RaceLook.resolve(0.0, 1.0, 0.0), RaceLook.Dir.LEFT, "Q = esquerda")
	check_eq(RaceLook.resolve(0.0, 0.0, 1.0), RaceLook.Dir.RIGHT, "E = direita")
	check_eq(RaceLook.resolve(1.0, 0.0, 0.0), RaceLook.Dir.BACK, "X = tras")
	check_eq(RaceLook.resolve(0.0, 1.0, 1.0), RaceLook.Dir.BACK, "Q+E juntos = tras")
	check_eq(RaceLook.resolve(0.0, 0.3, 0.0), RaceLook.Dir.NONE, "analogico de leve nao olha")
	check_eq(RaceLook.resolve(0.9, 0.6, 0.0), RaceLook.Dir.BACK, "analogico mais para baixo = tras")
	check_eq(RaceLook.resolve(0.6, 0.9, 0.0), RaceLook.Dir.LEFT, "analogico mais para o lado = lado")
	check_eq(RaceLook.dir_from_id("left"), RaceLook.Dir.LEFT, "id")
	check_eq(RaceLook.dir_from_id("xyz"), RaceLook.Dir.NONE, "id desconhecido = nao olha")


func test_touch_slide_picks_side_with_hysteresis() -> void:
	var r: float = 20.0
	check_eq(RaceLook.touch_dir(0.0, r, RaceLook.Dir.NONE), RaceLook.Dir.BACK, "so segurar = tras")
	check_eq(RaceLook.touch_dir(10.0, r, RaceLook.Dir.BACK), RaceLook.Dir.BACK, "deslize curto ainda e tras")
	check_eq(RaceLook.touch_dir(20.0, r, RaceLook.Dir.BACK), RaceLook.Dir.RIGHT, "deslize para a direita")
	check_eq(RaceLook.touch_dir(-20.0, r, RaceLook.Dir.BACK), RaceLook.Dir.LEFT, "deslize para a esquerda")
	check_eq(RaceLook.touch_dir(14.0, r, RaceLook.Dir.RIGHT), RaceLook.Dir.RIGHT, "na borda nao pisca (histerese)")
	check_eq(RaceLook.touch_dir(8.0, r, RaceLook.Dir.RIGHT), RaceLook.Dir.BACK, "voltando ao centro = tras")


func test_poses_look_the_right_way() -> void:
	var me := Vector3(400.0, 0.0, 12.0)            # rear z, lateral m, length
	var back: Array[Vector3] = RaceLook.local_pose(RaceLook.Dir.BACK, me)
	check(back[0].x > me.x + me.z + 5.0, "tras: a camera fica na frente da cabine")
	check(back[1].x < me.x - 20.0, "tras: olha para longe atras do bau")
	var left: Array[Vector3] = RaceLook.local_pose(RaceLook.Dir.LEFT, me)
	var right: Array[Vector3] = RaceLook.local_pose(RaceLook.Dir.RIGHT, me)
	check(left[0].y < 0.0 and left[1].y < left[0].y - 8.0, "esquerda: do lado esquerdo, olhando para a esquerda")
	check(right[0].y > 0.0 and right[1].y > right[0].y + 8.0, "direita: espelhado")
	check(left[0].z >= 5.0, "lado: acima de um caminhao na faixa vizinha")
	var yaw: float = rad_to_deg(atan2(absf(left[1].y - left[0].y), left[1].x - left[0].x))
	check(yaw > 95.0 and yaw < 140.0, "lado: para o lado e um pouco para tras (%.0f graus)" % yaw)


func test_poses_stay_inside_the_road_in_any_lane() -> void:
	var rig := _rig()
	var bad: int = 0
	for lane_x in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		var me := Vector3(500.0, lane_x * Track.ROAD_HALF_WIDTH_M, 12.0)
		for dir in [RaceLook.Dir.BACK, RaceLook.Dir.LEFT, RaceLook.Dir.RIGHT]:
			var lp: Array[Vector3] = RaceLook.local_pose(dir, me)
			var p: Vector3 = rig.clamp_point(lp[0], me)
			var prof: Vector3 = LaneSections.profile(rig.events, p.x)
			if p.y < -prof.x or p.y > prof.y or p.z < RaceCamRig.MIN_H:
				bad += 1
			if p.x > me.x - 1.5 and p.x < me.x + me.z + 1.5 and absf(p.y - me.y) < RaceCamRig.BODY_CLEAR_M \
					and p.z < RaceCamRig.BODY_TOP_H:
				bad += 1                                 # inside the player's own truck
	check_eq(bad, 0, "camera do olhar sempre entre as muretas e fora do bau")


func test_hold_looks_and_release_returns() -> void:
	var rig := _rig()
	var look := RaceLook.new()
	var me := Vector3(400.0, 0.0, 12.0)
	var anchor: Vector3 = rig.to_world(Vector3(406.0, 0.0, 0.0))
	var fwd: Vector3 = rig.path.forward_at(406.0)
	var base: Array = [rig.to_world(Vector3(385.5, 0.0, 5.6)), rig.to_world(Vector3(414.0, 0.0, 1.8)), 56.0]
	var dt: float = 1.0 / 60.0
	var out: Array = look.update(dt, RaceLook.Dir.NONE, true, base, [], anchor, fwd, 8.0)
	check(out.is_empty(), "sem botao: a camera da corrida fica sozinha")
	var max_h: float = 0.0
	var tgt: Array = _target(rig, RaceLook.Dir.BACK, me)
	var frames: int = 0
	while look.weight < 0.999 and frames < 120:
		out = look.update(dt, RaceLook.Dir.BACK, true, base, tgt, anchor, fwd, 8.0)
		max_h = maxf(max_h, (out[0] as Vector3).y - anchor.y)
		frames += 1
	check(frames * dt <= RaceLook.CROSS_S + 0.05, "entra rapido (%.2f s)" % (frames * dt))
	check((out[0] as Vector3).distance_to(tgt[0]) < 0.01, "segurando: chega na pose de olhar para tras")
	check(max_h > 6.5, "no caminho passa POR CIMA da cabine (%.1f m)" % max_h)
	check_near(float(out[2]), RaceLook.BACK_FOV, 0.01, "FOV do olhar")
	check(look.looking(), "olhando")
	frames = 0
	while frames < 120:
		out = look.update(dt, RaceLook.Dir.NONE, true, base, [], anchor, fwd, 8.0)
		frames += 1
		if out.is_empty():
			break
	check(out.is_empty(), "soltou: volta e larga a camera")
	check(frames * dt <= RaceLook.CROSS_S + 0.05, "volta rapido (%.2f s)" % (frames * dt))
	check(not look.looking() and look.weight == 0.0, "nao esta mais olhando")


func test_move_is_smooth_without_jumps() -> void:
	var rig := _rig()
	var look := RaceLook.new()
	var me := Vector3(400.0, 0.0, 12.0)
	var anchor: Vector3 = rig.to_world(Vector3(406.0, 0.0, 0.0))
	var fwd: Vector3 = rig.path.forward_at(406.0)
	var base: Array = [rig.to_world(Vector3(385.5, 0.0, 5.6)), rig.to_world(Vector3(414.0, 0.0, 1.8)), 56.0]
	var dt: float = 1.0 / 60.0
	var prev: Vector3 = base[0]
	var worst: float = 0.0
	var seq: Array = [RaceLook.Dir.LEFT, RaceLook.Dir.RIGHT, RaceLook.Dir.BACK, RaceLook.Dir.NONE]
	for d in seq:
		for i in 30:
			var out: Array = look.update(dt, d, true, base, _target(rig, d, me), anchor, fwd, 8.0)
			var p: Vector3 = base[0] if out.is_empty() else out[0]
			check(p.is_finite(), "pose valida")
			worst = maxf(worst, p.distance_to(prev))
			prev = p
	# the longest move (in front of the cab -> behind, ~37 m) takes 0.34 s eased: < 3.5 m per 60 Hz frame
	check(worst < 3.5, "sem salto entre quadros (max %.2f m)" % worst)


func test_cut_or_pause_drops_the_look_at_once() -> void:
	var rig := _rig()
	var look := RaceLook.new()
	var me := Vector3(400.0, 0.0, 12.0)
	var anchor: Vector3 = rig.to_world(Vector3(406.0, 0.0, 0.0))
	var base: Array = [rig.to_world(Vector3(385.5, 0.0, 5.6)), rig.to_world(Vector3(414.0, 0.0, 1.8)), 56.0]
	for i in 10:
		look.update(0.05, RaceLook.Dir.LEFT, true, base, _target(rig, RaceLook.Dir.LEFT, me), anchor, Vector3.FORWARD, 8.0)
	check(look.looking(), "olhando para a esquerda")
	var out: Array = look.update(0.05, RaceLook.Dir.LEFT, false, base, [], anchor, Vector3.FORWARD, 8.0)
	check(out.is_empty() and not look.looking(), "corte/chegada: larga na hora")


func test_eye_button_clear_of_the_other_buttons() -> void:
	var bad: Array[String] = []
	for w in [480.0, 600.0]:
		for s in [0.7, 1.0, 1.25, 1.5]:
			var b: Dictionary = TouchControls.button_layout(Vector2(w, 270.0), s)
			check(b.has("look"), "botao do olho existe")
			var lc: Vector2 = b["look"]["center"]
			var lr: float = float(b["look"]["radius"]) * TouchControls.HIT_MUL
			for name in b:
				if name == "look":
					continue
				var rr: float = float(b[name]["radius"]) * TouchControls.HIT_MUL
				if lc.distance_to(b[name]["center"]) < lr + rr:
					bad.append("%s w%d s%.2f" % [name, int(w), s])
			if lc.x - lr < 0.0 or lc.y - lr < 0.0:
				bad.append("fora da tela w%d s%.2f" % [int(w), s])
	check_eq(bad, [] as Array[String], "olho nao encosta em nenhum botao")


func test_hud_cluster_still_fits_with_the_eye_button() -> void:
	for w in [480.0, 600.0]:
		var lay := HudLayout.new()
		lay.size = Vector2(w, 270.0)
		lay.touch = true
		lay.want_scale = 1.25
		lay.inset_l = 22.0
		lay.buttons = TouchControls.button_layout(lay.size, 1.0)
		lay.compute()
		var lc: Vector2 = lay.buttons["look"]["center"]
		var lr: float = float(lay.buttons["look"]["radius"]) * TouchControls.HIT_MUL
		for r in lay.cluster_rects():
			check(not HudLayout._circle_hits_rect(lc, lr, r), "velocimetro longe do olho (w %d)" % int(w))
		check(not HudLayout._circle_hits_rect(lc, lr, lay.radar), "radar longe do olho")
		check(not HudLayout._circle_hits_rect(lc, lr, lay.mirror_rect()), "retrovisor longe do olho")


func test_sim_does_not_know_the_look() -> void:
	for f in DirAccess.get_files_at("res://scripts/sim"):
		if f.ends_with(".gd"):
			var txt: String = FileAccess.get_file_as_string("res://scripts/sim/" + f)
			check(not txt.contains("RaceLook") and not txt.contains("look_dir") and not txt.contains("touch_look"),
					"sim sem olhar: " + f)
	var cmd_src: String = FileAccess.get_file_as_string("res://scripts/input/local_input.gd")
	var poll: String = cmd_src.substr(cmd_src.find("func poll"), cmd_src.find("func look_dir") - cmd_src.find("func poll"))
	check(not poll.contains("touch_look") and not poll.contains("look_back"), "o olhar nao entra no comando enviado para a simulacao/rede")
