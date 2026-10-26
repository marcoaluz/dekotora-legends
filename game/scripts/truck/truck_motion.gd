class_name TruckMotion
extends RefCounted
## T-219: balanco da CARROCERIA de um caminhao (so visual): inclinacao (roll) nas curvas e na troca de faixa, cabeceio
## (pitch) ao acelerar/frear e compressao da suspensao (heave) nas lombadas e emendas de viaduto. Cada eixo e uma mola
## com amortecedor (frequencia e amortecimento no TruckFeel): o bau atrasa, passa um pouco do ponto e volta.
## Puro calculo, sem nos: recebe o que a simulacao ja tem (velocidade, velocidade lateral) e a geometria da pista.
## Convencao: roll > 0 = lado DIREITO desce; pitch > 0 = nariz sobe; heave < 0 = carroceria desce (comprime).

const ACC_FILTER_S: float = 0.12      # s: suaviza a derivada (a sim anda a 30/s; a tela a 60+)
const MAX_SUBSTEP: float = 1.0 / 120.0

var roll: float = 0.0                 # rad
var pitch: float = 0.0                # rad
var heave: float = 0.0                # m
var _roll_v: float = 0.0
var _pitch_v: float = 0.0
var _heave_v: float = 0.0
var long_acc: float = 0.0             # m/s2 filtrada (> 0 acelerando)
var lat_acc: float = 0.0              # m/s2 filtrada para a DIREITA (troca de faixa + curva)
var _prev_speed: float = NAN
var _prev_lat: float = NAN


## Avanca `dt` s. `speed` m/s; `lat_mps` velocidade lateral (m/s, > 0 = para a direita); `curv` curvatura da pista
## (1/m, > 0 = curva para a ESQUERDA); `vert_acc` aceleracao vertical que a pista impoe (m/s2, > 0 = baixada,
## comprime); `kick` tranco vertical instantaneo (m/s, emenda de viaduto; > 0 = para baixo).
func step(dt: float, feel: TruckFeel, speed: float, lat_mps: float, curv: float, vert_acc: float, kick: float = 0.0) -> void:
	if dt <= 0.0:
		return
	if is_nan(_prev_speed):
		_prev_speed = speed
		_prev_lat = lat_mps
	var k: float = minf(dt / ACC_FILTER_S, 1.0)
	long_acc += ((speed - _prev_speed) / dt - long_acc) * k
	var lane_acc: float = (lat_mps - _prev_lat) / dt
	var curve_acc: float = -speed * speed * curv * feel.roll_curve_share
	lat_acc += (lane_acc + curve_acc - lat_acc) * k
	_prev_speed = speed
	_prev_lat = lat_mps
	var roll_t: float = clampf(-deg_to_rad(feel.roll_deg_per_mps2) * lat_acc, -deg_to_rad(feel.roll_max_deg), deg_to_rad(feel.roll_max_deg))
	var pitch_t: float = clampf(deg_to_rad(feel.pitch_deg_per_mps2) * long_acc, -deg_to_rad(feel.pitch_max_deg), deg_to_rad(feel.pitch_max_deg))
	var heave_t: float = clampf(-feel.heave_m_per_mps2 * vert_acc, -feel.heave_max_m, feel.heave_max_m)
	_heave_v -= kick
	var left: float = dt
	while left > 0.0:
		var h: float = minf(left, MAX_SUBSTEP)
		left -= h
		var r: Vector2 = _spring(roll, _roll_v, roll_t, feel.roll_freq_hz, feel.roll_damping, h)
		roll = r.x
		_roll_v = r.y
		var p: Vector2 = _spring(pitch, _pitch_v, pitch_t, feel.pitch_freq_hz, feel.pitch_damping, h)
		pitch = p.x
		_pitch_v = p.y
		var v: Vector2 = _spring(heave, _heave_v, heave_t, feel.heave_freq_hz, feel.heave_damping, h)
		heave = v.x
		_heave_v = v.y
	var lim: float = deg_to_rad(feel.roll_max_deg) * 1.4          # o balanco pode passar um pouco do alvo, nao muito
	roll = clampf(roll, -lim, lim)
	pitch = clampf(pitch, -deg_to_rad(feel.pitch_max_deg) * 1.4, deg_to_rad(feel.pitch_max_deg) * 1.4)
	heave = clampf(heave, -feel.heave_max_m * 1.6, feel.heave_max_m * 1.6)


## Mola com amortecedor (Euler semi-implicito). Devolve (posicao, velocidade).
static func _spring(x: float, v: float, target: float, freq_hz: float, damping: float, h: float) -> Vector2:
	var w: float = TAU * maxf(freq_hz, 0.05)
	var a: float = w * w * (target - x) - 2.0 * clampf(damping, 0.0, 2.0) * w * v
	v += a * h
	x += v * h
	return Vector2(x, v)


## Transform LOCAL da carroceria (relativo ao no do caminhao, origem na traseira no chao, frente em -Z):
## roll em volta do centro de rolagem (0,7 m de altura), pitch em volta do meio do caminhao, heave para baixo.
static func body_transform(roll_: float, pitch_: float, heave_: float, length: float) -> Transform3D:
	var pivot := Vector3(0.0, 0.7, -length * 0.5)
	var b := Basis(Vector3.RIGHT, pitch_) * Basis(Vector3.FORWARD, roll_)
	return Transform3D(b, pivot - b * pivot + Vector3(0.0, heave_, 0.0))


## Reinicia (troca de cena, teleporte).
func reset() -> void:
	roll = 0.0
	pitch = 0.0
	heave = 0.0
	_roll_v = 0.0
	_pitch_v = 0.0
	_heave_v = 0.0
	long_acc = 0.0
	lat_acc = 0.0
	_prev_speed = NAN
	_prev_lat = NAN
