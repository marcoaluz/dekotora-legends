class_name RoadDetails
extends RefCounted
## T-199: small roadside detail added to the RoadFurniture boxes (same MultiMesh per 150 m block, no new material):
## - expansion joints on the concrete barrier (dark strip on the sloped face every 9 m) and a bolt plate on top;
## - reflectors on the W guard-rail of the coast (amber, glow at night like the delineators);
## - kilometre posts (キロポスト) every 100 m on the left barrier: white plate + green digits from the sign atlas;
## - emergency telephone boxes (非常電話) every ~1 km on the left verge, orange with a white door;
## - discreet spray tags on the barrier face (Label3D, a few per route, only drawn near the camera).

const JOINT_M: float = 9.0
const TAG_EVERY_M: float = 380.0
const TAGS: PackedStringArray = ["夜露死苦", "爆走", "喧嘩上等", "KANTO", "BAKUSO", "天上天下", "走", "R-246", "仏恥義理"]
const TAG_COLORS: Array[Color] = [Color(0.75, 0.12, 0.12, 0.8), Color(0.08, 0.08, 0.1, 0.75), Color(0.15, 0.3, 0.75, 0.75),
	Color(0.9, 0.9, 0.88, 0.7), Color(0.55, 0.2, 0.65, 0.75)]
const FACE_TILT: float = 0.245                # sloped face of the barrier profile: 0.15 m in over 0.6 m up (RoadMesh)


static func add(f: RoadFurniture, kind: StringName, tunnels: Array[Vector2]) -> void:
	var path: TrackPath = f.path
	var L: float = path.track.length_m
	var evs: TrackEvents = path.track.events
	var right_wall: bool = kind != &"coast" or RoadMesh.deck_height(kind) > 0.0
	var z: float = 4.5
	while z < L - 2.0:                                                       # joints + reflectors
		var p: Vector3 = LaneSections.profile(evs, z)
		if not RoadMesh.in_tunnel(z, tunnels, 2.0) and p.x >= RoadMesh.BARRIER_IN and p.y >= RoadMesh.BARRIER_IN:
			for side in [-1.0, 1.0]:
				if side > 0.0 and not right_wall:
					f._box(z, RoadMesh.RAIL_LAT - 0.03, 0.72, Vector3(0.03, 0.12, 0.12), Color("#ffb347", 0.6))
					continue
				_tilted(f, z, side * (RoadMesh.BARRIER_IN + 0.13), 0.55, Vector3(0.05, 0.64, 0.06), -side * FACE_TILT, Color("#55575c", 0.0))
				f._box(z, side * (RoadMesh.BARRIER_IN + 0.3), 0.86, Vector3(0.16, 0.025, 0.3), Color("#6f7278", 0.0))
		z += JOINT_M
	var font: Font = load(RoadFurniture.SIGN_FONT) as Font
	z = 100.0
	while z < L - 20.0:                                                      # kilometre posts
		if not RoadMesh.in_tunnel(z, tunnels, 4.0) and LaneSections.profile(evs, z).x >= RoadMesh.BARRIER_IN:
			_km_post(f, z)
		z += 100.0
	z = 520.0
	while z < L - 60.0:                                                      # emergency phones
		if not RoadMesh.in_tunnel(z, tunnels, 30.0) and LaneSections.at(evs, z, 30.0) == null:
			var lat: float = -(RoadMesh.BARRIER_IN - 0.45)
			f._box(z, lat, 0.75, Vector3(0.42, 1.5, 0.6), Color("#e8721c", 0.0))
			f._box(z - 0.31, lat, 0.85, Vector3(0.34, 0.8, 0.02), Color("#f2f2ee", 0.0))
			f._box(z, lat, 1.58, Vector3(0.5, 0.08, 0.7), Color("#3a3d44", 0.0))
		z += 1000.0
	var k: int = 0
	z = 210.0
	while z < L - 40.0:                                                      # spray tags
		if not RoadMesh.in_tunnel(z, tunnels, 10.0) and LaneSections.at(evs, z, 10.0) == null:
			var side: float = -1.0 if k % 2 == 0 else 1.0
			if side < 0.0 or right_wall:
				_tag(f, font, z, side, TAGS[(k * 5 + int(z)) % TAGS.size()], TAG_COLORS[k % TAG_COLORS.size()])
		k += 1
		z += TAG_EVERY_M + float((k * 37) % 90)


static func _tilted(f: RoadFurniture, z: float, lat: float, y: float, size: Vector3, tilt: float, col: Color) -> void:
	var b := Basis(Vector3.UP, f.path.yaw_at(z)) * Basis(Vector3.BACK, tilt) * Basis.from_scale(size)
	var t := Transform3D(b, f.path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, y))
	var bi: int = int(z / RoadFurniture.BLOCK_M)
	if not f._blocks.has(bi):
		f._blocks[bi] = []
	f._blocks[bi].append([t, col])


## White plate on a short post on top of the left barrier, km with one decimal in green digits ("1.2").
static func _km_post(f: RoadFurniture, z: float) -> void:
	var lat: float = -(RoadMesh.BARRIER_IN + 0.3)
	f._box(z, lat, 1.0, Vector3(0.06, 0.3, 0.06), Color("#9aa0a8", 0.0))
	f._box(z, lat, 1.32, Vector3(0.62, 0.36, 0.04), Color("#f4f4f0", 0.0))
	var faces: AtlasQuads = f.faces_layer()
	var path: TrackPath = f.path
	var b := Basis(Vector3.UP, path.yaw_at(z))                                # faces the driver (like the gantry text)
	var c: Vector3 = path.world_point(z - 0.03, lat / Track.ROAD_HALF_WIDTH_M, 1.32)
	var tenth: int = roundi(z / 100.0)
	var txt: String = "%d.%d" % [tenth / 10, tenth % 10]
	var x: float = -0.06 * float(txt.length() - 1)
	for ch in txt:
		if ch == ".":
			f._box(z - 0.03, lat + x, 1.2, Vector3(0.04, 0.04, 0.01), Color("#1f7a45", 0.0))
		else:
			faces.add_quad(Transform3D(b * Basis.from_scale(Vector3(0.12, 0.24, 1.0)), c + b.x * x), SignAtlas.uv("g" + ch))
		x += 0.12


static func _tag(f: RoadFurniture, font: Font, z: float, side: float, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 48
	l.pixel_size = 0.0075
	l.outline_size = 4
	l.modulate = col
	l.outline_modulate = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, col.a * 0.6)
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.visibility_range_end = 140.0
	var path: TrackPath = f.path
	var yaw: float = path.yaw_at(z) + (PI * 0.5 if side < 0.0 else -PI * 0.5)    # text faces the road
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -FACE_TILT)
	l.transform = Transform3D(b, path.world_point(z, side * (RoadMesh.BARRIER_IN + 0.095) / Track.ROAD_HALF_WIDTH_M, 0.52))
	f.add_child(l)
