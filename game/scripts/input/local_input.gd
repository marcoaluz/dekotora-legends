class_name LocalInput
extends RefCounted
## Le teclado e controle (Input Map) e devolve um Commands. Os botoes de toque entram na P22
## pelo mesmo caminho: TouchControls escreve em `touch_*` e este arquivo mistura tudo.
## Controle por faixas (ATB-1): `steer` sai como -1/0/+1 SEGURADO; a simulacao detecta o toque
## (borda 0 -> lado): 1o toque liga a seta, 2o toque no mesmo lado executa a troca.
## Buzina (T-144): tecla H (acao "horn") ou botao BUZINA na tela.

var touch_steer: float = 0.0
var touch_throttle: float = 0.0
var touch_brake: float = 0.0
var touch_passing: bool = false
var touch_horn: bool = false
var touch_look: int = 0                 # T-241: RaceLook.Dir from the touch eye button (camera only, not a command)
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
	var horn: bool = touch_horn or (InputMap.has_action("horn") and Input.is_action_pressed("horn"))
	return Commands.make(steer, throttle, brake, passing, horn)


## T-241: where the player wants to look (RaceLook.Dir). Not part of Commands: only the local camera uses it.
## Keyboard Q / E / X, controller right stick (left / right / down) + R3 / RB, touch eye button.
func look_dir() -> int:
	if touch_look != 0:
		return touch_look
	if not InputMap.has_action("look_back"):
		return 0
	return RaceLook.resolve(Input.get_action_strength("look_back"), Input.get_action_strength("look_left"),
			Input.get_action_strength("look_right"))
