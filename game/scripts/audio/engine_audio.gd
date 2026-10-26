class_name EngineAudio
extends Node
## Som do motor em camadas (GDD "Som do motor em camadas", P51): loops por motor (idle/low/mid/high, ou
## idle/mid/high nos perfis de escapamento da T-173) misturados por RPM com ajuste de tom, camada do turbo
## seguindo o boost, "pssh" ao soltar o acelerador com turbo cheio, freio-motor, escape direto e chacoalho de dano.
## Use: setup_spec(EngineSounds.spec("eng_v8", "turbo_single", "exh_stack"), jake) e update(...) a cada frame.
## setup("i6_std", "turbo_single", true, false) continua valendo (formato antigo, sem perfil de escapamento).
## T-197: spec com "voice" = diesel sintetizado (DieselMix): loops por RPM real com carga (ON/OFF), troca de marcha
## (queda e retomada, derivada do RPM), freio-motor por RPM, ronco de escape aberto, estalos, cabine e Doppler.
## T-220: modo do som (EngineSoundMode): "loops" (acima), "synth" (diesel procedural EngineSynthVoice no lugar dos
## loops ON/OFF) ou "mix" (procedural nos graves + loops so nos medios/agudos, barramento EngineLoopsHP). Gravacoes
## reais recortadas (rec_<voz>_<on|off>_<rpm>, tools/cut_loops.py) substituem os loops syn_ quando existem.

const BANDS: Array[String] = ["idle", "low", "mid", "high"]
const CENTERS: Array[float] = [0.0, 0.3, 0.62, 0.95]       # rpm normalizado (0..1) onde cada camada e mais forte
const WIDTH: float = 0.34
const CENTERS_3: Array[float] = [0.0, 0.5, 0.95]            # perfis com 3 camadas (T-173)
const WIDTH_3: float = 0.5
## T-197: nivel do diesel sintetizado para ficar no mesmo volume medio dos loops antigos (medido nas gravacoes
## de docs/audio_t197: acelerando -22 dBFS, lenta -28/-30 dBFS).
const DIESEL_DB: float = -4.5

var engine_set: String = "i6_std"
var turbo_set: String = ""            # loop do turbo ("turbo_single_whine", "exh_stack_turbo_whine"...) ou ""
var straight_exhaust: bool = false
var has_jake: bool = false
var bus: String = "Engine"
var positional: bool = false          # true = AudioStreamPlayer3D (outros caminhoes, volume pela distancia)
var max_distance: float = 120.0
## Rival offline: a simulacao dele nao tem turbo, entao o boost do som e estimado pelo acelerador e RPM (T-173).
var synth_boost: bool = false
var spec: Dictionary = {}
## T-197: som de dentro da cabine (barramento EngineCab: abafado, grave). So vale antes do setup_spec.
var interior: bool = false

var _bands: Array[String] = []
var _centers: Array[float] = CENTERS
var _width: float = WIDTH
var _pitch_mul: float = 1.0
var _turbo_pitch: float = 1.0
var _turbo_db: float = 0.0
var _gains: Dictionary = {}
var _blowoffs: Array = ["turbo_blowoff_1", "turbo_blowoff_2"]
var _players: Dictionary = {}         # nome da camada -> AudioStreamPlayer(3D)
var _smooth_throttle: float = 0.0
var _smooth_rpm: float = 0.0
var _synth: float = 0.0
var _blowoff_idx: int = 0
# T-197 (diesel sintetizado)
var _voice: String = ""
var _redline: float = 2400.0
var _open_db: float = -80.0
var _gain_db: float = 0.0
var _pops: bool = false
var _lazy: Dictionary = {}            # camadas que so tocam com peso > 0 (economiza vozes)
var _load: float = 0.0
var _jake: float = 0.0
var _shift_t: float = 0.0
var _prev_rpm: float = -1.0
var _prev_throttle: float = 0.0
var _pop_t: float = 0.0
var _pop_rng := RandomNumberGenerator.new()
var _doppler: float = 1.0
var _prev_dist: float = -1.0
# T-220
## "" = EngineSoundMode.current(); "loops" | "synth" | "mix" forca (cena de teste). Vale antes do setup_spec.
var mode_override: String = ""
var sound_mode: String = "loops"
var proc: EngineSynthVoice = null
var _src: String = "syn"
var _health: float = 1.0


