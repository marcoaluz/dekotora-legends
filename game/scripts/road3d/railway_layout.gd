class_name RailwayLayout
extends RefCounted
## Onde fica a ferrovia em cada rota (T-154, so visual). Tabela por rota; nada disso entra na simulacao.
## Regras usadas para escolher os trechos (conferidas por tests/test_railway.gd):
## - paralela do lado da TERRA (esquerda): no litoral o mar fica a direita; longe da mureta (13,6 m), das arvores
##   (ate ~23 m) e dos outdoors (26 m); os predios da cidade comecam a ~78 m;
## - fora dos trechos de 2 faixas da T-153 (litoral 2.270-2.890 m com a ponte; montanha 650-1.190 m com o tunel antigo);
## - nos tuneis da pista a linha entra no morro por uma boca propria (montanha) ou passa ao lado da caixa de concreto
##   (cidade, a caixa vai ate 30 m);
## - viaduto de trem cruzando POR CIMA da rodovia onde ha espaco: montanha (antes do pedagio/portico) e cidade.

const RAIL_TOP: float = 0.5        # trilho acima do chao (aterro de lastro) nas linhas no chao
const CLEARANCE: float = 8.5       # cruzamento: trilho acima da pista (vao livre ~6 m embaixo da viga)

## Linhas da rota (paralelas e cruzamentos). `kind`: cenario (coast/city/mountain) para rotas sem tabela.
static func lines_for(route_id: String, kind: StringName, path: TrackPath) -> Array[RailLine]:
	var out: Array[RailLine] = []
	var L: float = path.track.length_m
	var g: float = RoadMesh.deck_height(kind)
	match route_id:
		"kanto_1_coast":
			out.append(RailLine.parallel(path, 0.0, 2150.0, -1.0, 36.0, RAIL_TOP, 0.0, Vector2i(1, 1)))
		"kanto_2_viaduct":
			out.append(RailLine.parallel(path, 0.0, L, -1.0, 40.0, 0.0, g, Vector2i(1, 1)))
			out.append(RailLine.crossing(path, 1500.0, deg_to_rad(64.0), CLEARANCE, 330.0, g, Vector2i(1, 1)))
		"kanto_3_mountain":
			out.append(RailLine.crossing(path, 240.0, deg_to_rad(70.0), CLEARANCE, 150.0, 0.0, Vector2i(1, 1)))
			out.append(RailLine.parallel(path, 1240.0, 2080.0, -1.0, 38.0, RAIL_TOP, 0.0, Vector2i(1, 1)))
			out.append(RailLine.parallel(path, 2380.0, L, -1.0, 38.0, RAIL_TOP, 0.0, Vector2i(1, 1)))
	return out


## Trem padrao de cada rota (o outro aparece de vez em quando): litoral e montanha = carga; cidade = bonde amarelo.
static func main_train(route_id: String) -> int:
	return RailTraffic.Type.LRT if route_id == "kanto_2_viaduct" else RailTraffic.Type.FREIGHT


## Corredores ocupados pelos cruzamentos (para a cidade nao por predio em cima): [a, b, meia_largura] no plano XZ.
static func keep_out(lines: Array[RailLine]) -> Array:
	var out: Array = []
	for l in lines:
		if l.kind == RailLine.Kind.CROSSING:
			var a: Vector3 = l.pts[0]
			var b: Vector3 = l.pts[l.pts.size() - 1]
			out.append([Vector2(a.x, a.z), Vector2(b.x, b.z), 24.0])
	return out
