extends TestCase
## T-195: road drawn past the finish line (destination city) without touching the simulation, and the Marco's
## locomotive in the trains.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func test_runout_extends_the_drawn_road_only() -> void:
	for rid in ROUTES:
		var track: Track = (load("res://data/routes/%s.tres" % rid) as RouteDef).build_track()
		var L: float = track.length_m
		var plain := TrackPath.new(track)
		var ext := TrackPath.new(track, ArrivalLayout.RUNOUT[rid])
		check_near(track.length_m, L, 0.001, rid + ": the simulation track keeps its length")
		check_near(plain.end_m(), L, 0.001, rid + ": no runout = ends at the finish")
		check(ext.end_m() >= L + 900.0, rid + ": road goes on ~1 km after the finish (%.0f)" % (ext.end_m() - L))
		for z in [0.0, L * 0.3, L * 0.77, L - 1.0]:
			check(plain.center_at(z).distance_to(ext.center_at(z)) < 0.001, rid + ": same road before the finish (z %.0f)" % z)
		var prev: float = ext.yaw_at(L - 2.0)
		var z2: float = L
		var max_step: float = 0.0
		while z2 < ext.end_m() - 2.0:                          # no kink: yaw changes smoothly
			var y: float = ext.yaw_at(z2)
			max_step = maxf(max_step, absf(angle_difference(prev, y)))
			prev = y
			z2 += 2.0
		check(max_step < 0.01, rid + ": smooth runout (max %.4f rad per 2 m)" % max_step)
		check(ext.center_at(L + 500.0).distance_to(plain.center_at(L)) > 400.0, rid + ": trucks keep moving after the finish")


func test_coast_city_only_on_the_land_side() -> void:
	check_eq(ArrivalLayout.city_sides(&"coast"), [-1.0] as Array[float], "coast: sea stays on the right")
	check_eq(ArrivalLayout.city_sides(&"mountain").size(), 2, "mountain: both sides")


func test_marco_locomotive_leads_the_first_train() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t: RailTraffic.Train = RailTraffic.make_train(RailTraffic.Type.FREIGHT, rng, true)
	check_eq(t.models[0], RailTraffic.MARCO_LOCO, "1st train: the Marco's locomotive in front")
	var lead: int = 0
	for _i in 200:
		var u: RailTraffic.Train = RailTraffic.make_train(RailTraffic.Type.FREIGHT, rng)
		if u.models[0] == RailTraffic.MARCO_LOCO:
			lead += 1
		check(u.models.size() >= 7 and u.models.size() <= 10, "7 to 10 cars")
	check(lead > 120 and lead < 180, "most trains led by it (%d of 200)" % lead)
