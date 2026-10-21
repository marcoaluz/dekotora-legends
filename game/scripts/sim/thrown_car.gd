class_name ThrownCar
extends RefCounted
## Carro do transito arremessado por um caminhao (T-141). So numeros (roda igual no servidor):
## fora de controle o carro escorrega para a frente e de lado, gira, quica e bate na mureta.
## T-183: depois disso ele NAO volta a andar: e um carro acidentado (Wreck). O atrito segue freando o deslize,
## o giro e o deslize lateral ate o carro parar, e ele fica no angulo em que parou (nao endireita).
## A forca do arremesso vem da Collision (troca de momento com o caminhao).

const DECEL: float = 6.5               # m/s^2 escorregando para a frente
const SKID_DECEL: float = 9.0          # T-183: m/s^2 depois do tempo fora de controle (carro batido arrastando, de lado)
const SIDE_DECEL: float = 1.1          # x/s^2 atrito do deslize lateral
const SPIN_DECEL: float = 3.5          # rad/s^2
const WALL_X: float = 1.55             # x das muretas (o caminhao vai ate 1,6)
const WALL_BOUNCE: float = 0.3         # fracao da velocidade lateral que volta ao bater na mureta
const GROUND_BOUNCE: float = 0.3


static func step(c: TrafficSim.Car, dt: float) -> void:
	c.out_t = maxf(c.out_t - dt, 0.0)
	c.speed = maxf(c.speed - (DECEL if c.out_t > 0.0 else SKID_DECEL) * dt, 0.0)
	c.z += c.speed * dt
	c.x += c.vx * dt
	c.vx = move_toward(c.vx, 0.0, SIDE_DECEL * dt)
	var r: Rect2 = Wreck.footprint(c)      # T-183: girado, o carro ocupa mais largura (nao entra na mureta)
	var over: float = maxf(r.end.y - WALL_X, 0.0) - maxf(-WALL_X - r.position.y, 0.0)
	if over != 0.0:
		c.x -= over
		if signf(c.vx) == signf(over):
			c.vx = -c.vx * WALL_BOUNCE
		c.yaw_rate *= 0.6
	c.yaw += c.yaw_rate * dt
	c.yaw_rate = move_toward(c.yaw_rate, 0.0, SPIN_DECEL * dt)
	if c.yaw_rate == 0.0:
		c.yaw = wrapf(c.yaw, -PI, PI)  # parado de girar: angulo final entre -180 e 180 graus (nao endireita)
	if c.y > 0.0 or c.vy > 0.0:
		c.vy -= 9.8 * dt
		c.y += c.vy * dt
		if c.y <= 0.0:
			c.y = 0.0
			c.vy = -c.vy * GROUND_BOUNCE if c.vy < -2.0 else 0.0
