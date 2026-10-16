class_name EngineAudio
extends Node
## Som do motor em camadas (GDD "Som do motor em camadas", P51): 4 loops por motor (idle/low/mid/high)
## misturados por RPM com ajuste de tom, camada do turbo seguindo o boost, "pssh" ao soltar o
## acelerador com turbo cheio, freio-motor, escape direto e chacoalho de dano.
## Use: setup("i6_std", "turbo_single", true, false) e update(...) a cada frame.

const BANDS: Array[String] = ["idle", "low", "mid", "high"]
const CENTERS: Array[float] = [0.0, 0.3, 0.62, 0.95]       # rpm normalizado (0..1) onde cada camada e mais forte
const WIDTH: float = 0.34

var engine_set: String = "i6_std"
var turbo_set: String = ""            # "turbo_single_whine" / "turbo_twin_whine" / ""
var straight_exhaust: bool = false
var has_jake: bool = false
var bus: String = "Engine"
var positional: bool = false          # true = AudioStreamPlayer3D (outros caminhoes, volume pela distancia)
var max_distance: float = 120.0

var _players: Dictionary = {}         # nome da camada -> AudioStreamPlayer(3D)
var _smooth_throttle: float = 0.0
var _smooth_rpm: float = 0.0
var _blowoff_idx: int = 0


func setup(engine_set_: String, turbo_id: String = "turbo_none", straight: bool = false, jake: bool = false, positional_: bool = false) -> void:
	engine_set = engine_set_
	turbo_set = {"turbo_single": "turbo_single_whine", "turbo_twin": "turbo_twin_whine"}.get(turbo_id, "")
	straight_exhaust = straight
	has_jake = jake
	positional = positional_
	for c in get_children():
		c.queue_free()
	_players.clear()
	for b in BANDS:
		_add_layer("%s_%s" % [engine_set, b])
	if turbo_set != "":
		_add_layer(turbo_set)
	if straight_exhaust:
		_add_layer("exhaust_straight_layer")
	if has_jake:
		_add_layer("jake_brake")
	_add_layer("engine_damaged_rattle")


func _add_layer(sound: String) -> void:
	var audio: Node = get_node("/root/AudioBus")
	var s: AudioStream = audio.stream(sound)
	if s == null:
		return
	var p: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = max_distance
		p3.unit_size = 14.0
		p3.bus = bus
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.bus = bus
		p = p2
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	_players[sound] = p
	p.play()


## Pesos das 4 camadas para um RPM normalizado (0..1). Funcao pura (testavel).
static func band_weights(rpm01: float) -> Array[float]:
	var out: Array[float] = []
	var total: float = 0.0
	for c in CENTERS:
		var w: float = clampf(1.0 - absf(rpm01 - c) / WIDTH, 0.0, 1.0)
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


func _set_layer(name: String, weight: float, pitch: float, gain_db: float = 0.0) -> void:
	var p: Node = _players.get(name)
	if p == null:
		return
	p.volume_db = linear_to_db(clampf(weight, 0.0, 1.0)) + gain_db if weight > 0.003 else -80.0
	p.pitch_scale = pitch


## Chame todo frame. rpm01 = (rpm - marcha lenta)/(corte - marcha lenta); throttle 0..1; boost 0..1;
## engine_health 0..1 (1 = saudavel).
func update(dt: float, rpm01: float, throttle: float, boost: float, engine_health: float = 1.0, speed: float = 0.0) -> void:
	_smooth_throttle = lerpf(_smooth_throttle, throttle, minf(6.0 * dt, 1.0))
	_smooth_rpm = lerpf(_smooth_rpm, rpm01, minf(10.0 * dt, 1.0))
	var w: Array[float] = band_weights(_smooth_rpm)
	var load: float = lerpf(0.55, 1.0, _smooth_throttle)          # soltando o acelerador o motor "abaixa"
	var pitch: float = pitch_for(_smooth_rpm)
	for i in BANDS.size():
		_set_layer("%s_%s" % [engine_set, BANDS[i]], w[i] * load, pitch, -2.0)
	if turbo_set != "":
		_set_layer(turbo_set, boost * 0.75, 0.8 + boost * 0.7, -6.0)
	if straight_exhaust:
		_set_layer("exhaust_straight_layer", _smooth_throttle * (0.3 + 0.7 * _smooth_rpm), 0.85 + _smooth_rpm * 0.4, -5.0)
	if has_jake:
		var braking: bool = throttle < 0.05 and _smooth_rpm > 0.35 and speed > 3.0
		_set_layer("jake_brake", 0.8 if braking else 0.0, 0.9 + _smooth_rpm * 0.3, -4.0)
	_set_layer("engine_damaged_rattle", clampf((0.65 - engine_health) / 0.65, 0.0, 1.0) * 0.9, 1.0 + (1.0 - engine_health) * 0.1, -4.0)


## "pssh" do turbo ao soltar o acelerador com boost cheio.
func blowoff() -> void:
	_blowoff_idx = 1 - _blowoff_idx
	get_node("/root/AudioBus").play_sfx("turbo_blowoff_%d" % (_blowoff_idx + 1), -4.0, randf_range(0.95, 1.05))
