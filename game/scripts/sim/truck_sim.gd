class_name TruckSim
extends RefCounted
## Fisica de um caminhao no modelo de mundo pseudo-3D (z ao longo da pista, x lateral -1..+1).
## Puro calculo: recebe Commands + dt, atualiza numeros. Sem nos, sem Input, sem audio.

const GRAVITY: float = 9.8
const ROLLING_RESISTANCE: float = 0.01
const DRAG: float = 1.5                 # N por (m/s)^2
const BRAKE_FORCE: float = 60000.0      # N
const OFFROAD_MAX_SPEED: float = 14.0   # m/s no acostamento
const OFFROAD_DECEL: float = 8.0        # m/s^2 acima desse limite
const CURVE_PUSH: float = 7.9e-4        # empurrao da curva: x/s por (m/s)^2 por unidade de curva
const STEER_SPEED: float = 1.6          # x/s de autoridade maxima de direcao (limite de aderencia nas curvas)
const STEER_RESPONSE: float = 6.0
const LANE_SIGNAL_WINDOW: float = 1.5   # s: 2o toque no mesmo lado dentro desta janela executa a troca
const LANE_CHANGE_TIME: float = 0.7     # s: duracao nominal da troca de faixa
const LANE_GAIN: float = 3.4            # 1/s: quanto o x corre atras da faixa alvo
const LANE_MAX_VEL: float = 1.3         # x/s: velocidade lateral maxima
const LANE_HOLD: float = 0.5            # aderencia lateral: define a velocidade segura nas curvas (curva 1,0 = 90 km/h)
const OVERSPEED_PUSH: float = 4.0       # quanto a curva empurra para fora acima da velocidade segura
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
var timed_out: bool = false             # o prazo de entrega acabou antes de chegar
var lane: int = Lanes.CENTER            # faixa alvo (0..4, ver Lanes)
var signal_dir: int = 0                 # seta ligada: -1 esquerda, +1 direita, 0 apagada
var signal_time: float = 0.0            # s restantes para dar o 2o toque
var lane_change_time: float = 0.0       # s restantes da troca em andamento (inclinacao visual)
var tap_prev: int = 0                   # direcao do comando anterior (detecta o toque)
var lane_changes: int = 0               # trocas executadas (testes/estatistica)
var side_hits: int = 0                  # batidas laterais (riscam murais)
var cargo_fragility: float = 1.0        # contrato: multiplica o dano na carga (eletronicos/ceramica > 1)


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


## Velocidade (m/s) acima da qual a curva `curve` empurra o caminhao para fora da faixa.
static func curve_safe_speed(curve: float, grip_: float) -> float:
	var c: float = absf(curve)
	if c < 0.05:
		return EngineModel.MAX_SPEED * 2.0
	return sqrt(LANE_HOLD * grip_ / (c * CURVE_PUSH))


## Toque de faixa: `steer_` e a direcao segurada (-1, 0, +1). O toque e a borda 0 -> direcao.
## 1o toque liga a seta; 2o toque no mesmo lado dentro da janela executa a troca.
func _lane_input(steer_: float, dt: float) -> void:
	var dir: int = 0
	if steer_ > 0.5:
		dir = 1
	elif steer_ < -0.5:
		dir = -1
	var tapped: bool = dir != 0 and dir != tap_prev
	tap_prev = dir
	signal_time = maxf(signal_time - dt, 0.0)
	lane_change_time = maxf(lane_change_time - dt, 0.0)
	if signal_time <= 0.0:
		signal_dir = 0
	if not tapped:
		return
	if signal_dir == dir and signal_time > 0.0:
		var nl: int = clampi(lane + dir, Lanes.SHOULDER_L, Lanes.SHOULDER_R)
		signal_dir = 0
		signal_time = 0.0
		if nl != lane:
			lane = nl
			lane_change_time = LANE_CHANGE_TIME
			lane_changes += 1
	else:
		signal_dir = dir
		signal_time = LANE_SIGNAL_WINDOW


## Inclinacao visual da cabine (-1..+1) durante a troca de faixa.
func lean() -> float:
	return clampf(lateral_vel / LANE_MAX_VEL, -1.0, 1.0)


func grip() -> float:
	return pow(MASS_REF / mass, 0.3)


func step(dt: float, cmd: Commands, track: Track) -> void:
	# 1) longitudinal: tracao - arrasto - rolamento - freio - ladeira
	var force: float = engine.step(dt, cmd.throttle, speed, draft * DRAFT_SPEED_BONUS)
	if force > 0.0:
		force *= 1.0 + DRAFT_BOOST * draft
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
	# 3) lateral: seta + troca de faixa; o x segue a faixa alvo sozinho. Na curva so escapa se entrar rapido demais.
	_lane_input(cmd.steer, dt)
	var authority: float = minf(speed / 6.0, 1.0) * grip()
	var desired: float = clampf((Lanes.X[lane] - x) * LANE_GAIN, -LANE_MAX_VEL, LANE_MAX_VEL) * authority
	lateral_vel += (desired - lateral_vel) * minf(STEER_RESPONSE * dt, 1.0)
	var curve: float = track.curve_at(z)
	var safe: float = curve_safe_speed(curve, grip())
	var push: float = 0.0
	if speed > safe:
		push = -curve * (speed * speed - safe * safe) * CURVE_PUSH * OVERSPEED_PUSH
	x += (lateral_vel + push + steer_pull * steer_pull_dir) * dt
	x = clampf(x, -1.6, 1.6)   # limite fisico (fora do acostamento)
	# 4) avanco
	z += speed * dt
	gear = engine.gear
	rpm = engine.rpm
	boost = engine.boost