## Formato antigo (engine_set = prefixo dos loops de 4 camadas).
func setup(engine_set_: String, turbo_id: String = "turbo_none", straight: bool = false, jake: bool = false, positional_: bool = false) -> void:
	var s: Dictionary = {"set": engine_set_, "bands": BANDS, "pitch": 1.0, "straight": straight,
		"turbo": {"turbo_single": "turbo_single_whine", "turbo_twin": "turbo_twin_whine"}.get(turbo_id, "")}
	positional = positional_
	setup_spec(s, jake)


## Spec de EngineSounds.spec() (T-173).
func setup_spec(s: Dictionary, jake: bool = false) -> void:
	spec = s
	engine_set = String(s.get("set", "i6_std"))
	_bands.assign(s.get("bands", BANDS))
	if _bands.size() == 3:
		_centers = CENTERS_3
		_width = WIDTH_3
	else:
		_centers = CENTERS
		_width = WIDTH
	_pitch_mul = float(s.get("pitch", 1.0))
	turbo_set = String(s.get("turbo", ""))
	_turbo_pitch = float(s.get("turbo_pitch", 1.0))
	_turbo_db = float(s.get("turbo_db", 0.0))
	_gains = s.get("gains", {})
	_blowoffs = s.get("blowoffs", ["turbo_blowoff_1", "turbo_blowoff_2"])
	straight_exhaust = bool(s.get("straight", false))
	has_jake = jake
	for c in get_children():
		c.queue_free()
	proc = null
	sound_mode = "loops"
	_players.clear()
	_lazy.clear()
	_voice = String(s.get("voice", ""))
	if _voice != "":
		_setup_diesel(s)
	else:
		for b in _bands:
			_add_layer("%s_%s" % [engine_set, b])
		if straight_exhaust:
			_add_layer("exhaust_straight_layer")
		if has_jake:
			_add_layer("jake_brake")
	if turbo_set != "":
		_add_layer(turbo_set)
	_add_layer("engine_damaged_rattle")


func _setup_diesel(s: Dictionary) -> void:
	_redline = float(s.get("redline", 2400.0))
	_open_db = float(s.get("open_db", -80.0))
	_gain_db = float(s.get("gain_db", 0.0)) + DIESEL_DB
	_pops = bool(s.get("pops", false))
	_pop_rng.seed = hash(_voice) + get_instance_id()
	_src = "rec" if EngineSounds.has_engine_file(DieselMix.layer(_voice, "on", DieselMix.IDLE_RPM, "rec")) else "syn"
	var vdef: EngineVoiceDef = null
	if not positional:                                   # T-220: outros caminhoes ficam nos loops (custo)
		var m: String = mode_override if mode_override in EngineSoundMode.MODES else EngineSoundMode.current()
		vdef = EngineSoundMode.voice_def(_voice)
		if vdef != null:
			sound_mode = m
	var loop_bus: String = "EngineLoopsHP" if sound_mode == "mix" and AudioServer.get_bus_index("EngineLoopsHP") >= 0 else ""
	if sound_mode != "synth":
		for r in DieselMix.RPM_POINTS:
			_add_layer(DieselMix.layer(_voice, "on", r, _src), true, loop_bus)
			_add_layer(DieselMix.layer(_voice, "off", r, _src), true, loop_bus)
	if sound_mode != "loops":
		_add_proc(vdef)
	if not positional and "--synth-log" in OS.get_cmdline_user_args():
		print("ENGINE_SOUND voz=%s modo=%s fonte=%s" % [_voice, sound_mode, _src])
	if _open_db > -60.0:
		for r in DieselMix.OPEN_POINTS:
			_add_layer(DieselMix.layer(_voice, "open", r), true)
	if has_jake:
		for r in DieselMix.JAKE_POINTS:
			_add_layer(DieselMix.layer(_voice, "jake", r), true)
	if _pops:
		_add_layer("syn_exh_pop_1", true)
		_add_layer("syn_exh_pop_2", true)


