class_name RaceAudio
extends Node
## Todo o audio de uma corrida (P52): motor do jogador em camadas, motores dos rivais com volume pela
## distancia, ambiente (vento, pneus, cascalho, carga), efeitos de batida por forca, peca quebrando,
## marcha, Passing (farol + buzina da peca instalada), contagem e musica por tela.

var player_engine: EngineAudio
var _loops: Dictionary = {}           # nome -> AudioStreamPlayer
var _last_gear: int = 1
var _shift_idx: int = 0
var _bump_idx: int = 0
var _crash_idx: int = 0
var _countdown_last: int = 4
var _scrape: AudioStreamPlayer
var _works_loop: AudioStreamPlayer     # T-139: ruido das obras (so se o arquivo existir)
## T-139: sons dos eventos de pista. Os nomes novos (docs/AUDIO_ELEVENLABS.md) entram quando o arquivo existir;
## ate la toca o som de reserva que ja existe.
const EVENT_SOUNDS: Dictionary = {
	"cone": ["cone_hit", "bump_light_1", -8.0],
	"scrape": ["barrier_scrape", "bump_light_2", -7.0],
	"plates": ["steel_plate_clank", "bump_light_1", -9.0],
	"alert": ["event_alert_chime", "countdown_beep", -9.0],
}
const AUDIO_DIRS: Array[String] = ["res://assets/audio/sfx/crash/", "res://assets/audio/sfx/truck/", "res://assets/audio/sfx/ui/",
	"res://assets/audio/sfx/ambient/"]


func setup(truck: TruckSim, engine_set: String, turbo_id: String, straight: bool, music_name: String) -> void:
	var audio: Node = get_node("/root/AudioBus")
	player_engine = EngineAudio.new()
	add_child(player_engine)
	player_engine.setup(engine_set, turbo_id, straight, truck.engine.has_jake)
	for n in ["wind_speed_loop", "tire_screech_loop", "tire_gravel_loop", "cargo_rattle_loop"]:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = audio.stream(n)
		p.volume_db = -80.0
		add_child(p)
		if p.stream != null:
			p.play()
		_loops[n] = p
	_last_gear = truck.gear
	audio.play_music(music_name)


## Motor de um rival: volume e tom proprios, posicional (cai com a distancia).
func make_rival_engine(parent: Node3D, engine_set: String = "i6_std", turbo_id: String = "turbo_none") -> EngineAudio:
	var e := EngineAudio.new()
	e.positional = true
	e.bus = "Engine"
	parent.add_child(e)
	e.setup(engine_set, turbo_id, false, false, true)
	return e


