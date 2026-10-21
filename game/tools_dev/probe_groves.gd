extends SceneTree
## T-186: how many trees of each species RoadsideTrees plants on each route (no window needed).
## Usage: godot --headless --path game -s res://tools_dev/probe_groves.gd


func _init() -> void:
	for rid in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var track: Track = route.build_track()
		var path := TrackPath.new(track)
		var deck: float = RoadMesh.deck_height(route.scenery)
		var none: Callable = func(_z: float, _l: float, _p: Vector3) -> bool: return false
		var trees: Array = RoadsideTrees.place(path, route.scenery, 186 + rid.hash(), deck, none, [])
		var count: Dictionary = {}
		for t in trees:
			count[t[0]] = int(count.get(t[0], 0)) + 1
		var side := Roadside3D.new()                     # the same filters as the race (without the overpass)
		side.path = path
		side.bridges = route.bridges
		side.pole_runs = PowerLineLayout.corridors(PowerLineLayout.poles(rid, route.scenery, track, route.tunnels))
		var why: Dictionary = {}
		var rails: Array = RailwayLayout.lines_for(rid, route.scenery, path)
		var filt: Callable = func(z: float, l: float, p: Vector3) -> bool:
			var b: bool = side._tree_blocked(z, l, p, route.tunnels)
			if b:
				why["bloqueada"] = int(why.get("bloqueada", 0)) + 1
			return b
		var kept: Array = RoadsideTrees.place(path, route.scenery, 186 + rid.hash(), deck, filt, rails)
		print("  com filtros: %d (pontes %s, tuneis %s, fios %s) %s" % [kept.size(), str(route.bridges), str(route.tunnels),
			str(side.pole_runs), str(why)])
		side.free()
		var old: int = 0
		for o in track.objects:
			if String(o["kind"]) == "tree":
				old += 1
		print("%s: %d arvores (antes %d, %.0f m de pista) %s" % [rid, trees.size(), old, track.length_m, str(count)])
	quit()
