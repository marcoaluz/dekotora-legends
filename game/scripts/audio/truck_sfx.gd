class_name TruckSfx
extends Node
## Sons de um caminhao que vem do ESTADO da simulacao (T-144): buzina segurada e freada forte.
## Um por caminhao. O do jogador toca sem posicao (AudioStreamPlayer); os outros sao AudioStreamPlayer3D presos
## ao caminhao (o volume cai com a distancia ate a camera, inclusive na corrida online).
##  - Buzina: basica (horn_air_basic) = continua enquanto segura (duas vozes em cruz pulando o comeco e o fim do
##    arquivo); musical (horn_musical_1/2, da peca instalada) = toca a melodia, e para quando solta.
##  - Freada forte: brake_squeal com volume pela intensidade (para ao soltar) e air_brake_hiss ao soltar, mais
##    alto quanto mais velocidade perdeu.

## Janela de loop (volta para / comeca a outra voz) de cada buzina: HornCatalog.loop_window (T-173).
const HORN_FADE: float = 0.12             # s de cruzamento / de soltar
const HORN_DB: float = -3.0
const BRAKE_DB: float = -4.0
const HISS_MIN_LOST: float = 4.0          # m/s perdidos para valer o "pssh" ao soltar

var horn_name: String = "horn_air_basic"
var positional: bool = false
var _horn: Array = []                     # 2 vozes
var _voice: int = 0
var _horn_on: bool = false
var _squeal: Node
var _hiss: Node
var _was_braking: bool = false
var _squeal_gain: float = 0.0
var _fade: Array[float] = [0.0, 0.0]      # alvo de volume linear por voz


## `parent` = no do caminhao (o som 3D segue o caminhao) ou, para o jogador (`player`, sem posicao), qualquer no.
func setup(parent: Node, player: bool, horn: String) -> void:
	positional = not player
	horn_name = horn if horn != "" else "horn_air_basic"
	parent.add_child(self)
	var audio: Node = get_node("/root/AudioBus")
	var hs: AudioStream = audio.stream(horn_name)
	for k in 2:
		var p: Node = _make(hs, 22.0, 260.0)
		_horn.append(p)
	_squeal = _make(audio.stream("brake_squeal"), 14.0, 150.0)
	_hiss = _make(audio.stream("air_brake_hiss"), 14.0, 150.0)


func _make(s: AudioStream, unit: float, max_d: float) -> Node:
	var p: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = unit
		p3.max_distance = max_d
		p3.bus = "SFX"
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		p = p2
	p.set("stream", s)
	p.set("volume_db", -80.0)
	add_child(p)
	return p


func is_musical() -> bool:
	return HornCatalog.is_musical(horn_name)


func horn_playing() -> bool:
	return _horn_on


## Chame todo quadro com o estado do caminhao.
func update(t: TruckSim, dt: float) -> void:
	_update_horn(t.horn, dt)
	_update_brake(t, dt)


func _update_horn(held: bool, dt: float) -> void:
	if held and not _horn_on:
		_horn_on = true
		_voice = 0
		_start_voice(0, 0.0)
		_fade = [1.0, 0.0]
	elif not held and _horn_on:
		_horn_on = false
		_fade = [0.0, 0.0]
	if _horn_on and not is_musical():
		var cur: Node = _horn[_voice]
		var win: Array = HornCatalog.loop_window(horn_name)       # T-173: janela de loop medida por buzina
		if float(cur.call("get_playback_position")) >= float(win[1]) and _fade[_voice] > 0.0:
			var nxt: int = 1 - _voice
			_start_voice(nxt, float(win[0]))
			_fade[_voice] = 0.0
			_fade[nxt] = 1.0
			_voice = nxt
	for k in 2:
		var p: Node = _horn[k]
		if not bool(p.get("playing")):
			continue
		var lin: float = db_to_linear(float(p.get("volume_db")) - HORN_DB)
		lin = move_toward(lin, _fade[k], dt / HORN_FADE)
		if lin <= 0.001 and _fade[k] <= 0.0:
			p.call("stop")
			p.set("volume_db", -80.0)
		else:
			p.set("volume_db", linear_to_db(maxf(lin, 0.0001)) + HORN_DB)


func _start_voice(k: int, from: float) -> void:
	var p: Node = _horn[k]
	if p.get("stream") == null:
		return
	p.set("volume_db", (-30.0 if from > 0.0 else 0.0) + HORN_DB)
	p.call("play", from)


func _update_brake(t: TruckSim, dt: float) -> void:
	if _squeal.get("stream") == null:
		return
	if t.hard_braking and not _was_braking:
		_squeal_gain = 1.0
		_squeal.set("pitch_scale", lerpf(0.92, 1.08, clampf(t.brake_speed0 / 33.0, 0.0, 1.0)))
		_squeal.call("play")
	if t.hard_braking:
		_squeal_gain = maxf(_squeal_gain, t.brake_intensity)
		_squeal.set("volume_db", linear_to_db(clampf(0.35 + 0.65 * t.brake_intensity, 0.05, 1.0)) + BRAKE_DB)
		if not bool(_squeal.get("playing")):       # freada longa: o chiado continua
			_squeal.call("play", 0.3)
	elif bool(_squeal.get("playing")):
		_squeal_gain = maxf(_squeal_gain - dt * 6.0, 0.0)
		_squeal.set("volume_db", linear_to_db(maxf(_squeal_gain, 0.0001)) + BRAKE_DB)
		if _squeal_gain <= 0.0:
			_squeal.call("stop")
	if _was_braking and not t.hard_braking and t.brake_lost >= HISS_MIN_LOST and _hiss.get("stream") != null:
		_hiss.set("volume_db", linear_to_db(clampf(t.brake_lost / 20.0, 0.25, 1.0)) - 3.0)
		_hiss.call("play")
	_was_braking = t.hard_braking