## Camadas tocando (testes / ferramenta de teste).
func layer_names() -> Array[String]:
	var out: Array[String] = []
	for k in _players:
		out.append(String(k))
	return out


## Camadas com volume agora (T-197: as do diesel so tocam com peso > 0). Vale tambem sem audio (testes).
func active_layers() -> Array[String]:
	var out: Array[String] = []
	for k in _players:
		if float(_players[k].get("volume_db")) > -79.0:
			out.append(String(k))
	return out


## T-220: diesel procedural do caminhao do jogador (so cliente; o no nao toca sem janela).
func _add_proc(vdef: EngineVoiceDef) -> void:
	var cfg: EngineAudioConfig = EngineSoundMode.config()
	var send: String = "EngineCab" if interior and AudioServer.get_bus_index("EngineCab") >= 0 else bus
	var hp: int = AudioServer.get_bus_index("EngineLoopsHP")
	if hp >= 0:
		AudioServer.set_bus_send(hp, send)
	proc = EngineSynthVoice.new()
	proc.name = "DieselSynth"
	proc.redline = _redline
	proc.configure(vdef, EngineSoundMode.light(), send, cfg.crossover_hz if sound_mode == "mix" else 0.0, cfg)
	proc.base_db += _gain_db
	add_child(proc)


func _add_layer(sound: String, lazy: bool = false, bus_override: String = "") -> void:
	var audio: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")   # vale fora da arvore tambem
	if audio == null:
		return
	var s: AudioStream = audio.stream(sound)
	if s == null:
		return
	var p: Node
	var b: String = "EngineCab" if interior and AudioServer.get_bus_index("EngineCab") >= 0 else bus
	if bus_override != "":
		b = bus_override
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = max_distance
		p3.unit_size = 14.0
		p3.bus = b
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.bus = b
		p = p2
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	_players[sound] = p
	if lazy:
		_lazy[sound] = true
	else:
		p.play()


## Pesos das camadas para um RPM normalizado (0..1). Funcao pura (testavel). Sem `centers` = as 4 camadas antigas.
static func band_weights(rpm01: float, centers: Array[float] = CENTERS, width: float = WIDTH) -> Array[float]:
	var out: Array[float] = []
	var total: float = 0.0
	for c in centers:
		var w: float = clampf(1.0 - absf(rpm01 - c) / width, 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)            # smoothstep: crossfade suave
		out.append(w)
		total += w
	if total <= 0.0001:
		out[0] = 1.0
		total = 1.0
	for i in out.size():
		out[i] = out[i] / total
	return out


## Tom (pitch_scale) para o RPM: sobe com a rotacao.
static func pitch_for(rpm01: float) -> float:
	return 0.78 + clampf(rpm01, 0.0, 1.0) * 0.62


## Tom da turbina pelo boost (T-178): sobe so ~6 semitons (0,85 -> 1,2). Antes ia de 0,8 a 1,5 (quase uma oitava),
## e o assobio subindo soava como o "riser" de sintetizador de musica eletronica.
const TURBO_PITCH_MIN: float = 0.85
const TURBO_PITCH_MAX: float = 1.2


static func turbo_pitch_for(boost: float) -> float:
	return lerpf(TURBO_PITCH_MIN, TURBO_PITCH_MAX, clampf(boost, 0.0, 1.0))


