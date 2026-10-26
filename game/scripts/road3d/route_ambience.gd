class_name RouteAmbience
extends Node3D
## T-217: the route ambience "in the line of the original, but modern": the other carriageway with its median hedge
## and traffic coming the other way (OppositeLayout / OppositeRoad3D / OppositeTraffic3D), stone retaining walls of
## the cuts (CutLayout / StoneWalls3D) and the landmarks that give each route its identity (RouteLandmarks).
## `prepare` registers the layouts BEFORE the other builders run (they keep their things out of the new places);
## `build` draws everything after the terrain exists. Only visual: nothing in scripts/sim/ nor in the network.
## Flags (after --): --no-opposite, --no-walls, --no-landmarks (before/after prints and cost measures).

var opposite: OppositeLayout
var cuts: CutLayout
var road: OppositeRoad3D
var traffic: OppositeTraffic3D
var walls: StoneWalls3D
var landmarks: RouteLandmarks
var danchi: Danchi3D
var signs: SignsT217


static func prepare(path: TrackPath, route_id: String, kind: StringName, tunnels: Array[Vector2],
		bridges: Array[Vector2]) -> void:
	release()
	if not ScenicZone.enabled():
		return                                   # --t188=off: the old look everywhere (no T-217 either)
	if OppositeLayout.enabled():
		OppositeLayout.register(OppositeLayout.new(path, route_id, kind, tunnels, bridges))
	if CutLayout.enabled():
		CutLayout.register(CutLayout.new(path, route_id))
	if DanchiLayout.enabled() and DanchiLayout.RUNS.has(route_id):
		DanchiLayout.register(DanchiLayout.new(path, route_id))


static func release() -> void:
	OppositeLayout.clear_all()
	CutLayout.clear_all()
	DanchiLayout.clear_all()


func build(path: TrackPath, route_id: String, kind: StringName, tod: TimeOfDay, q: int, field: TerrainField,
		clock: Callable, soft_spec: bool, places: PackedStringArray = PackedStringArray(),
		tunnels: Array[Vector2] = []) -> void:
	opposite = OppositeLayout.of(path)
	cuts = CutLayout.of(path)
	if opposite != null and not "--no-opp-road" in OS.get_cmdline_user_args():
		road = OppositeRoad3D.new()
		road.name = "OppositeRoad"
		add_child(road)
		road.build(opposite, tod, q, soft_spec)
		if not "--no-opp-traffic" in OS.get_cmdline_user_args():
			traffic = OppositeTraffic3D.new()
			traffic.name = "OppositeTraffic"
			add_child(traffic)
			traffic.clock = clock
			traffic.build(opposite, tod, q, 217 + absi(route_id.hash()) % 1000)
	if cuts != null and not cuts.runs.is_empty():
		walls = StoneWalls3D.new()
		walls.name = "StoneWalls"
		add_child(walls)
		walls.build(cuts, tod, ScenicShaders.terrain(tod))
	if DanchiLayout.of(path) != null:
		danchi = Danchi3D.new()
		danchi.name = "Danchi"
		add_child(danchi)
		danchi.build(DanchiLayout.of(path), kind, tod)
	if ScenicZone.enabled() and not "--no-signs-t217" in OS.get_cmdline_user_args():
		signs = SignsT217.new()
		signs.name = "SignsT217"
		add_child(signs)
		signs.build(path, route_id, places, tunnels, tod)
	if RouteLandmarks.enabled():
		landmarks = RouteLandmarks.new()
		landmarks.name = "Landmarks"
		add_child(landmarks)
		landmarks.build(path, route_id, kind, tod, q, field)
	print("AMBIENCE_T217 %s contraria=%s (%d tri, %d veiculos) muros=%d (%d tri) danchi=%s placas=%s marcos=%s" % [route_id,
		"sim" if opposite != null else "nao", road.tris if road != null else 0,
		traffic.vehicles.size() if traffic != null else 0, walls.faces if walls != null else 0,
		walls.tris if walls != null else 0, str(danchi.counts) if danchi != null else "-",
		str(signs.counts) if signs != null else "-",
		landmarks.summary() if landmarks != null else "-"])
