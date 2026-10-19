class_name ThrownCar
extends RefCounted
## Carro do transito arremessado por um caminhao (T-141). So numeros (roda igual no servidor):
## fora de controle o carro escorrega para a frente e de lado, gira, quica e bate na mureta; quando acaba,
## o motorista escolhe a faixa mais perto e endireita o carro devagar (TrafficSim volta a dirigir).
## A forca do arremesso vem da Collision (troca de momento com o caminhao).

const DECEL: float = 6.5               # m/s^2 escorregando para a frente
const SIDE_DECEL: float = 1.1          # x/s^2 atrito do deslize lateral
const SPIN_DECEL: float = 3.5          # rad/s^2
const WALL_X: float = 1.55             # x das muretas (o caminhao vai ate 1,6)
const WALL_BOUNCE: float = 0.3         # fracao da velocidade lateral que volta ao bater na mureta
const GROUND_BOUNCE: float = 0.3
const RECOVER_YAW_RATE: float = 0.9    # rad/s voltando para a direcao da pista
const RECOVER_SPEED: float = 4.0       # m/s no maximo enquanto ainda esta torto (|yaw| > 0,1)


static func step(c: TrafficSim.Car, dt: float) -> void:
	c.out_t = maxf(c.out_t - dt, 0.0)
	c.speed = maxf(c.speed - DECEL * dt, 0.0)
	c.z += c.speed * dt
	c.x += c.vx * dt
	c.vx = move_toward(c.vx, 0.0, SIDE_DECEL * dt)
	var lim: float = WALL_X - c.width_x * 0.5
	if absf(c.x) > lim:
		c.x = signf(c.x) * lim
		c.vx = -c.vx * WALL_BOUNCE
		c.yaw_rate *= 0.6
	c.yaw += c.yaw_rate * dt
	c.yaw_rate = move_toward(c.yaw_rate, 0.0, SPIN_DECEL * dt)
	if c.y > 0.0 or c.vy > 0.0:
		c.vy -= 9.8 * dt
		c.y += c.vy * dt
		if c.y <= 0.0:
			c.y = 0.0
			c.vy = -c.vy * GROUND_BOUNCE if c.vy < -2.0 else 0.0
	if c.out_t <= 0.0 and c.y <= 0.0:
		c.yaw = wrapf(c.yaw, -PI, PI)
		c.yaw_rate = 0.0
		c.vx = 0.0
		var best: int = 0
		for l in TrafficSim.LANES.size():
			if absf(TrafficSim.LANES[l] - c.x) < absf(TrafficSim.LANES[best] - c.x):
				best = l
		c.lane = best
		c.timer = 6.0
