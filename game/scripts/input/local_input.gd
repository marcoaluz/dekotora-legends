class_name LocalInput
extends RefCounted
## Le teclado e controle (Input Map) e devolve um Commands. Os botoes de toque entram na P22
## pelo mesmo caminho: TouchControls escreve em `touch_*` e este arquivo mistura tudo.
## Controle por faixas (ATB-1): `steer` sai como -1/0/+1 SEGURADO; a simulacao detecta o toque
## (borda 0 -> lado): 1o toque liga a seta, 2o toque no mesmo lado executa a troca.

var touch_steer: float = 0.0
var touch_throttle: float = 0.0
var touch_brake: float = 0.0
var touch_passing: bool = false
const MIN_HOLD_MS: int = 70             # um toque curto dura ao menos 2 passos da simulacao (30/s)
var _latch_dir: int = 0
var _latch_until: int = 0


func poll() -> Commands:
	var steer: float = Input.get_axis("steer_left", "steer_right")
	if absf(touch_steer) > absf(steer):
		steer = touch_steer
	steer = 0.0 if absf(steer) < 0.5 else signf(steer)
	var now: int = Time.get_ticks_msec()
	if steer != 0.0:
		if int(steer) != _latch_dir or now >= _latch_until:
			_latch_until = now + MIN_HOLD_MS
		_latch_dir = int(steer)
	elif _latch_dir != 0 and now < _latch_until:
		steer = float(_latch_dir)           # solta rapido demais: segura o resto do tempo minimo
	else:
		_latch_dir = 0
	var throttle: float = maxf(Input.get_action_strength("throttle"), touch_throttle)
	var brake: float = maxf(Input.get_action_strength("brake"), touch_brake)
	var passing: bool = Input.is_action_pressed("passing") or touch_passing
	return Commands.make(steer, throttle, brake, passing)
