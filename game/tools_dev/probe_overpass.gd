extends SceneTree
## T-164: mostra, ao longo do eixo do viaduto, a pista mais perto e o vao livre (depurar onde ele para).
## godot --headless --path game -s res://tools_dev/probe_overpass.gd -- --route=kanto_2_viaduct


func _init() -> void:
	var rid: String = "kanto_2_viaduct"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			rid = a.substr(8)
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var path := TrackPath.new(route.build_track())
	for o in OverpassLayout.for_route(rid):
		var ax: Dictionary = OverpassLayout.axis(path, o)
		print("viaduto z=", o["z"], " topo=", ax["top"])
		var s: float = -80.0
		while s <= 80.0:
			var q: Vector3 = (ax["c"] as Vector3) + (ax["d"] as Vector3) * s
			var n: Dictionary = Overpass3D.nearest_road(path, q)
			print("  s=%5.0f  dist=%6.1f  z=%6.0f  vao=%5.2f" % [s, n["dist"], n["z"], float(ax["top"]) - OverpassLayout.BEAM_BOTTOM - float(n["y"])])
			s += 10.0
		var sec: TrackEvents.Event = LaneSections.at(path.track.events, float(o["z"]), 80.0)
		if sec != null:
			print("  trecho de 2 faixas perto: z=", sec.z, " fim=", sec.end_z())
	quit()
