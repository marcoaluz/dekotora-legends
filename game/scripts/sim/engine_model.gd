class_name EngineModel
extends RefCounted
## Motor. Versao simples da P20: forca de tracao fixa. A curva de torque por RPM, turbo,
## marchas e danos entram na P44 sem mudar quem chama (TruckSim usa so estas funcoes).

const MAX_SPEED: float = 38.9          # m/s (140 km/h)
const TRACTIVE_FORCE: float = 26000.0  # N (torque fixo por enquanto)
const IDLE_RPM: float = 700.0
const REDLINE_RPM: float = 2400.0
const GEARS: int = 6

var power_factor: float = 1.0          # 1.0 = motor saudavel (dano reduz, P32/P44)


## Forca de tracao (N) para um acelerador 0..1 na velocidade dada.
func traction_force(throttle: float, speed: float) -> float:
	var limiter: float = clampf((MAX_SPEED - speed) / 3.0, 0.0, 1.0)  # corta perto da velocidade maxima
	return TRACTIVE_FORCE * throttle * limiter * power_factor


## Marcha (1..6) e RPM aproximados para a velocidade; so para apresentacao/audio.
func gear_and_rpm(speed: float) -> Vector2:
	var band: float = MAX_SPEED / float(GEARS)
	var gear: int = clampi(int(speed / band) + 1, 1, GEARS)
	var in_gear: float = (speed - float(gear - 1) * band) / band
	return Vector2(float(gear), lerpf(IDLE_RPM + 400.0, REDLINE_RPM, clampf(in_gear, 0.0, 1.0)))
