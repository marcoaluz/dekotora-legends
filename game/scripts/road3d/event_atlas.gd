class_name EventAtlas
extends RefCounted
## Map of the track events atlas (T-139): assets/textures/event_atlas.png, 512 x 576, made by
## tools_dev/make_event_atlas.gd (needs a window). The generator and the game use the SAME map.
##  y 0..255   : 128 x 128 cells (speed limit 60, works/narrowing diamonds, LED arrows, warning triangle, glow)
##  y 256..383 : 256 x 128 cells (orange LED information boards)
##  y 384..511 : 256 x 64 / 128 x 64 cells (barricade stripes, 工事中 board, distance plates, 車線減少 plate)
##  y 512..575 : 64 x 64 cells (solid colours)

const ATLAS := "res://assets/textures/event_atlas.png"
const W: int = 512
const H: int = 576
const SMALL: PackedStringArray = ["spd_60", "warn_works", "warn_narrow_r", "warn_narrow_l",
	"arrow_l", "arrow_r", "triangle", "glow"]
const WIDE: PackedStringArray = ["vms_accident", "vms_works"]
const STRIPS: PackedStringArray = ["barricade", "kouji"]
const PLATES: PackedStringArray = ["d400", "d200"]
const SOLIDS: PackedStringArray = ["solid_black", "solid_white", "steel", "solid_yellow", "solid_orange", "solid_grey"]

static var _rects: Dictionary = {}


static func rects() -> Dictionary:
	if not _rects.is_empty():
		return _rects
	for i in SMALL.size():
		_rects[SMALL[i]] = Rect2i((i % 4) * 128, (i / 4) * 128, 128, 128)
	for i in WIDE.size():
		_rects[WIDE[i]] = Rect2i(i * 256, 256, 256, 128)
	for i in STRIPS.size():
		_rects[STRIPS[i]] = Rect2i(i * 256, 384, 256, 64)
	for i in PLATES.size():
		_rects[PLATES[i]] = Rect2i(i * 128, 448, 128, 64)
	_rects["aux_narrow"] = Rect2i(256, 448, 256, 64)
	for i in SOLIDS.size():
		_rects[SOLIDS[i]] = Rect2i(i * 64, 512, 64, 64)
	return _rects


static func has(id: String) -> bool:
	return rects().has(id)


## UV 0..1 of the id (1.5 px margin against mipmap bleeding; solids use only their centre).
static func uv(id: String) -> Rect2:
	var r: Rect2i = rects().get(id, Rect2i(0, 512, 64, 64))
	var m: float = 24.0 if id in SOLIDS else 1.5
	return Rect2((Vector2(r.position) + Vector2(m, m)) / Vector2(W, H), (Vector2(r.size) - Vector2(2.0 * m, 2.0 * m)) / Vector2(W, H))


static func aspect(id: String) -> float:
	var r: Rect2i = rects().get(id, Rect2i(0, 0, 128, 128))
	return float(r.size.x) / float(r.size.y)
