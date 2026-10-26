class_name PowerLineLayout
extends RefCounted
## Onde ficam os postes de energia com fios (電柱, T-163) em cada rota. So visual; nada disso entra na simulacao.
## Regras (conferidas por tests/test_power_lines.gd):
## - fora da mureta (face externa a 13,6 m), a LATERAL_M do centro, do lado da TERRA: litoral = esquerda (o mar fica
##   a direita); montanha = direita (a ferrovia da T-154 corre a esquerda); cidade (viaduto) = sem postes;
## - longe dos tuneis (bocas e morros), dos trechos de 2 faixas da T-153 (ponte, tunel antigo), do pedagio e do
##   viaduto de trem que cruza a pista na montanha (240 m);
## - um poste a cada EVERY_M; a cada TRANSFORMER_EVERY postes, um com transformador.
## Para uma rota nova: acrescente uma linha em `runs_for` (ou deixe o padrao pelo cenario).

const LATERAL_M: float = 17.0           # placas da mureta vao ate ~15,5 m; outdoors a 26 m; ferrovia (muro) a 29 m
const EVERY_M: float = 35.0
const TRANSFORMER_EVERY: int = 4
const TUNNEL_GAP: float = 90.0          # morro em volta das bocas
const SECTION_GAP: float = 80.0
const SIGN_GAP: float = 5.0             # placa verde grande (Track.objects "sign_green", direita, 13,7 m +- 2,4)

## T-217: lateral of the poles on this side; on the right they stand beyond the other carriageway (OppositeLayout).
static func lateral(side: float, path: TrackPath = null) -> float:
	if side > 0.0 and path != null and OppositeLayout.of(path) != null:
		return LATERAL_M + OppositeLayout.SHIFT
	return LATERAL_M


## Trechos [inicio, fim, lado] de cada rota.
static func runs_for(route_id: String, kind: StringName, length_m: float) -> Array:
	match route_id:
		"kanto_1_coast":
			return [[320.0, 2140.0, -1.0]]                  # T-217: before the stone wall cut (2,165 m)
		"kanto_2_viaduct":
			return []
		"kanto_3_mountain":
			return [[330.0, length_m - 60.0, 1.0]]
	match kind:                                 # rotas sem tabela: pelo cenario
		&"coast":
			return [[320.0, length_m - 120.0, -1.0]]
		&"mountain":
			return [[330.0, length_m - 60.0, 1.0]]
	return []


## Postes da rota: Array de [z, lado (-1/+1), variante (0 = simples, 1 = com transformador), corrida (indice)].
## Postes de uma mesma "corrida" sao ligados pelos fios (um buraco = corrida nova).
static func poles(route_id: String, kind: StringName, track: Track, tunnels: Array[Vector2]) -> Array:
	var out: Array = []
	var run_id: int = 0
	var n: int = 0
	for r in runs_for(route_id, kind, track.length_m):
		var z: float = float(r[0])
		var last_ok: bool = false
		while z <= float(r[1]):
			if _free(z, float(r[2]), track, tunnels):
				if not last_ok:
					run_id += 1
				out.append([z, float(r[2]), 1 if n % TRANSFORMER_EVERY == TRANSFORMER_EVERY - 1 else 0, run_id])
				n += 1
				last_ok = true
			else:
				last_ok = false
			z += EVERY_M
	return out


static func _free(z: float, side: float, track: Track, tunnels: Array[Vector2]) -> bool:
	if RoadMesh.in_tunnel(z, tunnels, TUNNEL_GAP):
		return false
	if LaneSections.at(track.events, z, SECTION_GAP) != null:
		return false
	if side > 0.0:
		var k: int = track.first_object_at(z - SIGN_GAP)
		while k < track.objects.size() and float(track.objects[k]["z"]) <= z + SIGN_GAP:
			if String(track.objects[k]["kind"]) == "sign_green":
				return false
			k += 1
	return true


## Corredor dos fios (para tirar as arvores do caminho): [z0, z1, lado] de cada corrida.
static func corridors(list: Array) -> Array:
	var out: Array = []
	for p in list:
		if out.is_empty() or int(out[-1][3]) != int(p[3]):
			out.append([float(p[0]), float(p[0]), float(p[1]), int(p[3])])
		out[-1][1] = float(p[0])
	return out
