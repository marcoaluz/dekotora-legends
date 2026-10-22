extends TestCase
## T-198: race camera modes, cinema director, mirror defaults and saved settings (pure: no scene).


func _rig(tunnels: Array[Vector2] = []) -> RaceCamRig:
	var track: Track = Track.make_test_track()
	return RaceCamRig.new(TrackPath.new(track), track.events, tunnels)


func test_cycle_goes_through_the_five_cameras_and_wraps() -> void:
	var m: int = RaceCamRig.Mode.STANDARD
	var seen: Array[String] = []
	for i in 5:
		m = RaceCamRig.next_mode(m)
		seen.append(RaceCamRig.IDS[m])
	check_eq(seen, ["far", "cinema", "orbit", "near", "standard"], "C: padrao -> longe -> cinema -> orbita -> perto -> padrao")
	check_eq(RaceCamRig.mode_from_id("xyz"), RaceCamRig.Mode.STANDARD, "id desconhecido vira a padrao")


func test_standard_camera_is_the_old_one() -> void:
	var rig := _rig()
	var z: float = 400.0
	var x: float = 0.3
	var k: float = 1.2
	var c: Array[Vector3] = rig.chase_target(z, x, k)
	check(c[0].distance_to(rig.path.world_point(z - (10.0 + 4.5 * k), x * 0.85, 4.6 + 1.0 * k)) < 0.001, "posicao igual a de antes")
	check(c[1].distance_to(rig.path.world_point(z + 14.0, x * 0.45, 1.8)) < 0.001, "alvo igual ao de antes")


func test_near_is_closer_and_far_is_higher() -> void:
	var rig := _rig()
	rig.mode = RaceCamRig.Mode.STANDARD
	var std: Array[Vector3] = rig.chase_local(400.0, 0.0, 1.0)
	rig.mode = RaceCamRig.Mode.NEAR
	var near: Array[Vector3] = rig.chase_local(400.0, 0.0, 1.0)
	rig.mode = RaceCamRig.Mode.FAR
	var far: Array[Vector3] = rig.chase_local(400.0, 0.0, 1.0)
	check(near[0].x > std[0].x and far[0].x < std[0].x, "perto mais perto, longe mais atras")
	check(far[0].z > std[0].z + 4.0, "longe mais alta")
	check(rig.fx_scale() < 1.0, "longe: efeitos de velocidade mais calmos")


func test_clamp_keeps_the_camera_between_the_barriers() -> void:
	var rig := _rig()
	var p: Vector3 = rig.clamp_point(Vector3(300.0, 40.0, 2.0))
	check(p.y <= LaneSections.OPEN_WALL_M - RaceCamRig.WALL_GAP_M + 0.001, "nao passa da mureta da direita (%.1f)" % p.y)
	p = rig.clamp_point(Vector3(300.0, -40.0, -3.0))
	check(p.y >= -(LaneSections.OPEN_WALL_M - RaceCamRig.WALL_GAP_M) - 0.001, "nem da esquerda")
	check(p.z >= RaceCamRig.MIN_H, "nunca abaixo do asfalto")


func test_clamp_glides_under_the_tunnel_arch() -> void:
	var rig := _rig([Vector2(600.0, 300.0)] as Array[Vector2])
	check(rig.clamp_point(Vector3(700.0, 0.0, 12.0)).z <= RaceCamRig.TUNNEL_H_MAX + 0.001, "dentro do tunel: baixa")
	check_near(rig.clamp_point(Vector3(300.0, 0.0, 12.0)).z, 12.0, 0.001, "longe do tunel: livre")
	var last: float = rig.clamp_point(Vector3(520.0, 0.0, 12.0)).z
	var worst: float = 0.0
	for i in 81:                               # entrando no tunel de metro em metro: sem degrau
		var h: float = rig.clamp_point(Vector3(520.0 + float(i), 0.0, 12.0)).z
		worst = maxf(worst, absf(h - last))
		last = h
	check(worst < 0.5, "a descida perto da boca e suave (maior degrau %.2f m/m)" % worst)


func test_clamp_keeps_out_of_the_player_box() -> void:
	var rig := _rig()
	var me := Vector3(400.0, 1.8, 12.0)
	var p: Vector3 = rig.clamp_point(Vector3(405.0, 2.0, 2.0), me)
	check(absf(p.y - me.y) >= RaceCamRig.BODY_CLEAR_M - 0.001 or p.z >= RaceCamRig.BODY_TOP_H, "camera fora do bau")


func test_orbit_turns_one_lap_then_returns_behind() -> void:
	check_near(RaceCamRig.orbit_angle(0.0), 0.0, 0.001, "comeca atras")
	check(RaceCamRig.orbit_angle(RaceCamRig.ORBIT_LAP_S * 0.5) > 2.5, "meia volta no meio")
	check_near(RaceCamRig.orbit_angle(RaceCamRig.ORBIT_LAP_S + 1.0), 0.0, 0.001, "parada atras (retorno automatico)")
	var worst: float = 0.0
	for i in 600:
		worst = maxf(worst, absf(wrapf(RaceCamRig.orbit_angle(float(i + 1) * 0.05) - RaceCamRig.orbit_angle(float(i) * 0.05), -PI, PI)))
	check(worst < 0.07, "giro suave (max %.3f rad por quadro de 50 ms)" % worst)


