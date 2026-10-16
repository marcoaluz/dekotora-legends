class_name TruckView
extends Node2D
## Monta o caminhao em camadas: base + pecas (cada uma em um estado de dano) + brilho (glow).
## Todos os PNG de um caminhao tem o mesmo quadro e ancora, entao basta empilhar na ordem certa.
## A origem deste no e o ponto de ancora (traseira do bau, no chao).

const ANGLES: Array[String] = ["L2", "L1", "C", "R1", "R2"]
const STATES: Array[String] = ["ok", "dent", "broken"]
const BASE_DIR := "res://assets/sprites/truck/base/"
const PARTS_DIR := "res://assets/sprites/parts/"
## Ordem de empilhamento (de baixo para cima), igual ao GDD / PIPELINE.
const SLOT_ORDER: Array[String] = ["side_skirts", "front_bumper", "rear_bumper", "visor", "roof_lights", "andon", "mural", "hubcaps"]

var angle: String = "C"
var _base: Sprite2D
var _base_glow: Sprite2D
var _parts: Dictionary = {}   # id -> {slot, glow, enabled, state, sprite, glow_sprite}
var _anchor: Vector2 = Vector2.ZERO
var _additive: CanvasItemMaterial


func _ready() -> void:
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var meta: Dictionary = _read_json(BASE_DIR + "base.json")
	var a: Array = meta.get("anchor", [0, 0])
	_anchor = Vector2(a[0], a[1])
	_base = _make_sprite(false)
	_base_glow = _make_sprite(true)
	_load_parts()
	refresh()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _make_sprite(additive: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = -_anchor
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if additive:
		s.material = _additive
		s.modulate = Color(1, 1, 1, 0.55)
	add_child(s)
	return s


func _load_parts() -> void:
	var dirs := DirAccess.get_directories_at(PARTS_DIR)
	var entries: Array = []
	for id in dirs:
		var meta: Dictionary = _read_json("%s%s/%s.json" % [PARTS_DIR, id, id])
		if meta.is_empty():
			continue
		entries.append({"id": id, "slot": String(meta.get("slot", "")), "glow": bool(meta.get("glow", false))})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return SLOT_ORDER.find(x["slot"]) < SLOT_ORDER.find(y["slot"]))
	for e in entries:
		_parts[e["id"]] = {
			"slot": e["slot"], "glow": e["glow"], "enabled": true, "state": "ok",
			"sprite": _make_sprite(false),
			"glow_sprite": _make_sprite(true) if e["glow"] else null,
		}


func part_ids() -> Array:
	return _parts.keys()


func set_angle(new_angle: String) -> void:
	angle = new_angle
	refresh()


func set_angle_index(i: int) -> void:
	set_angle(ANGLES[clampi(i, 0, ANGLES.size() - 1)])


func angle_index() -> int:
	return ANGLES.find(angle)


func set_part_enabled(id: String, on: bool) -> void:
	if _parts.has(id):
		_parts[id]["enabled"] = on
		refresh()


func set_part_state(id: String, state: String) -> void:
	if _parts.has(id) and state in STATES:
		_parts[id]["state"] = state
		refresh()


func set_all_states(state: String) -> void:
	for id in _parts:
		set_part_state(id, state)


func refresh() -> void:
	if _base == null:
		return
	_base.texture = _tex("%sbase_%s.png" % [BASE_DIR, angle])
	_base_glow.texture = _tex("%sbase_glow_%s.png" % [BASE_DIR, angle])
	for id in _parts:
		var p: Dictionary = _parts[id]
		var on: bool = p["enabled"]
		var st: String = p["state"]
		var sp: Sprite2D = p["sprite"]
		sp.visible = on
		sp.texture = _tex("%s%s/part_%s_%s_%s.png" % [PARTS_DIR, id, id, st, angle])
		if p["glow"]:
			var gt: Texture2D = _tex("%s%s/%s_glow_%s_%s.png" % [PARTS_DIR, id, id, st, angle])
			var gs: Sprite2D = p["glow_sprite"]
			gs.texture = gt
			gs.visible = on


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
