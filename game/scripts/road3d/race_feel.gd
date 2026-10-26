class_name RaceFeel
extends Node
## T-219: sensacao de PESO na corrida, so apresentacao (nunca muda a simulacao nem a rede). Le o TruckFeel
## (data/feel/truck_feel.tres) e faz:
##  - balanco da carroceria de cada caminhao (TruckMotion: roll, pitch, heave) com as rodas no chao;
##  - emendas do viaduto e das pontes (tranco na suspensao + "ta-dum" no som do jogador);
##  - congelamento curto (hit-stop) nas batidas grandes do jogador: offline a corrida para 60-90 ms; ONLINE so a
##    camera para (a simulacao e do servidor);
##  - vibracao do celular (Haptics), escala dos tremores ("Reduzir tremor da camera");
##  - sons: vibracao da carroceria pela velocidade, rangido ao frear forte, pancada grave nas batidas;
##  - fumaca/poeira dos pneus depois da batida e no acostamento (pedido para o BrakeFx);
##  - telemetria `--feel-log=ARQ.csv` (um quadro por linha) para os graficos de antes/depois.

const JOINT_MIN_SPEED: float = 6.0         # m/s: abaixo disto a emenda nao bate
const CREAK_COOLDOWN_S: float = 2.2
const REF_SPEED: float = 27.8              # m/s (100 km/h): o tranco da emenda vale joint_kick_mps nesta velocidade

var feel: TruckFeel
var path: TrackPath
var player: int = 0
var online: bool = false
var motions: Array[TruckMotion] = []
var elevated: bool = false                 # rota toda em viaduto (cidade)
var bridges: Array[Vector2] = []
var hitstop_left: float = 0.0              # s de congelamento que faltam
var hitstops: int = 0                      # quantos (testes/telemetria)
var _settings: Node
var _joint_prev: Dictionary = {}           # indice -> [emenda do eixo dianteiro, emenda do eixo traseiro]
var _smoke_t: PackedFloat32Array = []      # s de fumaca/poeira de pneu que faltam por caminhao (batida)
var _rumble: AudioStreamPlayer
var _creak_cd: float = 0.0
var _was_hard_braking: bool = false
var _log: FileAccess
var _log_t: float = 0.0


func setup(path_: TrackPath, n_trucks: int, player_: int, online_: bool, elevated_: bool, bridges_: Array[Vector2]) -> void:
	feel = TruckFeel.current()
	path = path_
	player = player_
	online = online_
	elevated = elevated_
	bridges = bridges_
	_settings = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	motions.clear()
	for k in n_trucks:
		motions.append(TruckMotion.new())
	_smoke_t.resize(n_trucks)
	_smoke_t.fill(0.0)
	var bus: Node = get_node_or_null("/root/AudioBus")
	if bus != null and feel.body_rumble_db > -79.0:
		_rumble = AudioStreamPlayer.new()
		_rumble.bus = "SFX"
		_rumble.stream = bus.stream("body_rumble_loop")
		_rumble.volume_db = -80.0
		add_child(_rumble)
		if _rumble.stream != null and _rumble.is_inside_tree():
			_rumble.play()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--feel-log="):
			_log = FileAccess.open(a.substr(11), FileAccess.WRITE)
			if _log != null:
				_log.store_line("t,speed_kmh,x,lateral_vel,lane,roll_deg,pitch_deg,heave_cm,lat_acc,long_acc,fov,shake,hitstop")


func _exit_tree() -> void:
	if _log != null:
		_log.close()
		_log = null


## Tremores multiplicados por isto (Opcoes > Graficos > Reduzir tremor da camera).
func shake_scale() -> float:
	return feel.reduced_shake_scale if _reduce_shake() else 1.0


func _reduce_shake() -> bool:
	if _settings == null:
		_settings = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	return _settings != null and bool(_settings.get("fx_reduce_shake"))


## Curvatura da pista em z (1/m, > 0 = curva para a esquerda).
func curvature(z: float) -> float:
	return angle_difference(path.yaw_at(z - 3.0), path.yaw_at(z + 3.0)) / 6.0


## Aceleracao vertical que a pista impoe a `speed` (m/s2, > 0 = baixada: a suspensao comprime).
func vertical_acc(z: float, speed: float) -> float:
	return speed * speed * (path.pitch_at(z + 3.0) - path.pitch_at(z - 3.0)) / 6.0


## Esta pista tem emendas de dilatacao em z (viaduto da cidade inteiro, pontes)?
func has_joints(z: float) -> bool:
	return elevated or RoadMesh.in_tunnel(z, bridges)


## Avanca o balanco do caminhao `k` (z/x desenhados) e aplica no no. Chame todo quadro, depois do transform.
func update_truck(k: int, node: TruckNode, t: TruckSim, z: float, dt: float) -> void:
	while motions.size() <= k:                   # online: caminhao que entrou depois do setup
		motions.append(TruckMotion.new())
		_smoke_t.append(0.0)
	var mid: float = z + t.length * 0.5
	var kick: float = _joint_kick(k, t, z)
	var m: TruckMotion = motions[k]
	m.step(dt, feel, t.speed, t.lateral_vel * Track.ROAD_HALF_WIDTH_M, curvature(mid), vertical_acc(mid, t.speed), kick)
	node.set_body_motion(m.roll, m.pitch, m.heave, t.length)
	if k < _smoke_t.size():
		_smoke_t[k] = maxf(_smoke_t[k] - dt, 0.0)


