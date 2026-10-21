class_name OverpassLayout
extends RefCounted
## Onde fica o viaduto rodoviario que cruza POR CIMA da pista (T-164, decisao do Marco na T-159). So visual: nada
## disso entra na simulacao nem na rede. Regras (conferidas por tests/test_overpass.gd):
## - num trecho reto (ou quase), longe de tuneis, trechos de 2 faixas, porticos, pedagio e viadutos de trem;
## - o vao livre embaixo das vigas e de CLEAR m sobre a pista onde quer que o viaduto passe por cima dela;
## - pilares fora da pista (>= PIER_ROAD_GAP m do eixo) e longe das linhas de trem;
## - postes, arvores e placas da beira da estrada saem de baixo dele (FOOTPRINT m de cada lado do eixo).
## Lugares achados com tools_dev/find_overpass_spots.gd. Para uma rota nova: uma linha em `for_route`.

const CLEAR: float = 7.6            # vao livre sob as vigas (caminhao de 3,8 m + luzes no teto, folga de sobra)
const BEAM_BOTTOM: float = 2.521    # topo do asfalto do viaduto ate o fundo das vigas (build_road_pontes_kit.py)
const HALF_LEN: float = 320.0       # o viaduto vai ate 320 m de cada lado do cruzamento (some na neblina)
const FULL_HALF: float = 50.0       # modulo completo (vigas em I, postes do corrimao) so perto da pista
const PIER_EVERY: float = 40.0
const PIER_ROAD_GAP: float = 17.0   # mureta externa a 13,6 m
const FOOTPRINT: float = 9.0        # meia largura do tabuleiro (6 m) + folga

## Viadutos da rota: [{z, angle (graus, 90 = perpendicular)}].
static func for_route(route_id: String) -> Array:
	match route_id:
		"kanto_2_viaduct":
			return [{"z": 2050.0, "angle": 76.0}]       # via expressa cruzando via expressa (Shuto); antes do trecho antigo (2.140 m)
		"kanto_3_mountain":
			return [{"z": 2580.0, "angle": 70.0}]       # desvio passando por cima da pista e da ferrovia
	return []


## Pontos do eixo do viaduto: centro (no topo do asfalto dele), direcao e altura.
static func axis(path: TrackPath, o: Dictionary) -> Dictionary:
	var z: float = float(o["z"])
	var road: Vector3 = path.center_at(z)
	var d: Vector3 = path.forward_at(z).rotated(Vector3.UP, -deg_to_rad(float(o["angle"])))
	d.y = 0.0
	d = d.normalized()
	var hi: float = road.y                      # a pista pode estar em rampa: vao livre medido no ponto mais alto embaixo
	var zz: float = z - 25.0
	while zz <= z + 25.0:
		hi = maxf(hi, path.center_at(clampf(zz, 0.0, path.track.length_m)).y)
		zz += 5.0
	var top: float = hi + CLEAR + BEAM_BOTTOM
	return {"c": Vector3(road.x, top, road.z), "d": d, "top": top}


## Corredores sem predio (cidade) e sem objetos de beira de estrada: [a, b, meia_largura] no plano XZ.
static func keep_out(path: TrackPath, route_id: String) -> Array:
	var out: Array = []
	for o in for_route(route_id):
		var ax: Dictionary = axis(path, o)
		var c: Vector3 = ax["c"]
		var d: Vector3 = ax["d"]
		var a: Vector3 = c - d * HALF_LEN
		var b: Vector3 = c + d * HALF_LEN
		out.append([Vector2(a.x, a.z), Vector2(b.x, b.z), FOOTPRINT])
	return out


## O ponto (com raio r) cai embaixo de algum viaduto?
static func blocked(corridors: Array, p: Vector3, r: float = 0.0) -> bool:
	var q := Vector2(p.x, p.z)
	for k in corridors:
		if Geometry2D.get_closest_point_to_segment(q, k[0], k[1]).distance_to(q) < float(k[2]) + r:
			return true
	return false
