class_name Lanes
extends RefCounted
## Faixas da pista. Indices 0..4: acostamento esquerdo, 3 faixas, acostamento direito.
## O caminhao so conhece "faixa alvo"; o x (lateral) segue a faixa sozinho.

const SHOULDER_L: int = 0
const FIRST: int = 1                   # primeira faixa de rolagem
const LAST: int = 3                    # ultima faixa de rolagem
const SHOULDER_R: int = 4
const CENTER: int = 2
## 3 faixas de 3,6 m (x = 0,5 -> 3,6 m do centro) e acostamento de 1,8 m de cada lado; o caminhao tem 2,5 m, entao
## fica folgado DENTRO da faixa. Tem que bater com RoadMesh (LANE_W) e as linhas pintadas.
const X: Array[float] = [-0.875, -0.5, 0.0, 0.5, 0.875]
const ROAD: Array[float] = [-0.5, 0.0, 0.5]   # so as faixas de rolagem (transito)
const SPACING: float = 0.5
const ASPHALT_EDGE: float = 0.75              # borda das faixas (x)
const OFFROAD_X: float = 0.8                  # alem disto o centro do caminhao ja esta no acostamento (lento)


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