## Tranco da emenda quando um eixo passa por ela (dianteiro e traseiro: "ta-dum").
func _joint_kick(k: int, t: TruckSim, z: float) -> float:
	if t.speed < JOINT_MIN_SPEED or feel.joint_spacing_m <= 1.0:
		_joint_prev.erase(k)
		return 0.0
	var front: float = z + t.length * TrackPath.FRONT_AXLE
	var rear: float = z + t.length * TrackPath.REAR_AXLE
	var jf: int = int(floorf(front / feel.joint_spacing_m))
	var jr: int = int(floorf(rear / feel.joint_spacing_m))
	var prev: Array = _joint_prev.get(k, [jf, jr])
	_joint_prev[k] = [jf, jr]
	var kick: float = 0.0
	var amp: float = feel.joint_kick_mps * clampf(t.speed / REF_SPEED, 0.3, 1.5)
	if jf != int(prev[0]) and has_joints(front):
		kick += amp
	if jr != int(prev[1]) and has_joints(rear):
		kick += amp * 0.8
	if kick > 0.0 and k == player:
		_play("road_joint_thump", feel.joint_thump_db, randf_range(0.9, 1.08))
	return kick


## Eventos da simulacao: congelamento, vibracao, pancada grave, fumaca de pneu.
func on_event(e: Dictionary) -> void:
	var kind: String = String(e["type"])
	var force: float = float(e.get("force", 0.0))
	var mine: bool = false
	match kind:
		"truck":
			mine = int(e["a"]) == player or int(e["b"]) == player
			_smoke(int(e["a"]))
			_smoke(int(e["b"]))
			if mine:
				Haptics.pulse(clampf(40.0 + force * 10.0, 40.0, 160.0))
		"traffic", "event_obstacle":
			mine = int(e["truck"]) == player
			_smoke(int(e["truck"]))
			if mine:
				Haptics.pulse(clampf(30.0 + force * 8.0, 30.0, 140.0))
		_:
			return
	if not mine:
		return
	if force >= 4.0:
		_play("impact_thud_deep", feel.impact_thud_db + clampf((force - 10.0) * 0.4, -6.0, 2.0), randf_range(0.92, 1.04))
	if force >= feel.hitstop_min_force and feel.hitstop_ms > 0.0 and not _reduce_shake():
		hitstop_left = maxf(hitstop_left, feel.hitstop_ms / 1000.0)
		hitstops += 1


func _smoke(k: int) -> void:
	if k >= 0 and k < _smoke_t.size():
		_smoke_t[k] = feel.crash_tire_smoke_s


## 0..1: fumaca de pneu pedida para o caminhao `k` (depois de uma batida).
func tire_smoke(k: int) -> float:
	return clampf(_smoke_t[k] / maxf(feel.crash_tire_smoke_s, 0.01), 0.0, 1.0) if k < _smoke_t.size() else 0.0


## Poeira no acostamento?
func offroad_dust(t: TruckSim) -> bool:
	return feel.offroad_dust_from_mps > 0.0 and t.offroad and t.speed >= feel.offroad_dust_from_mps


## Congelamento: devolve true enquanto dura (e desconta `delta`). Offline a cena pula o quadro inteiro; online so a camera.
func consume_hitstop(delta: float) -> bool:
	if hitstop_left <= 0.0:
		return false
	hitstop_left = maxf(hitstop_left - delta, 0.0)
	return true


## Sons continuos do jogador: vibracao da carroceria pela velocidade e rangido ao frear forte / balanco grande.
func update_audio(dt: float, t: TruckSim) -> void:
	_creak_cd = maxf(_creak_cd - dt, 0.0)
	if _rumble != null and _rumble.stream != null:
		var v01: float = clampf(t.speed / EngineModel.MAX_SPEED, 0.0, 1.0)
		var w: float = clampf(t.speed / 5.0, 0.0, 1.0) * (0.25 + 0.75 * v01)
		_rumble.volume_db = linear_to_db(w) + feel.body_rumble_db if w > 0.01 else -80.0
		_rumble.pitch_scale = 0.8 + 0.45 * v01
	var m: TruckMotion = motions[player] if player < motions.size() else null
	var swing: bool = m != null and absf(m.roll) > deg_to_rad(feel.roll_max_deg) * 0.85
	if ((t.hard_braking and not _was_hard_braking) or swing) and _creak_cd <= 0.0 and t.speed > 8.0:
		_creak_cd = CREAK_COOLDOWN_S
		_play("chassis_creak", feel.creak_db, randf_range(0.85, 1.1))
	_was_hard_braking = t.hard_braking


func _play(name: String, db: float, pitch: float = 1.0) -> void:
	if db <= -79.0:
		return
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")
	if bus != null and bus.is_node_ready() and bus.stream(name) != null:
		bus.play_sfx(name, db, pitch)


## Uma linha de telemetria (so com --feel-log).
func log_frame(dt: float, t: TruckSim, fov: float, shake: float) -> void:
	if _log == null:
		return
	_log_t += dt
	var m: TruckMotion = motions[player]
	_log.store_line("%.3f,%.2f,%.4f,%.4f,%d,%.3f,%.3f,%.2f,%.3f,%.3f,%.2f,%.3f,%d" % [_log_t, t.speed * 3.6, t.x, t.lateral_vel,
		t.lane, rad_to_deg(m.roll), rad_to_deg(m.pitch), m.heave * 100.0, m.lat_acc, m.long_acc, fov, shake,
		1 if hitstop_left > 0.0 else 0])