func _set_layer(name: String, weight: float, pitch: float, gain_db: float = 0.0) -> void:
	var p: Node = _players.get(name)
	if p == null:
		return
	gain_db += float(_gains.get(name, 0.0))
	var on: bool = weight > 0.003
	p.volume_db = linear_to_db(clampf(weight, 0.0, 1.0)) + gain_db if on else -80.0
	p.pitch_scale = pitch * _doppler
	if _lazy.has(name) and on != bool(p.get("playing")) and p.is_inside_tree():
		if on:
			p.call("play")
		else:
			p.call("stop")


## Chame todo frame. rpm01 = (rpm - marcha lenta)/(corte - marcha lenta); throttle 0..1; boost 0..1;
## engine_health 0..1 (1 = saudavel).
func update(dt: float, rpm01: float, throttle: float, boost: float, engine_health: float = 1.0, speed: float = 0.0) -> void:
	boost = clampf(boost, 0.0, 1.0)                                # T-178: boost fora de 0..1 dava guincho agudo
	_health = engine_health
	_smooth_throttle = lerpf(_smooth_throttle, throttle, minf(6.0 * dt, 1.0))
	_smooth_rpm = lerpf(_smooth_rpm, rpm01, minf(10.0 * dt, 1.0))
	if synth_boost:
		var target: float = 1.0 if throttle > 0.6 and rpm01 > 0.45 else 0.0
		_synth = move_toward(_synth, target, dt / (1.0 if target > _synth else 0.6))
		boost = maxf(boost, _synth)
	if positional:
		_update_doppler(dt)
	if _voice != "":
		_update_diesel(dt, throttle, speed)
	else:
		_update_legacy(throttle, speed)
	if turbo_set != "":
		_set_layer(turbo_set, boost * 0.75, turbo_pitch_for(boost) * _turbo_pitch, -6.0 + _turbo_db)
	_set_layer("engine_damaged_rattle", clampf((0.65 - engine_health) / 0.65, 0.0, 1.0) * 0.9, 1.0 + (1.0 - engine_health) * 0.1, -4.0)


## Loops do ElevenLabs (T-173/T-178): camadas por faixa de RPM normalizado com ajuste de tom.
func _update_legacy(throttle: float, speed: float) -> void:
	var w: Array[float] = band_weights(_smooth_rpm, _centers, _width)
	var load: float = lerpf(0.55, 1.0, _smooth_throttle)          # soltando o acelerador o motor "abaixa"
	var pitch: float = pitch_for(_smooth_rpm) * _pitch_mul
	for i in _bands.size():
		_set_layer("%s_%s" % [engine_set, _bands[i]], w[i] * load, pitch, -2.0)
	if straight_exhaust:
		_set_layer("exhaust_straight_layer", _smooth_throttle * (0.3 + 0.7 * _smooth_rpm), 0.85 + _smooth_rpm * 0.4, -5.0)
	if has_jake:
		var braking: bool = throttle < 0.05 and _smooth_rpm > 0.35 and speed > 3.0
		_set_layer("jake_brake", 0.8 if braking else 0.0, 0.9 + _smooth_rpm * 0.3, -4.0)


