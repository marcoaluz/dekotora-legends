class_name TurnSignalAudio
extends Node
## Som da seta (pisca) do jogador (T-170). So apresentacao: le o estado do TruckSim (signal_dir, lane_changes,
## lane_refusals), nao mexe na simulacao nem na rede.
##  - Tique-taque: `turn_signal_tick` a cada vez que a lampada acende (tom normal) e apaga (tom mais grave), no
##    mesmo ritmo das lampadas e do HUD (SignalBlink). Para sozinho quando a seta apaga.
##  - Clique da alavanca: `turn_signal_switch` a cada toque em < ou > que chegou a simulacao (borda de
##    TruckSim.tap_prev: liga a seta, troca de lado, troca de faixa ou troca recusada). Nao usa lane_changes:
##    online a reconciliacao reaplica comandos e esse contador pode contar o mesmo toque duas vezes.
## Dois AudioStreamPlayer fixos no barramento SFX (volume e mudo das Opcoes valem); nenhum no novo por tique.

const TICK := "turn_signal_tick"
const SWITCH := "turn_signal_switch"
const TICK_FROM: float = 0.09          # s: o clique do rele comeca ~0,1 s depois do inicio do arquivo
const TICK_DB: float = -9.0
const TOCK_PITCH: float = 0.86         # lampada apagando: mesmo clique, mais grave
const SWITCH_DB: float = -7.0

var ticks: int = 0                     # contadores (testes)
var tocks: int = 0
var clicks: int = 0
var _blink := SignalBlink.new()
var _tick: AudioStreamPlayer
var _switch: AudioStreamPlayer
var _prev_tap: int = 0


## `parent` = no onde ficam os players. `tick`/`switch` = streams (null = mudo; o estado continua sendo contado).
func setup(parent: Node, tick: AudioStream, switch: AudioStream) -> void:
	name = "TurnSignalAudio"
	parent.add_child(self)
	_tick = _make(tick)
	_switch = _make(switch)


## Atalho da corrida: pega os streams no AudioBus.
func setup_from_bus(parent: Node, truck: TruckSim) -> void:
	var bus: Node = parent.get_node("/root/AudioBus")
	setup(parent, bus.stream(TICK) if RaceAudio.has_sound(TICK) else null, bus.stream(SWITCH) if RaceAudio.has_sound(SWITCH) else null)
	sync_to(truck)


## Comeca do estado atual sem tocar o clique (direcao que ja estava segurada).
func sync_to(t: TruckSim) -> void:
	_prev_tap = t.tap_prev


func _make(s: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = s
	add_child(p)
	return p


## Chame todo quadro com o caminhao do jogador.
func update(t: TruckSim) -> void:
	step(t.shown_signal(), t.tap_prev, SignalBlink.now())    # T-239: tambem durante a troca de faixa


## Logica pura (testavel com relogio proprio). `tap_dir` = direcao segurada no ultimo passo (-1/0/+1).
func step(signal_dir: int, tap_dir: int, now_s: float) -> void:
	var tapped: bool = tap_dir != 0 and tap_dir != _prev_tap
	_prev_tap = tap_dir
	if tapped:
		clicks += 1
		_play(_switch, 0.0, SWITCH_DB, 1.0)
	match _blink.update(signal_dir, now_s):
		SignalBlink.Edge.LIT:
			ticks += 1
			_play(_tick, TICK_FROM, TICK_DB, 1.0)
		SignalBlink.Edge.DARK:
			tocks += 1
			_play(_tick, TICK_FROM, TICK_DB - 2.0, TOCK_PITCH)


func lit() -> bool:
	return _blink.lit


func _play(p: AudioStreamPlayer, from: float, db: float, pitch: float) -> void:
	if p == null or p.stream == null or not p.is_inside_tree():
		return
	p.volume_db = db
	p.pitch_scale = pitch
	p.play(from)


## Fim da corrida / pausa longa: cala sem tocar o "taque" final.
func silence() -> void:
	for p in [_tick, _switch]:
		if p != null:
			(p as AudioStreamPlayer).stop()
