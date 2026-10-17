class_name Lanes
extends RefCounted
## Faixas da pista. Indices 0..4: acostamento esquerdo, 3 faixas, acostamento direito.
## O caminhao so conhece "faixa alvo"; o x (lateral) segue a faixa sozinho.

const SHOULDER_L: int = 0
const FIRST: int = 1                   # primeira faixa de rolagem
const LAST: int = 3                    # ultima faixa de rolagem
const SHOULDER_R: int = 4
const CENTER: int = 2
const X: Array[float] = [-1.1, -0.6, 0.0, 0.6, 1.1]
const ROAD: Array[float] = [-0.6, 0.0, 0.6]   # so as faixas de rolagem (transito)
const SPACING: float = 0.6


static func nearest(x: float) -> int:
	var best: int = CENTER
	var best_d: float = 1e9
	for i in X.size():
		var d: float = absf(X[i] - x)
		if d < best_d:
			best_d = d
			best = i
	return best


static func is_road_lane(lane: int) -> bool:
	return lane >= FIRST and lane <= LAST