func test_free_poses_stay_finite_and_inside_the_road() -> void:
	var rig := _rig([Vector2(900.0, 200.0)] as Array[Vector2])
	var lim: float = LaneSections.OPEN_WALL_M - RaceCamRig.WALL_GAP_M + 0.001
	for m in [RaceCamRig.Mode.CINEMA, RaceCamRig.Mode.ORBIT]:
		rig.mode = m
		rig.director.reset()
		var z: float = 300.0
		var bad: int = 0
		for i in 900:                          # 30 s a 30 quadros/s, rival passando
			z += 0.9
			var rival := Vector3(z + 40.0 - float(i) * 0.1, -3.6, 14.0)
			var me := Vector3(z, 1.8, 12.0)
			var p: Array = rig.director.update(1.0 / 30.0, me, 27.0, rival, rig) if m == RaceCamRig.Mode.CINEMA \
					else rig.orbit_local(float(i) / 30.0, me)
			var c: Vector3 = rig.clamp_point(p[0], me)
			if not (c.is_finite() and absf(c.y) <= lim and float(p[2]) > 5.0 and float(p[2]) < 90.0):
				bad += 1
		check_eq(bad, 0, "%s: pose valida em todos os quadros" % RaceCamRig.IDS[m])


func test_cinema_cuts_every_few_seconds_and_on_overtake() -> void:
	var rig := _rig()
	var d: RaceCamDirector = rig.director
	var me := Vector3(300.0, 0.0, 12.0)
	var far := Vector3(NAN, 0.0, 0.0)
	var prev: String = ""
	var repeats: int = 0
	var rival_shots: int = 0
	for i in 30 * 60:                          # 1 min sem rival
		d.update(1.0 / 30.0, me, 25.0, far, rig)
		if d.shot_t == 0.0:
			if d.shot == prev:
				repeats += 1
			prev = d.shot
			if d.shot == "rival" or d.shot == "overtake":
				rival_shots += 1
	check_eq(rival_shots, 0, "sem rival nao ha tomada do rival")
	check(d.cuts >= 60 / int(RaceCamDirector.SHOT_MAX_S) and d.cuts <= 60 / int(RaceCamDirector.SHOT_MIN_S) + 2,
			"cortes a cada 4,5-7 s (%d em 1 min)" % d.cuts)
	check_eq(repeats, 0, "nunca a mesma tomada duas vezes seguidas")
	d.reset()
	d.update(1.0 / 30.0, me, 25.0, Vector3(305.0, 3.6, 12.0), rig)
	for i in 60:
		d.update(1.0 / 30.0, me, 25.0, Vector3(305.0, 3.6, 12.0), rig)
	d.update(1.0 / 30.0, me, 25.0, Vector3(295.0, 3.6, 12.0), rig)      # o rival ficou para tras: ultrapassagem
	check_eq(d.shot, "overtake", "corte automatico na ultrapassagem")
	check(d.side < 0.0, "camera do lado de fora da dupla (rival na direita -> camera na esquerda)")


func test_blend_starts_at_the_old_pose_and_ends_at_the_new() -> void:
	var rig := _rig()
	var anchor := Vector3(10, 0, 10)
	rig.set_mode(RaceCamRig.Mode.FAR, Vector3(10, 5, 20), Vector3(10, 2, 0), 56.0, anchor)
	var b: Array = rig.blend(Vector3(10, 12, 40), Vector3(10, 0, -10), 52.0, anchor, 0.0)
	check((b[0] as Vector3).distance_to(Vector3(10, 5, 20)) < 0.01, "comeca onde estava")
	for i in 40:
		b = rig.blend(Vector3(10, 12, 40), Vector3(10, 0, -10), 52.0, anchor, 0.05)
	check((b[0] as Vector3).distance_to(Vector3(10, 12, 40)) < 0.01 and not rig.blending(), "termina na camera nova")


func test_mirror_defaults_and_initial_camera() -> void:
	check(not RaceCamView.mirror_auto_on(0, false), "qualidade baixa: desligado")
	check(not RaceCamView.mirror_auto_on(1, true), "celular medio: desligado")
	check(RaceCamView.mirror_auto_on(1, false) and RaceCamView.mirror_auto_on(3, false), "PC medio/Ultra: ligado")
	check(RaceCamView.mirror_on(1, 0, true) and not RaceCamView.mirror_on(2, 3, false), "ligado/desligado mandam")
	check_eq(RaceCamView.initial_mode("kanto_1_coast", {"kanto_1_coast": "far"}, "near"), RaceCamRig.Mode.FAR, "camera da rota")
	check_eq(RaceCamView.initial_mode("kanto_2_city", {"kanto_1_coast": "far"}, "near"), RaceCamRig.Mode.NEAR, "senao a ultima")


func test_settings_keep_camera_and_mirror() -> void:
	var path: String = "user://test_settings_t198.cfg"
	var a: Node = (load("res://scripts/autoload/settings.gd") as GDScript).new()
	a.race_cam = "orbit"
	a.race_cam_routes = {"kanto_3_mountain": "cinema"}
	a.mirror_mode = 2
	a.cam_letterbox = false
	a.save_settings(path)
	var b: Node = (load("res://scripts/autoload/settings.gd") as GDScript).new()
	b.load_settings(path)
	check_eq(b.race_cam, "orbit", "camera salva")
	check_eq(String(b.race_cam_routes.get("kanto_3_mountain", "")), "cinema", "camera por rota salva")
	check_eq(b.mirror_mode, 2, "retrovisor salvo")
	check(not b.cam_letterbox, "faixas pretas salvas")
	a.free()
	b.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_sim_does_not_know_the_cameras() -> void:
	var bad: Array[String] = []
	for f in DirAccess.get_files_at("res://scripts/sim/"):
		if not f.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://scripts/sim/" + f)
		for word in ["RaceCam", "RearMirror", "race_cam", "mirror_mode", "SubViewport"]:
			if src.contains(word):
				bad.append(f + ":" + word)
	check_eq(bad, [] as Array[String], "scripts/sim/ nao usa camera nem retrovisor")
