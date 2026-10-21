class_name EngineAudio
extends Node
## Som do motor em camadas (GDD "Som do motor em camadas", P51): loops por motor (idle/low/mid/high, ou
## idle/mid/high nos perfis de escapamento da T-173) misturados por RPM com ajuste de tom, camada do turbo
## seguindo o boost, "pssh" ao soltar o acelerador com turbo cheio, freio-motor, escape direto e chacoalho de dano.
## Use: setup_spec(EngineSounds.spec("eng_v8", "turbo_single", "exh_stack"), jake) e update(...) a cada frame.
## setup("i6_std", "turbo_single", true, false) continua valendo (formato antigo, sem perfil de escapamento).

const BANDS: Array[String] = ["idle", "low", "mid", "high"]
const CENTERS: Array[float] = [0.0, 0.3, 0.62, 0.95]       # rpm normalizado (0..1) onde cada camada e mais forte
const WIDTH: float = 0.34
const CENTERS_3: Array[float] = [0.0, 0.5, 0.95]            # perfis com 3 camadas (T-173)
const WIDTH_3: float = 0.5

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
	_players.clear()
	for b in _bands:
		_add_layer("%s_%s" % [engine_set, b])
	if turbo_set != "":
		_add_layer(turbo_set)
	if straight_exhaust:
		_add_layer("exhaust_straight_layer")
	if has_jake:
		_add_layer("jake_brake")
	_add_layer("engine_damaged_rattle")


## Camadas tocando (testes / ferramenta de teste).
func layer_names() -> Array[String]:
	var out: Array[String] = []
	for k in _players:
		out.append(String(k))
	return out


func _add_layer(sound: String) -> void:
	var audio: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")   # vale fora da arvore tambem
	if audio == null:
		return
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
	p.volume_db = linear_to_db(clampf(weight, 0.0, 1.0)) + gain_db if weight > 0.003 else -80.0
	p.pitch_scale = pitch


## Chame todo frame. rpm01 = (rpm - marcha lenta)/(corte - marcha lenta); throttle 0..1; boost 0..1;
## engine_health 0..1 (1 = saudavel).
func update(dt: float, rpm01: float, throttle: float, boost: float, engine_health: float = 1.0, speed: float = 0.0) -> void:
	boost = clampf(boost, 0.0, 1.0)                                # T-178: boost fora de 0..1 dava guincho agudo
	_smooth_throttle = lerpf(_smooth_throttle, throttle, minf(6.0 * dt, 1.0))
	_smooth_rpm = lerpf(_smooth_rpm, rpm01, minf(10.0 * dt, 1.0))
	if synth_boost:
		var target: float = 1.0 if throttle > 0.6 and rpm01 > 0.45 else 0.0
		_synth = move_toward(_synth, target, dt / (1.0 if target > _synth else 0.6))
		boost = maxf(boost, _synth)
	var w: Array[float] = band_weights(_smooth_rpm, _centers, _width)
	var load: float = lerpf(0.55, 1.0, _smooth_throttle)          # soltando o acelerador o motor "abaixa"
	var pitch: float = pitch_for(_smooth_rpm) * _pitch_mul
	for i in _bands.size():
		_set_layer("%s_%s" % [engine_set, _bands[i]], w[i] * load, pitch, -2.0)
	if turbo_set != "":
		_set_layer(turbo_set, boost * 0.75, turbo_pitch_for(boost) * _turbo_pitch, -6.0 + _turbo_db)
	if straight_exhaust:
		_set_layer("exhaust_straight_layer", _smooth_throttle * (0.3 + 0.7 * _smooth_rpm), 0.85 + _smooth_rpm * 0.4, -5.0)
	if has_jake:
		var braking: bool = throttle < 0.05 and _smooth_rpm > 0.35 and speed > 3.0
		_set_layer("jake_brake", 0.8 if braking else 0.0, 0.9 + _smooth_rpm * 0.3, -4.0)
	_set_layer("engine_damaged_rattle", clampf((0.65 - engine_health) / 0.65, 0.0, 1.0) * 0.9, 1.0 + (1.0 - engine_health) * 0.1, -4.0)


## "pssh" do turbo ao soltar o acelerador com boost cheio (o do perfil do escapamento, se houver).
func blowoff() -> void:
	if _blowoffs.is_empty():
		return
	_blowoff_idx = (_blowoff_idx + 1) % _blowoffs.size()
	get_node("/root/AudioBus").play_sfx(String(_blowoffs[_blowoff_idx]), -4.0, randf_range(0.95, 1.05))
