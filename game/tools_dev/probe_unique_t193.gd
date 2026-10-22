extends SceneTree
## T-193: where the unique car goes on each route (and why other spots are refused). Headless.
func _init() -> void:
	for rid in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var r: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var t: Track = r.build_track()
		var busy: Array[Vector2] = []
		for tu in r.tunnels + r.bridges:
			busy.append(Vector2(tu.x, tu.x + tu.y))
		for o in OverpassLayout.for_route(rid):
			busy.append(Vector2(float(o["z"]), float(o["z"])))
		var spot: Array = UniqueCar.SPOTS[rid]
		var start: float = t.length_m * float(spot[0])
		print("UNIQUE ", rid, " len=", t.length_m, " start=", start, " busy=", busy, " curve(start)=", t.curve_at(start),
			" free(start)=", UniqueCar._free(t, spot, busy, start), " -> z=", UniqueCar.spot_z(t, rid, busy))
	quit()
