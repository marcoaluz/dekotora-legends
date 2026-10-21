class_name ScenicStretch
extends Node3D
## T-188 (etapa 1): builds the new scenery of the pilot stretch of the route (ScenicZone): ground with relief
## (TerrainPatch), mid-distance mountains (MountainRidges), forest on the slopes (SlopeForest) and, in the city,
## blocks with sidewalks, streets, varied roofs and neon signs (CityBlocks). Only visual and deterministic (fixed
## seeds per route); nothing here touches scripts/sim/. `field` is shared with Roadside3D (trees/rocks on the ground).

var field: TerrainField
var zone: Vector2 = ScenicZone.NONE
var blocks: CityBlocks
var ridge_count: int = 0
var forest_count: int = 0


func build(path: TrackPath, route_id: String, kind: StringName, tod: TimeOfDay, zone_: Vector2, keep_out: Array) -> void:
	zone = zone_
	if zone.y <= zone.x:
		return
	var seed_: int = 188 + absi(route_id.hash()) % 1000
	field = TerrainField.new(path, kind, zone, keep_out, seed_)
	var terrain := TerrainPatch.new()
	add_child(terrain)
	terrain.build(field, tod)
	if kind != &"city":
		var ridges := MountainRidges.new()
		add_child(ridges)
		ridges.build(path, kind, tod, zone, seed_)
		ridge_count = ridges.piece_count
		var forest := SlopeForest.new()
		add_child(forest)
		forest.build(field, tod, seed_)
		forest_count = forest.count
	if kind != &"mountain":
		blocks = CityBlocks.new()
		add_child(blocks)
		blocks.build(field, tod, keep_out, seed_)
	print("SCENIC_T188 %s zona=%d-%d terreno=%d tri cordilheira=%d floresta=%d predios=%d" % [route_id, int(zone.x),
		int(zone.y), terrain.tri_count, ridge_count, forest_count, blocks.building_count if blocks != null else 0])
