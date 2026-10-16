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
const PASSING_FILL_RATE: float = 0.04   # por segundo, em velocidade alta (> 70% da maxima)
const PASSING_DRAIN_RATE: float = 0.35  # por segundo enquanto o botao esta apertado
const DRAFT_BOOST: float = 0.2          # +20% de tracao com vacuo total
const DRAFT_SPEED_BONUS: float = 2.0    # m/s acima da velocidade maxima com vacuo total

var z: float = 0.0
var x: float = 0.0
var speed: float = 0.0
var lateral_vel: float = 0.0
var rpm: float = 700.0
var gear: int = 1
var boost: float = 0.0
var mass: float = BASE_MASS + DEFAULT_CARGO
var loadout: Array[Dictionary] = []     # pecas instaladas (ver DamageModel.make_part), da mais externa para a interna
var systems: Dictionary = {"engine": 100.0, "steering": 100.0, "cargo": 100.0}   # saude 0..100
var steer_pull: float = 0.0             # puxao constante da direcao danificada (x/s)
var steer_pull_dir: float = 1.0
var engine: EngineModel = EngineModel.new()
var offroad: bool = false
var is_bot: bool = false
var passing_charge: float = 0.0         # barra de Passing 0..1
var passing_active: bool = false        # buzinando/pressionando agora
var draft: float = 0.0                  # 0..1: efeito do vacuo (atras de outro veiculo)
var overtakes: int = 0
var finish_time: float = -1.0
var finish_position: int = 0


func set_mass(parts_kg: float = 0.0, cargo_kg: float = DEFAULT_CARGO) -> void:
	mass = BASE_MASS + cargo_kg + parts_kg


func set_loadout(parts: Array[Dictionary]) -> void:
	loadout = parts
	var w: float = 0.0
	for p in parts:
		p["broken"] = false
		w += float(p["weight"])
	set_mass(w)
	refresh_damage_effects()


func cargo_integrity() -> float:
	return float(systems["cargo"]) / 100.0


## Recalcula os efeitos mecanicos do dano (potencia do motor, puxao da direcao).
func refresh_damage_effects() -> void:
	engine.power_factor = 0.5 + 0.5 * float(systems["engine"]) / 100.0
	steer_pull = 0.1 * (1.0 - float(systems["steering"]) / 100.0)


func grip() -> float:
	return pow(MASS_REF / mass, 0.3)


func step(dt: float, cmd: Commands, track: Track) -> void:
	# 1) longitudinal: tracao - arrasto - rolamento - freio - ladeira
	var force: float = engine.traction_force(cmd.throttle, speed - draft * DRAFT_SPEED_BONUS) * (1.0 + DRAFT_BOOST * draft)
	var resist: float = DRAG * speed * speed + ROLLING_RESISTANCE * mass * GRAVITY
	if speed > 0.0:
		force -= resist
	force -= cmd.brake * BRAKE_FORCE * (1.0 if speed > 0.0 else 0.0)
	var accel: float = force / mass - GRAVITY * track.hill_at(z) * 0.5
	speed = maxf(speed + accel * dt, 0.0)
	# barra de Passing: enche em alta velocidade, esvazia enquanto usada
	passing_active = cmd.passing and passing_charge > 0.02
	if passing_active:
		passing_charge = maxf(passing_charge - PASSING_DRAIN_RATE * dt, 0.0)
	elif speed > EngineModel.MAX_SPEED * 0.7:
		passing_charge = minf(passing_charge + PASSING_FILL_RATE * dt, 1.0)
	# 2) acostamento: perde velocidade
	offroad = absf(x) > 1.0
	if offroad and speed > OFFROAD_MAX_SPEED:
		speed = maxf(speed - OFFROAD_DECEL * dt, OFFROAD_MAX_SPEED)
	# 3) lateral: direcao (limitada pela aderencia) + curva empurrando para fora
	var authority: float = STEER_SPEED * grip() * minf(speed / 8.0, 1.0)
	var target_lat: float = cmd.steer * authority
	lateral_vel += (target_lat - lateral_vel) * minf(STEER_RESPONSE * dt, 1.0)
	var push: float = -track.curve_at(z) * speed * speed * CURVE_PUSH
	x += (lateral_vel + push + steer_pull * steer_pull_dir) * dt
	x = clampf(x, -1.6, 1.6)   # limite fisico (fora do acostamento)
	# 4) avanco
	z += speed * dt
	var gr: Vector2 = engine.gear_and_rpm(speed)
	gear = int(gr.x)
	rpm = gr.y if cmd.throttle > 0.0 or speed > 1.0 else EngineModel.IDLE_RPM
