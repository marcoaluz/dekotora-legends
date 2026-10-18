class_name EngineModel
extends RefCounted
## Motor completo (P44): curva de torque por RPM, 6 marchas automaticas, turbo com atraso e pressao
## (boost), escape direto, freio-motor e perda de potencia por dano. Valores de docs/BALANCEAMENTO.md.
## Sem nos nem audio: a apresentacao le rpm, gear, boost e os eventos (blow-off) deste objeto.

const MAX_SPEED: float = 38.9          # m/s (140 km/h): limite de referencia
const IDLE_RPM: float = 700.0
const GEARS: int = 6
const GEAR_RATIOS: Array[float] = [6.4, 4.1, 2.75, 1.9, 1.35, 1.0]
const FINAL_DRIVE: float = 3.3
const WHEEL_RADIUS: float = 0.52
const DRIVE_EFFICIENCY: float = 1.15   # perdas + escala de jogo
const TRACTION_LIMIT: float = 32000.0  # N: limite de aderencia na arrancada (patina acima disso)
const UPSHIFT_FRAC: float = 0.9        # sobe de marcha acima desta fracao da rotacao de corte
const DOWNSHIFT_RPM: float = 1000.0
const SHIFT_TIME: float = 0.35         # corte de torque ao trocar de marcha (s)
const ENGINE_BRAKE_FORCE: float = 4500.0   # N, freio-motor padrao em rotacao alta
const JAKE_BONUS: float = 0.35         # +35% (jake_brake)
const JAKE_MIN_RPM: float = 1500.0
const RPM_RESPONSE: float = 9.0

# Curva de torque normalizada (fracao do torque maximo) por RPM.
const TORQUE_CURVE: Array[Vector2] = [
	Vector2(700, 0.55), Vector2(1000, 0.82), Vector2(1300, 0.97), Vector2(1600, 1.0),
	Vector2(1900, 0.93), Vector2(2200, 0.80), Vector2(2500, 0.62), Vector2(2800, 0.4),
]

var max_torque: float = 1400.0         # N.m
var redline_rpm: float = 2400.0
var turbo_gain: float = 0.0            # 0.18 = +18% em alta
var turbo_min_rpm: float = 1500.0
var turbo_lag: float = 0.0             # s
var exhaust_bonus: float = 0.0         # 0.03 = +3%
var has_jake: bool = false
var power_factor: float = 1.0          # 1.0 saudavel; dano reduz (TruckSim.refresh_damage_effects)
var body_torque: float = 1.0           # modelo do caminhao (BodyDef.torque_mult): o Canter tem motor menor

var rpm: float = IDLE_RPM
var gear: int = 1
var boost: float = 0.0                 # 0..1
var blowoff: bool = false              # true por um tick quando solta o acelerador com turbo cheio ("pssh")
var shifting: float = 0.0              # tempo restante de troca
var throttle_now: float = 0.0
var _prev_throttle: float = 0.0


func configure(engine_def: Resource = null, turbo_def: Resource = null, exhaust_def: Resource = null, jake: bool = false) -> void:
	if engine_def != null:
		max_torque = float(engine_def.get("max_torque_nm"))
		redline_rpm = float(engine_def.get("redline_rpm"))
	if turbo_def != null:
		turbo_gain = float(turbo_def.get("torque_gain"))
		turbo_min_rpm = maxf(float(turbo_def.get("min_rpm")), 1.0)
		turbo_lag = float(turbo_def.get("lag_s"))
	if exhaust_def != null:
		exhaust_bonus = float(exhaust_def.get("torque_bonus"))
	has_jake = jake


func torque_fraction(r: float) -> float:
	if r <= TORQUE_CURVE[0].x:
		return TORQUE_CURVE[0].y
	for i in range(1, TORQUE_CURVE.size()):
		if r <= TORQUE_CURVE[i].x:
			var a: Vector2 = TORQUE_CURVE[i - 1]
			var b: Vector2 = TORQUE_CURVE[i]
			return lerpf(a.y, b.y, (r - a.x) / (b.x - a.x))
	return TORQUE_CURVE[TORQUE_CURVE.size() - 1].y


## RPM do motor para uma velocidade e marcha (sem embreagem).
func rpm_for(speed: float, g: int) -> float:
	return speed / WHEEL_RADIUS * GEAR_RATIOS[g - 1] * FINAL_DRIVE * 60.0 / TAU


func _ratio_total() -> float:
	return GEAR_RATIOS[gear - 1] * FINAL_DRIVE


## Avanca o motor um passo e devolve a forca nas rodas (N): positiva = tracao, negativa = freio-motor.
## `speed_bonus` = bonus de velocidade maxima do vacuo (m/s).
func step(dt: float, throttle: float, speed: float, speed_bonus: float = 0.0) -> float:
	throttle_now = throttle
	blowoff = false
	# RPM segue a velocidade na marcha atual (suavizado) ou acelera livre na troca
	var target_rpm: float = maxf(rpm_for(speed, gear), IDLE_RPM)
	if shifting > 0.0:
		shifting = maxf(shifting - dt, 0.0)
	rpm = lerpf(rpm, target_rpm, minf(RPM_RESPONSE * dt, 1.0))
	# troca automatica
	if shifting <= 0.0:
		if rpm > redline_rpm * UPSHIFT_FRAC and gear < GEARS:
			gear += 1
			shifting = SHIFT_TIME
		elif rpm < DOWNSHIFT_RPM and gear > 1 and speed > 2.0:
			gear -= 1
			shifting = SHIFT_TIME * 0.6
	# turbo: enche com acelerador e rotacao acima do minimo; esvazia rapido ao soltar
	var boost_target: float = 0.0
	if throttle > 0.5 and rpm > turbo_min_rpm and turbo_gain > 0.0:
		boost_target = clampf(0.6 + 0.4 * (rpm - turbo_min_rpm) / (redline_rpm - turbo_min_rpm), 0.0, 1.0)
	if boost_target > boost:
		boost = minf(boost + dt / maxf(turbo_lag, 0.05), boost_target) if turbo_lag > 0.0 else boost_target
	else:
		boost = maxf(boost - dt * 1.6, boost_target)
	if turbo_gain > 0.0 and _prev_throttle > 0.5 and throttle < 0.2 and boost > 0.6:
		blowoff = true
	_prev_throttle = throttle
	# forca
	var limiter: float = clampf((MAX_SPEED + speed_bonus - speed) / 3.0, 0.0, 1.0)
	var rpm_limit: float = clampf((redline_rpm * 1.08 - rpm) / (redline_rpm * 0.08), 0.0, 1.0)
	if throttle > 0.0 and shifting <= 0.0:
		var tq: float = max_torque * torque_fraction(rpm) * (1.0 + exhaust_bonus) * (1.0 + turbo_gain * boost) * power_factor * body_torque
		var f_drive: float = tq * _ratio_total() * DRIVE_EFFICIENCY / WHEEL_RADIUS * throttle * limiter * rpm_limit
		return minf(f_drive, TRACTION_LIMIT)
	if throttle <= 0.0 and rpm > JAKE_MIN_RPM and speed > 1.0:
		var f: float = ENGINE_BRAKE_FORCE * clampf(rpm / redline_rpm, 0.0, 1.0) * (1.0 + (JAKE_BONUS if has_jake else 0.0))
		return -f
	return 0.0


## Compatibilidade com a P20/P21 (so apresentacao): marcha e rpm atuais.
func gear_and_rpm(_speed: float) -> Vector2:
	return Vector2(float(gear), rpm)

