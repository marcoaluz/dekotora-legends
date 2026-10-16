class_name RoadsideLayer
extends Node2D
## Desenha os objetos de beira de estrada (postes, arvores, placas, guard-rails) projetados pela
## mesma camera da estrada, de longe para perto. Cada sprite vem de assets/sprites/roadside/<id>.png + .json.

const DIR := "res://assets/sprites/roadside/"
const MAX_DIST_M: float = 220.0

var projector: SpriteProjector
var _defs: Dictionary = {}     # id -> {tex, glow, size, anchor, ppm}
var _additive: CanvasItemMaterial


func _ready() -> void:
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _def(id: String) -> Dictionary:
	if _defs.has(id):
		return _defs[id]
	var d: Dictionary = {}
	var jp: String = "%s%s.json" % [DIR, id]
	if FileAccess.file_exists(jp):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
		if meta is Dictionary:
			d = {
				"tex": load("%s%s.png" % [DIR, id]),
				"glow": load("%s%s_glow.png" % [DIR, id]) if bool(meta.get("glow", false)) else null,
				"size": Vector2(meta["size"][0], meta["size"][1]),
				"anchor": Vector2(meta["anchor"][0], meta["anchor"][1]),
				"ppm": float(meta["ppm"]),
			}
	_defs[id] = d
	return d


func update_view(proj: SpriteProjector) -> void:
	projector = proj
	queue_redraw()


func _draw() -> void:
	if projector == null or projector.track == null:
		return
	var track: Track = projector.track
	var z0: float = projector.cam_z + SpriteProjector.NEAR_Z
	var z1: float = projector.cam_z + MAX_DIST_M
	var first: int = track.first_object_at(z0)
	var last: int = first
	while last < track.objects.size() and float(track.objects[last]["z"]) < z1:
		last += 1
	for i in range(last - 1, first - 1, -1):     # de longe para perto
		var o: Dictionary = track.objects[i]
		var d: Dictionary = _def(String(o["kind"]))
		if d.is_empty():
			continue
		var p: Vector3 = projector.project(float(o["x"]), float(o["z"]), 0.0)
		if p.z <= 0.0:
			continue
		var s: float = p.z / float(d["ppm"])
		var size: Vector2 = d["size"] * s
		var pos: Vector2 = Vector2(p.x, p.y) - (d["anchor"] as Vector2) * s
		if pos.x > SpriteProjector.SCREEN_W or pos.x + size.x < 0.0 or size.x > 900.0:
			continue
		draw_texture_rect(d["tex"], Rect2(pos.round(), size.round()), false)
		if d["glow"] != null:
			draw_texture_rect(d["glow"], Rect2(pos.round(), size.round()), false, Color(1, 1, 1, 0.8))
