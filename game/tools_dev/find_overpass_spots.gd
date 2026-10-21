extends SceneTree
## T-164: lista trechos retos de cada rota onde cabe um viaduto rodoviario cruzando por cima (longe de tuneis,
## trechos de 2 faixas, porticos, pedagio, viadutos de trem e outdoors). Uso:
##   godot --headless --path game -s res://tools_dev/find_overpass_spots.gd


func _init() -> void:
	for rid in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var track: Track = route.build_track()
		var L: float = track.length_m
		var gantries: Array = []
		var gz: float = 320.0
		while gz < L - 120.0:
			gantries.append(gz)
			gz += 650.0
		var line: String = ""
		var z: float = 120.0
		while z < L - 150.0:
			var cmax: float = 0.0
			var dz: float = -90.0
			while dz <= 90.0:
				cmax = maxf(cmax, absf(track.curve_at(z + dz)))
				dz += 10.0
			var ok: bool = cmax < (0.45 if rid == "kanto_2_viaduct" else 0.15)
			ok = ok and not RoadMesh.in_tunnel(z, route.tunnels, 120.0)
			ok = ok and LaneSections.at(track.events, z, 120.0) == null
			ok = ok and absf(z - 150.0) > 120.0 and absf(z - 1500.0) > 120.0 and absf(z - 240.0) > 120.0
			for g in gantries:
				ok = ok and absf(z - float(g)) > 60.0
			if ok:
				line += "%d " % int(z)
			z += 20.0
		print(rid, " L=", int(L), " tuneis=", route.tunnels, " retos: ", line)
		var cs: String = ""
		var zz: float = 0.0
		while zz < L:
			cs += "%d:%.2f " % [int(zz), track.curve_at(zz)]
			zz += 100.0
		print("   curvas ", cs)
	quit()
