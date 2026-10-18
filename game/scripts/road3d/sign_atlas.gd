class_name SignAtlas
extends RefCounted
## Mapa do atlas da sinalizacao (assets/textures/road_signs_atlas.png, 1024 x 1024, gerado por
## tools_dev/make_sign_atlases.gd). Um id por figura; o gerador e o jogo usam o MESMO mapa.
##  y 0..255   : celulas 128 x 128 (placas redondas, losangos, chevrons, "km", "延長", fundos lisos)
##  y 256..383 : celulas 256 x 128 (apoio "トンネル", saida 出口, 止まれ pintado)
##  y 384..511 : celulas 384 x 128 (nome de tunel)
##  y 512..895 : celulas 256 x 96 (nomes de lugar dos paineis de distancia)
##  y 896..991 : celulas 48 x 96 (algarismos: verdes para paineis, pretos para a placa do tunel)

const ATLAS := "res://assets/textures/road_signs_atlas.png"
const SIZE: int = 1024
const SMALL: PackedStringArray = ["spd_50", "spd_60", "spd_80", "spd_100", "stop", "warn_curve_r", "warn_curve_l",
	"warn_tunnel", "chev_r", "chev_l", "km", "enchou", "solid_green", "solid_white", "solid_back", "warn_rocks"]
const WIDE: PackedStringArray = ["aux_tunnel", "exit", "tomare", "aux_slow"]
## Nome do tunel de cada rota (ficticio); rota sem nome usa "aux_tunnel" (so "トンネル").
const TUNNEL_NAMES: Dictionary = {"kanto_2_viaduct": "臨海トンネル", "kanto_3_mountain": "仙石原トンネル"}
const DIGITS: String = "0123456789"

static var _rects: Dictionary = {}


## Lugares dos paineis de distancia: os mesmos dos porticos (RoadFurniture.KANJI), na mesma ordem.
static func places() -> Array:
	return RoadFurniture.KANJI.keys()


static func rects() -> Dictionary:
	if not _rects.is_empty():
		return _rects
	for i in SMALL.size():
		_rects[SMALL[i]] = Rect2i((i % 8) * 128, (i / 8) * 128, 128, 128)
	for i in WIDE.size():
		_rects[WIDE[i]] = Rect2i(i * 256, 256, 256, 128)
	var t: int = 0
	for rid in TUNNEL_NAMES:
		_rects["tun_" + String(rid)] = Rect2i(t * 384, 384, 384, 128)
		t += 1
	var ps: Array = places()
	for i in ps.size():
		_rects["place_" + String(ps[i])] = Rect2i((i % 4) * 256, 512 + (i / 4) * 96, 256, 96)
	for i in DIGITS.length():
		_rects["g" + DIGITS[i]] = Rect2i(i * 48, 896, 48, 96)
		_rects["w" + DIGITS[i]] = Rect2i((10 + i) * 48, 896, 48, 96)
	_rects["wm"] = Rect2i(20 * 48, 896, 48, 96)
	return _rects


static func has(id: String) -> bool:
	return rects().has(id)


## UV 0..1 do id (com margem de 1,5 px contra vazamento do mipmap).
static func uv(id: String) -> Rect2:
	var r: Rect2i = rects().get(id, Rect2i(0, 0, 128, 128))
	return Rect2((Vector2(r.position) + Vector2(1.5, 1.5)) / SIZE, (Vector2(r.size) - Vector2(3, 3)) / SIZE)


## Proporcao largura/altura do id (para montar quads sem distorcer).
static func aspect(id: String) -> float:
	var r: Rect2i = rects().get(id, Rect2i(0, 0, 128, 128))
	return float(r.size.x) / float(r.size.y)