func update(dt: float, t: TruckSim, countdown: float) -> void:
	var rpm01: float = clampf((t.rpm - EngineModel.IDLE_RPM) / (t.engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)
	player_engine.update(dt, rpm01, t.engine.throttle_now, t.boost, float(t.systems["engine"]) / 100.0, t.speed)
	if t.engine.blowoff:
		player_engine.blowoff()
	if t.gear != _last_gear:
		_shift_idx = 1 - _shift_idx
		get_node("/root/AudioBus").play_sfx("gear_shift_%d" % (_shift_idx + 1), -6.0)
		_last_gear = t.gear
	_set_loop("wind_speed_loop", clampf(t.speed / 38.9, 0.0, 1.0) * 0.55, -8.0)
	# pneu cantando: so quando passa da velocidade segura da curva (TruckSim.skid); escapando, no maximo
	_set_loop("tire_screech_loop", 1.0 if t.escaping else t.skid * 0.85, -6.0)
	_set_loop("tire_gravel_loop", (clampf(t.speed / 20.0, 0.0, 1.0) * 0.8) if t.offroad else 0.0, -4.0)
	var cargo_loss: float = 1.0 - t.cargo_integrity()
	_set_loop("cargo_rattle_loop", clampf(cargo_loss * 1.4, 0.0, 0.8) * clampf(t.speed / 20.0, 0.0, 1.0), -10.0)
	# contagem regressiva
	if countdown > 0.0:
		var n: int = int(ceil(countdown))
		if n != _countdown_last and n <= 3:
			_countdown_last = n
			get_node("/root/AudioBus").play_sfx("countdown_beep")
	elif _countdown_last != 0:
		_countdown_last = 0
		get_node("/root/AudioBus").play_sfx("countdown_go")


func _set_loop(name: String, weight: float, gain_db: float) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if p == null or p.stream == null:
		return
	p.volume_db = (linear_to_db(clampf(weight, 0.0, 1.0)) + gain_db) if weight > 0.01 else -80.0


## Evento da simulacao (RaceSim.drain_events). `me` = indice do jogador.
func on_event(e: Dictionary, me: int) -> void:
	var audio: Node = get_node("/root/AudioBus")
	match String(e["type"]):
		"truck":
			if int(e["a"]) != me and int(e["b"]) != me:
				return
			var f: float = float(e["force"])
			_crash_sound(f)
			if not (e["broken_a"] as Array).is_empty() or not (e["broken_b"] as Array).is_empty():
				audio.play_sfx("chrome_part_break", -2.0)
				audio.play_sfx("lights_shatter", -6.0)
		"traffic":
			if int(e["truck"]) != me:
				return
			audio.play_sfx("car_hit", -2.0)
			if float(e["force"]) > 8.0:
				_crash_sound(float(e["force"]))
			if not (e["broken"] as Array).is_empty():
				audio.play_sfx("chrome_part_break", -2.0)
		"overtake":
			if int(e["truck"]) == me:
				audio.play_sfx("fame_up", -8.0)
		"passing_scare":
			if int(e["to"]) == me:
				audio.play_sfx("horn_air_basic", -3.0)
		"event_cone", "event_scrape", "event_plates":     # T-139
			if int(e["truck"]) == me:
				_event_sfx(String(e["type"]).substr(6))
		"event_obstacle":
			if int(e["truck"]) == me:
				audio.play_sfx("car_hit", -1.0)
				_crash_sound(float(e["force"]))
				if not (e["broken"] as Array).is_empty():
					audio.play_sfx("chrome_part_break", -2.0)


## Aviso de evento de pista no HUD (T-139).
func event_alert() -> void:
	_event_sfx("alert")


func _event_sfx(kind: String) -> void:
	var s: Array = EVENT_SOUNDS[kind]
	get_node("/root/AudioBus").play_sfx(String(s[0]) if has_sound(String(s[0])) else String(s[1]), float(s[2]))


## O arquivo de som existe (sem aviso de "som nao encontrado")?
static func has_sound(name: String) -> bool:
	for d in AUDIO_DIRS:
		for ext in [".mp3", ".ogg", ".wav"]:
			if ResourceLoader.exists(d + name + ext):
				return true
	return false


## Ruido das obras pela distancia ate a obra mais perto (T-139; so toca se `roadworks_loop` existir).
func update_events(evs: TrackEvents, z: float) -> void:
	if evs.is_empty():
		return
	if _works_loop == null:
		if not has_sound("roadworks_loop"):
			return
		_works_loop = AudioStreamPlayer.new()
		_works_loop.bus = "SFX"
		_works_loop.stream = get_node("/root/AudioBus").stream("roadworks_loop")
		_works_loop.volume_db = -80.0
		add_child(_works_loop)
		_works_loop.play()
	var best: float = INF
	for ev in evs.list:
		if ev.kind == TrackEvents.Kind.WORKS:
			best = minf(best, maxf(maxf(ev.z - z, z - ev.end_z()), 0.0))
	var wgt: float = clampf(1.0 - best / 160.0, 0.0, 1.0)
	_works_loop.volume_db = (linear_to_db(wgt) - 6.0) if wgt > 0.01 else -80.0


func _crash_sound(force: float) -> void:
	var audio: Node = get_node("/root/AudioBus")
	if force < 4.0:
		_bump_idx = 1 - _bump_idx
		audio.play_sfx("bump_light_%d" % (_bump_idx + 1), -2.0)
	else:
		_crash_idx = 1 - _crash_idx
		audio.play_sfx("crash_heavy_%d" % (_crash_idx + 1), 0.0)


## Botao Passing apertado: farol alto + buzina (a da peca instalada, se houver).
func passing_pressed(horn: String) -> void:
	var audio: Node = get_node("/root/AudioBus")
	audio.play_sfx("passing_flash", -2.0)
	audio.play_sfx(horn if horn != "" else "horn_air_basic", -4.0)


func finish_race(won: bool) -> void:
	var audio: Node = get_node("/root/AudioBus")
	audio.play_jingle("results_win" if won else "results_lose")
	for p in _loops.values():
		(p as AudioStreamPlayer).volume_db = -80.0
	player_engine.update(0.1, 0.0, 0.0, 0.0)
