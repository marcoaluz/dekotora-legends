class_name TexSlots
extends RefCounted
## T-217: textures of the route ambience with an automatic swap. Each SLOT has our own texture made by code
## (blender/scripts/build_t217_textures.py, in assets/textures/t217/) and, if Marco drops a CC0 PBR set with the
## slot name in assets/textures/cc0/t217/ (ambientCG / Poly Haven, see docs/BIBLIOTECA_CENARIO.md section 6), the game
## uses his files instead, no code change: `<slot>_diff.jpg|png`, `<slot>_nor_gl.jpg|png` (normal map, OpenGL),
## `<slot>_rough.jpg|png`. After copying, run `bash tools/import_textures_3d.sh game/assets/textures/cc0/t217` once
## (mipmaps + compression; without it the texture turns into grain at a distance).

const OWN := "res://assets/textures/t217/"
const MARCO := "res://assets/textures/cc0/t217/"
const EXTS: Array[String] = ["jpg", "png", "webp", "jpeg"]
## Slot -> metres covered by one repeat of the texture (Marco's 2K sets are usually ~2-3 m; ours as noted).
const TILE_M: Dictionary = {"stone_wall": 3.0, "rock_cut": 4.0, "hedge": 2.0, "portal_concrete": 4.0,
	"tunnel_wall": 4.0, "danchi_wall": 4.0, "cut_slope": 4.0}


static func _find(base: String) -> Texture2D:
	for e in EXTS:
		var p: String = "%s.%s" % [base, e]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null


## Marco's CC0 colour map for the slot, if he has put one there.
static func marco(slot: String) -> Texture2D:
	return _find(MARCO + slot + "_diff")


static func albedo(slot: String, own: String = "") -> Texture2D:
	var t: Texture2D = marco(slot)
	if t != null:
		return t
	return _find(OWN + (own if own != "" else slot))


static func normal(slot: String, own: String = "") -> Texture2D:
	if marco(slot) != null:
		var t: Texture2D = _find(MARCO + slot + "_nor_gl")
		return t if t != null else _find(MARCO + slot + "_nrm")
	return _find(OWN + (own if own != "" else slot + "_nrm"))


static func rough(slot: String) -> Texture2D:
	return _find(MARCO + slot + "_rough") if marco(slot) != null else null


## Metres per repeat (our textures have their own size; Marco's use TILE_M).
static func tile_m(slot: String, own_m: float) -> float:
	return float(TILE_M.get(slot, own_m)) if marco(slot) != null else own_m
