extends TestCase
## T-198: in the real race scene (no window) the camera cycle and the mirror only touch the presentation.

const IN_TREE := true


func _snapshot(sim: RaceSim) -> Array:
	var out: Array = [sim.time]
	for t in sim.trucks:
		out.append_array([t.z, t.x, t.speed, t.rpm, t.gear, t.boost])
	if sim.traffic != null:
		for c in sim.traffic.cars:
			out.append_array([c.z, c.x])
	return out


func test_camera_cycle_and_mirror_do_not_touch_the_sim() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.last_duel_key = ""
	gs.pending_route = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	gs.pending_contract = {}
	var race: Node = (load("res://scenes/race/race3d.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(race)
	var camv: RaceCamView = race._camv
	check(camv != null and camv.mirror != null and camv.button != null, "cameras e retrovisor montados")
	if camv == null or race.sim == null:
		race.free()
		return
	camv._save = false                                # o teste nao grava nas opcoes do jogador
	var saved_cam: String = Settings.race_cam
	(race._intro as DuelIntro).skip()
	race._countdown = 0.0
	var sim: RaceSim = race.sim
	var before: Array = _snapshot(sim)
	var start_mode: int = camv.rig.mode
	var cam: Camera3D = race._cam
	var bad: int = 0
	for i in 5:
		camv.cycle()
		for n in 20:
			race._update_camera(0.05)
			if not (cam.global_position.is_finite() and cam.fov > 5.0 and cam.fov < 100.0):
				bad += 1
	check_eq(bad, 0, "todas as cameras com pose valida")
	check_eq(camv.rig.mode, start_mode, "5 toques em C voltam para a mesma camera")
	check_eq(_snapshot(sim), before, "trocar de camera nao muda a simulacao")
	camv.rig.mode = RaceCamRig.Mode.STANDARD
	camv.mirror.set_enabled(true)
	var f0: int = camv.mirror.frames_rendered
	for n in 10:
		race._update_camera(0.05)
	check(camv.mirror.active(), "retrovisor ligado na corrida")
	check(camv.mirror.frames_rendered > f0 and camv.mirror.frames_rendered <= f0 + 10, "retrovisor atualiza em taxa propria")
	check_eq(_snapshot(sim), before, "o retrovisor nao muda a simulacao")
	camv.mirror.set_enabled(false)
	check(not camv.mirror.active(), "R desliga")
	camv.rig.mode = RaceCamRig.Mode.CINEMA
	camv.mirror.set_enabled(true)
	race._update_camera(0.05)
	check(not camv.mirror.active(), "no cinema o retrovisor some")
	check_eq(Settings.race_cam, saved_cam, "opcoes do jogador intactas")
	race.free()
	gs.last_duel_key = ""
	gs.pending_route = null
	gs.new_profile()
