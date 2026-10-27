class_name HardBrake
extends RefCounted
## Freada forte (T-144): o caminhao freia de repente em velocidade alta. So estado (a apresentacao faz o som
## de freio, a fumaca dos pneus, as marcas no asfalto e o tremor). Nao muda a fisica.
##
## Regra: o freio passa de MIN_BRAKE com o caminhao acima de MIN_SPEED (60 km/h) => comeca. Continua enquanto o
## freio estiver apertado, o caminhao perdendo pelo menos MIN_DECEL (9 km/h por s) e acima de END_SPEED.
## Com o freio total (60 kN) o caminhao de 12 t perde ~5 m/s^2 = 18 km/h por segundo.
## `brake_intensity` 0..1 cresce com a velocidade em que a freada comecou e com a desaceleracao (som e fumaca).

const MIN_BRAKE: float = 0.7            # comando de freio (0..1)
const MIN_SPEED: float = 60.0 / 3.6     # m/s no instante em que aperta
const MIN_DECEL: float = 2.5            # m/s^2 (9 km/h por segundo)
const END_SPEED: float = 2.5            # m/s: abaixo disto acabou (parado)
const FULL_SPEED: float = 120.0 / 3.6   # m/s: freada a partir daqui = intensidade cheia
## T-239: luz de freio (todas as luzes do caminhao ficam vermelhas). Acende com o freio a partir de LAMP_ON e so apaga
## abaixo de LAMP_OFF (histerese: o freio proporcional dos bots nao faz a luz piscar).
const LAMP_ON: float = 0.15
const LAMP_OFF: float = 0.05


## Chame no fim de TruckSim.step com o freio do comando e a velocidade de ANTES do tick.
static func update(t: TruckSim, brake: float, speed_before: float, dt: float) -> void:
	var decel: float = (speed_before - t.speed) / maxf(dt, 0.0001)
	var held: bool = brake >= MIN_BRAKE
	t.hard_brake_started = false
	t.hard_brake_ended = false
	if held and not t.brake_held:
		t.brake_speed0 = speed_before
		t.brake_lost = 0.0
	t.brake_held = held
	t.brake_lamp = brake >= LAMP_ON or (t.brake_lamp and brake > LAMP_OFF)
	var was: bool = t.hard_braking
	t.hard_braking = held and t.brake_speed0 >= MIN_SPEED and t.speed > END_SPEED and decel >= MIN_DECEL
	if t.hard_braking:
		t.brake_lost = maxf(t.brake_speed0 - t.speed, 0.0)
		var by_speed: float = clampf((t.brake_speed0 - MIN_SPEED * 0.75) / (FULL_SPEED - MIN_SPEED * 0.75), 0.25, 1.0)
		var by_decel: float = clampf(decel / 5.0, 0.4, 1.0)
		t.brake_intensity = by_speed * by_decel * clampf(t.speed / 8.0, 0.3, 1.0)
	else:
		t.brake_intensity = 0.0
	t.hard_brake_started = t.hard_braking and not was
	t.hard_brake_ended = was and not t.hard_braking
