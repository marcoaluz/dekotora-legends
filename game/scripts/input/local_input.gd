class_name LocalInput
extends RefCounted
## Le teclado e controle (Input Map) e devolve um Commands. Os botoes de toque entram na P22
## pelo mesmo caminho: TouchControls escreve em `touch_*` e este arquivo mistura tudo.

var touch_steer: float = 0.0
var touch_throttle: float = 0.0
var touch_brake: float = 0.0
var touch_passing: bool = false
var tilt_steer: float = 0.0       # acelerometro (P22)


func poll() -> Commands:
	tilt_steer = Settings.tilt_steer()
	var steer: float = Input.get_axis("steer_left", "steer_right")
	if absf(touch_steer) > absf(steer):
		steer = touch_steer
	if absf(tilt_steer) > absf(steer):
		steer = tilt_steer
	var throttle: float = maxf(Input.get_action_strength("throttle"), touch_throttle)
	var brake: float = maxf(Input.get_action_strength("brake"), touch_brake)
	var passing: bool = Input.is_action_pressed("passing") or touch_passing
	return Commands.make(steer, throttle, brake, passing)
