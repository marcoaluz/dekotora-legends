class_name Track
extends RefCounted
## Pista pseudo-3D: lista de segmentos de comprimento fixo. Cada segmento guarda a curva
## (positivo = vira a direita) e a inclinacao (fracao; 0.04 = 4% de subida).
## Sem nenhum no visual: a apresentacao le estes numeros para desenhar.

const SEG_LEN: float = 2.0            # metros por segmento
const ROAD_HALF_WIDTH_M: float = 7.2  # x = +-1 corresponde a esta distancia lateral

var curves: PackedFloat32Array = PackedFloat32Array()
var hills: PackedFloat32Array = PackedFloat32Array()
var heights: PackedFloat32Array = PackedFloat32Array()   # altura no INICIO de cada segmento (m)
var length_m: float = 0.0


func segment_count() -> int:
	return curves.size()


func _index(z: float) -> int:
	return clampi(int(z / SEG_LEN), 0, maxi(curves.size() - 1, 0))


func curve_at(z: float) -> float:
	return curves[_index(z)] if curves.size() > 0 else 0.0


func hill_at(z: float) -> float:
	return hills[_index(z)] if hills.size() > 0 else 0.0


## Altura da pista em z (metros), interpolada dentro do segmento.
func height_at(z: float) -> float:
	if heights.is_empty():
		return 0.0
	var i: int = _index(z)
	return heights[i] + hills[i] * (clampf(z, 0.0, length_m) - float(i) * SEG_LEN)


## Adiciona uma secao: `length` metros com curva e inclinacao alvo; `ease_m` metros de transicao
## suave a partir do valor do segmento anterior.
func add_section(length: float, curve: float, hill: float = 0.0, ease_m: float = 40.0) -> void:
	var n: int = maxi(int(length / SEG_LEN), 1)
	var ease_n: int = clampi(int(ease_m / SEG_LEN), 0, n)
	var c0: float = curves[curves.size() - 1] if curves.size() > 0 else 0.0
	var h0: float = hills[hills.size() - 1] if hills.size() > 0 else 0.0
	for i in n:
		var t: float = 1.0 if ease_n == 0 or i >= ease_n else smoothstep(0.0, 1.0, float(i) / float(ease_n))
		var h: float = lerpf(h0, hill, t)
		heights.append(heights[heights.size() - 1] + hills[hills.size() - 1] * SEG_LEN if heights.size() > 0 else 0.0)
		curves.append(lerpf(c0, curve, t))
		hills.append(h)
	length_m = curves.size() * SEG_LEN


## Pista de teste (P20): retas, curvas para os dois lados e uma subida.
static func make_test_track() -> Track:
	var t := Track.new()
	t.add_section(400.0, 0.0)
	t.add_section(300.0, -0.8)    # curva a esquerda
	t.add_section(300.0, 0.0)
	t.add_section(300.0, 0.9)     # curva a direita
	t.add_section(200.0, 0.0, 0.05)   # subida
	t.add_section(200.0, 0.0, -0.05)  # descida
	t.add_section(300.0, 1.4)     # curva forte a direita
	t.add_section(300.0, -1.2)    # curva forte a esquerda
	t.add_section(600.0, 0.0)
	return t
