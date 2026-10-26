class_name EngineSynthVoice
extends AudioStreamPlayer
## T-220: plays the procedural diesel (DieselSynth) through an AudioStreamGenerator. The excitation is made here in
## GDScript (cheap per sample); the exhaust resonances run as bus effects on the "EngineSynth" bus (C++):
##   high-pass 35 Hz -> EQ (boom, mid, presence; 21 bands PC / 10 bands light) -> muffler low-pass (opens with rpm and
##   load) -> grit (distortion) -> pipe echo (PC only) -> crossover low-pass (only in "mix" mode).
## Client only: EngineAudio creates it for the player's truck. Never runs on the headless server (no window = no fill).

const BUS: String = "EngineSynth"
const EQ21_HZ: Array[float] = [22.0, 32.0, 44.0, 63.0, 90.0, 125.0, 175.0, 250.0, 350.0, 500.0, 700.0, 1000.0, 1400.0,
	2000.0, 2800.0, 4000.0, 5600.0, 8000.0, 11000.0, 16000.0, 22000.0]
const EQ10_HZ: Array[float] = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]
enum Fx { HP, EQ, LP, DRIVE, ECHO, CROSS }

var synth: DieselSynth
var voice: EngineVoiceDef
var light: bool = false
var target_rpm: float = 700.0
var target_load: float = 0.0
var health: float = 1.0
var redline: float = 2400.0
## 0..1 overall (EngineAudio fades it out when the jake brake loops take over).
var master: float = 1.0
var base_db: float = 0.0
## CPU used by the GDScript part (ms per call of _fill), for the test scene and the log.
var cpu_ms_avg: float = 0.0
var cpu_ms_max: float = 0.0
var _fx: Dictionary = {}                 # Fx -> effect index on the bus
var _gen: AudioStreamGenerator
var _log: bool = "--synth-log" in OS.get_cmdline_user_args()   # imprime SYNTH_CPU a cada 5 s (celular: logcat)
var _log_t: float = 0.0


## light = phone version. send = bus the synth goes to (Engine / EngineCab). crossover_hz > 0 = mix mode.
func configure(v: EngineVoiceDef, light_: bool, send: String, crossover_hz: float, cfg: EngineAudioConfig) -> void:
	voice = v
	light = light_
	var rate: int = cfg.rate_light if light else cfg.rate_pc
	synth = DieselSynth.new(v, float(rate))
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = rate
	_gen.buffer_length = cfg.buffer_s
	stream = _gen
	base_db = v.level_db + cfg.synth_db
	volume_db = base_db
	setup_bus(v, light, send, crossover_hz)
	bus = BUS


## Builds (or rebuilds) the EngineSynth bus for a voice (the test scene calls it again when sliders move).
func setup_bus(v: EngineVoiceDef, light_: bool, send: String, crossover_hz: float) -> void:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
	while AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.remove_bus_effect(idx, 0)
	AudioServer.set_bus_send(idx, send if AudioServer.get_bus_index(send) >= 0 else "Master")
	_fx.clear()
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 35.0
	_add(idx, Fx.HP, hp)
	var bands: Array[float] = EQ10_HZ if light_ else EQ21_HZ
	var eq: AudioEffectEQ = AudioEffectEQ10.new() if light_ else AudioEffectEQ21.new()
	for b in bands.size():
		eq.set_band_gain_db(b, eq_gain_db(v, bands[b]))
	_add(idx, Fx.EQ, eq)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = v.lp_idle_hz
	lp.resonance = 0.55
	_add(idx, Fx.LP, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_ATAN
	dist.drive = clampf(v.drive, 0.0, 0.95)
	dist.post_gain = -2.0
	_add(idx, Fx.DRIVE, dist)
	if not light_ and v.echo_ms > 0.5:
		var dl := AudioEffectDelay.new()
		dl.dry = 1.0
		dl.tap1_active = true
		dl.tap1_delay_ms = v.echo_ms
		dl.tap1_level_db = v.echo_db
		dl.tap1_pan = 0.0
		dl.tap2_active = false
		dl.feedback_active = true
		dl.feedback_delay_ms = v.echo_ms
		dl.feedback_level_db = v.echo_db - 3.0
		_add(idx, Fx.ECHO, dl)
	if crossover_hz > 0.0:
		var cross := AudioEffectLowPassFilter.new()
		cross.cutoff_hz = crossover_hz
		cross.resonance = 0.5
		_add(idx, Fx.CROSS, cross)


func _add(bus_idx: int, key: int, fx: AudioEffect) -> void:
	AudioServer.add_bus_effect(bus_idx, fx)
	_fx[key] = AudioServer.get_bus_effect_count(bus_idx) - 1


## Gain of the exhaust resonances at a frequency (dB): three bells on a log axis. Pure (tests, analysis).
static func eq_gain_db(v: EngineVoiceDef, hz: float) -> float:
	var g: float = 0.0
	for p in [[v.boom_hz, v.boom_db, 0.55], [v.mid_hz, v.mid_db, 0.7], [v.presence_hz, v.presence_db, 0.9]]:
		var o: float = log(hz / float(p[0])) / log(2.0) / float(p[2])
		g += float(p[1]) * exp(-0.5 * o * o)
	return clampf(g, -18.0, 18.0)


## Muffler low-pass cutoff: opens with rpm (idle -> redline) and a bit with load.
static func lp_cutoff(v: EngineVoiceDef, rpm: float, redline: float, load: float) -> float:
	var r01: float = clampf((rpm - DieselSynth.IDLE_RPM) / maxf(redline - DieselSynth.IDLE_RPM, 1.0), 0.0, 1.0)
	return lerpf(v.lp_idle_hz, v.lp_high_hz, r01) * (0.85 + 0.15 * clampf(load, 0.0, 1.0))


func _ready() -> void:
	start()


func start() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	play()
	_fill()
	if _log:
		print("SYNTH_START %s %d Hz voz %s" % ["leve" if light else "PC", int(synth.mix_rate), voice.id])


func _process(dt: float) -> void:
	if not playing:
		return
	if _log:
		_log_t += dt
		if _log_t >= 5.0:
			_log_t = 0.0
			print("SYNTH_CPU %s %d Hz: %.3f ms/quadro (pico %.3f)" % ["leve" if light else "PC", int(synth.mix_rate), cpu_ms_avg, cpu_ms_max])
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx >= 0 and _fx.has(Fx.LP):
		var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(idx, int(_fx[Fx.LP])) as AudioEffectLowPassFilter
		if lp != null:
			lp.cutoff_hz = lp_cutoff(voice, target_rpm, redline, target_load)
	volume_db = base_db + linear_to_db(maxf(master, 0.0001)) if master > 0.002 else -80.0
	_fill()


func _fill() -> void:
	var pb: AudioStreamGeneratorPlayback = get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n: int = pb.get_frames_available()
	if n <= 0:
		return
	var t0: int = Time.get_ticks_usec()
	var mono: PackedFloat32Array = synth.render(n, target_rpm, target_load, health)
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var s: float = mono[i]
		buf[i] = Vector2(s, s)
	pb.push_buffer(buf)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	cpu_ms_avg = lerpf(cpu_ms_avg, ms, 0.05)
	cpu_ms_max = maxf(cpu_ms_max * 0.995, ms)
