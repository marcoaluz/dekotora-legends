class_name Commands
extends RefCounted
## Comandos de um caminhao em um tick. Vem do jogador (toque/teclado/controle), de um bot
## ou da rede. A simulacao so conhece isto: nunca le Input.

var steer: float = 0.0      # -1 (esquerda) .. +1 (direita)
var throttle: float = 0.0   # 0..1
var brake: float = 0.0      # 0..1
var passing: bool = false   # botao Passing
var horn: bool = false      # buzina segurada (T-144): so som + o transito da frente abre caminho


static func make(steer_: float = 0.0, throttle_: float = 0.0, brake_: float = 0.0, passing_: bool = false, horn_: bool = false) -> Commands:
	var c := Commands.new()
	c.steer = clampf(steer_, -1.0, 1.0)
	c.throttle = clampf(throttle_, 0.0, 1.0)
	c.brake = clampf(brake_, 0.0, 1.0)
	c.passing = passing_
	c.horn = horn_
	return c


func duplicate_cmd() -> Commands:
	return Commands.make(steer, throttle, brake, passing, horn)
