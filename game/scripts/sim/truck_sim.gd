class_name TruckSim
extends RefCounted
## Fisica de um caminhao no modelo de mundo pseudo-3D (z ao longo da pista, x lateral -1..+1).
## Puro calculo: recebe Commands + dt, atualiza numeros. Sem nos, sem Input, sem audio.

const GRAVITY: float = 9.8
const ROLLING_RESISTANCE: float = 0.01
const DRAG: float = 2.0                 # N por (m/s)^2
const BRAKE_FORCE: float = 60000.0      # N
const OFFROAD_MAX_SPEED: float = 14.0   # m/s no acostamento
const OFFROAD_DECEL: float = 8.0        # m/s^2 acima desse limite
const CURVE_PUSH: float = 7.9e-4        # empurrao da curva: x/s por (m/s)^2 por unidade de curva
const STEER_SPEED: float = 1.6          # x/s de autoridade maxima de direcao
const STEER_RESPONSE: float = 6.0
const MASS_REF: float = 12000.0
const BASE_MASS: float = 8000.0
const DEFAULT_CARGO: float = 4000.0
const WIDTH_X: float = 0.35             # largura do caminhao em unidades de x

var z: float = 0.0
var x: float = 0.0
var speed: float = 0.0
var lateral_vel: float = 0.0
var rpm: float = 700.0
var gear: int = 1
var boost: float = 0.0
var mass: float = BASE_MASS + DEFAULT_CARGO
var damage: Dictionary = {}             # id da peca/sistema -> durabilidade atual (P32)
var engine: EngineModel = EngineModel.new()
var offroad: bool = false


func set_mass(parts_kg: float = 0.0, cargo_kg: float = DEFAULT_CARGO) -> void:
	mass = BASE_MASS + cargo_kg + parts_kg


func grip() -> float:
	return pow(MASS_REF / mass, 0.3)


func step(dt: float, cmd: Commands, track: Track) -> void:
	# 1) longitudinal: tracao - arrasto - rolamento - freio - ladeira
	var force: float = engine.traction_force(cmd.throttle, speed)
	var resist: float = DRAG * speed * speed + ROLLING_RESISTANCE * mass * GRAVITY
	if speed > 0.0:
		force -= resist
	force -= cmd.brake * BRAKE_FORCE * (1.0 if speed > 0.0 else 0.0)
	var accel: float = force / mass - GRAVITY * track.hill_at(z) * 0.5
	speed = maxf(speed + accel * dt, 0.0)
	# 2) acostamento: perde velocidade
	offroad = absf(x) > 1.0
	if offroad and speed > OFFROAD_MAX_SPEED:
		speed = maxf(speed - OFFROAD_DECEL * dt, OFFROAD_MAX_SPEED)
	# 3) lateral: direcao (limitada pela aderencia) + curva empurrando para fora
	var authority: float = STEER_SPEED * grip() * minf(speed / 8.0, 1.0)
	var target_lat: float = cmd.steer * authority
	lateral_vel += (target_lat - lateral_vel) * minf(STEER_RESPONSE * dt, 1.0)
	var push: float = -track.curve_at(z) * speed * speed * CURVE_PUSH
	x += (lateral_vel + push) * dt
	x = clampf(x, -1.6, 1.6)   # limite fisico (fora do acostamento)
	# 4) avanco
	z += speed * dt
	var gr: Vector2 = engine.gear_and_rpm(speed)
	gear = int(gr.x)
	rpm = gr.y if cmd.throttle > 0.0 or speed > 1.0 else EngineModel.IDLE_RPM