## T-197: diesel sintetizado. RPM real (rpm01 -> marcha lenta..corte do motor), carga ON/OFF pelo acelerador, corte
## na troca de marcha, freio-motor e escape aberto em pontos proprios, estalos ao tirar o pe (cromado cortado).
func _update_diesel(dt: float, throttle: float, speed: float) -> void:
	var rpm: float = lerpf(DieselMix.IDLE_RPM, _redline, _smooth_rpm)
	var rate: float = (rpm - _prev_rpm) / maxf(dt, 0.001) if _prev_rpm > 0.0 else 0.0
	_prev_rpm = rpm
	if DieselMix.is_shift_drop(rate, throttle):
		_shift_t = DieselMix.SHIFT_CUT_S
	_shift_t = maxf(_shift_t - dt, 0.0)
	var target: float = 0.0 if _shift_t > 0.0 else clampf(throttle, 0.0, 1.0)
	_load = move_toward(_load, target, dt * (5.0 if target > _load else 10.0))
	_jake = move_toward(_jake, 1.0 if DieselMix.jake_active(has_jake, throttle, rpm, speed) else 0.0, dt * 8.0)
	var lw: Vector2 = DieselMix.load_weights(_load)
	var pw: Array[float] = DieselMix.point_weights(rpm, DieselMix.RPM_POINTS)
	for i in DieselMix.RPM_POINTS.size():
		var r: float = DieselMix.RPM_POINTS[i]
		var p: float = DieselMix.point_pitch(rpm, r) * _pitch_mul
		_set_layer(DieselMix.layer(_voice, "on", r, _src), pw[i] * lw.x, p, _gain_db)
		_set_layer(DieselMix.layer(_voice, "off", r, _src), pw[i] * lw.y * (1.0 - _jake), p, _gain_db)
	if proc != null:                                     # T-220: diesel procedural segue o RPM continuo
		proc.target_rpm = rpm
		proc.target_load = _load
		proc.health = _health
		proc.master = 1.0 - _jake * (1.0 - _load)
	if _open_db > -60.0:
		var ow: Array[float] = DieselMix.point_weights(rpm, DieselMix.OPEN_POINTS)
		for i in DieselMix.OPEN_POINTS.size():
			var r2: float = DieselMix.OPEN_POINTS[i]
			_set_layer(DieselMix.layer(_voice, "open", r2), ow[i] * lw.x, DieselMix.point_pitch(rpm, r2), _gain_db + _open_db)
	if has_jake:
		var jw: Array[float] = DieselMix.point_weights(rpm, DieselMix.JAKE_POINTS)
		for i in DieselMix.JAKE_POINTS.size():
			var r3: float = DieselMix.JAKE_POINTS[i]
			_set_layer(DieselMix.layer(_voice, "jake", r3), jw[i] * _jake, DieselMix.point_pitch(rpm, r3), _gain_db - 2.0)
	if _pops:
		if throttle < 0.05 and _prev_throttle > 0.5 and rpm > 1300.0:
			_pop_t = 0.9
		_pop_t = maxf(_pop_t - dt, 0.0)
		if _pop_t > 0.0 and _pop_rng.randf() < dt * 7.0:
			_fire_pop()
	_prev_throttle = throttle


func _fire_pop() -> void:
	var p: Node = _players.get("syn_exh_pop_%d" % _pop_rng.randi_range(1, 2))
	if p == null or not p.is_inside_tree():
		return
	p.set("volume_db", _gain_db - 3.0 - _pop_rng.randf() * 6.0)
	p.set("pitch_scale", _pop_rng.randf_range(0.85, 1.15) * _doppler)
	p.call("play")


## Doppler dos outros caminhoes (T-197): pela velocidade com que a distancia ate a camera muda. Feito a mao (nao pelo
## doppler do Godot) para ignorar cortes de camera (salto grande = sem Doppler naquele quadro) e limitar a +-6%.
func _update_doppler(dt: float) -> void:
	var host: Node3D = get_parent() as Node3D
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if host == null or cam == null or dt <= 0.0:
		return
	var d: float = host.global_position.distance_to(cam.global_position)
	var target: float = 1.0
	if _prev_dist >= 0.0:
		var radial: float = (d - _prev_dist) / dt
		if absf(radial) < 90.0:
			target = DieselMix.doppler(radial)
	_prev_dist = d
	_doppler = lerpf(_doppler, target, minf(5.0 * dt, 1.0))


## "pssh" do turbo ao soltar o acelerador com boost cheio (o do perfil do escapamento, se houver).
func blowoff() -> void:
	if _blowoffs.is_empty():
		return
	_blowoff_idx = (_blowoff_idx + 1) % _blowoffs.size()
	get_node("/root/AudioBus").play_sfx(String(_blowoffs[_blowoff_idx]), -4.0, randf_range(0.95, 1.05))
