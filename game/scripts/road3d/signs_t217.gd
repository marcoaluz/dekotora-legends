class_name SignsT217
extends Node3D
## T-217: more Japanese road signs with real text (Noto Sans JP, as the other signs):
## - BLUE signs of the general roads and of the services, on the left (Japan): route guide at the exit (国道 + towns
##   with arrows), 非常駐車帯 (emergency parking bay) and ハイウェイラジオ 1620kHz (highway radio);
## - the BACKS of the green gantry signs of the other carriageway (grey plates on a truss over its two lanes), as seen
##   from our side.
## Panels and frames: one MeshBatch-like SurfaceTool per route (1 call); texts: Label3D (cut at 380 m).

const BLUE := Color("#1b4fa8")
const GREEN := Color("#1f7a4f")
const POST := Color("#8e939a")
const LAT_LEFT: float = -(RoadMesh.BARRIER_IN + 0.3)       # on the left barrier (RoadSigns.SIDE_LAT)
const OPP_GANTRY_EVERY: float = 720.0

var path: TrackPath
var counts: Dictionary = {}
var _st: SurfaceTool
var _font: Font
var _level: float = 1.0


func build(path_: TrackPath, route_id: String, places: PackedStringArray, tunnels: Array[Vector2], tod: TimeOfDay) -> void:
	path = path_
	_font = load(RoadFurniture.SIGN_FONT) as Font
	_level = AtlasQuads.level_for(tod)
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L: float = path.track.length_m
	var cuts: CutLayout = CutLayout.of(path)
	var free := func(z: float) -> bool:
		if RoadMesh.in_tunnel(z, tunnels, 80.0) or LaneSections.at(path.track.events, z, 40.0) != null:
			return false
		if cuts != null and cuts.height(z, -1.0) > 0.05:
			return false
		var g: float = fposmod(z - RoadSigns.GANTRY_FIRST, RoadSigns.GANTRY_EVERY)
		return minf(g, RoadSigns.GANTRY_EVERY - g) > 60.0 and z > 500.0 and z < L - 120.0
	var a: String = _kanji(places, 3)
	var b: String = _kanji(places, 4)
	for spec in [[L - 640.0, "guide", L * 0.55], [L * 0.38, "parking", L * 0.28], [L * 0.62, "radio", L * 0.2]]:
		var z: float = _find(float(spec[0]), free)
		if z < 0.0:
			z = _find(float(spec[2]), free)
		if z < 0.0:
			continue
		counts[String(spec[1]) + "_z"] = int(z)
		match String(spec[1]):
			"guide":
				_guide(z, a, b, places)
			"parking":
				_plate(z, Vector2(3.4, 2.0), BLUE, [["非常駐車帯", 0.42, 0.4], ["Emergency Parking", -0.45, 0.22]])
			"radio":
				_plate(z, Vector2(3.6, 1.9), BLUE, [["ハイウェイラジオ", 0.42, 0.34], ["1620kHz", -0.42, 0.4]])
		counts[String(spec[1])] = int(counts.get(String(spec[1]), 0)) + 1
	if OppositeLayout.of(path) != null:
		var z: float = RoadSigns.GANTRY_FIRST + OPP_GANTRY_EVERY * 0.5
		while z < L - 100.0:
			if not RoadMesh.in_tunnel(z, tunnels, 60.0) and not RoadMesh.in_tunnel(z, OppositeLayout.of(path).bridges, 20.0):
				_opp_gantry(z)
			z += OPP_GANTRY_EVERY
	var mesh: ArrayMesh = _st.commit()
	if mesh != null and mesh.get_surface_count() > 0:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED       # like the other signs: level by the time of day
		m.albedo_color = Color(_level, _level, _level)
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _kanji(places: PackedStringArray, i: int) -> String:
	if places.is_empty():
		return "東京"
	var p: String = places[mini(i, places.size() - 1)]
	return String(RoadFurniture.KANJI.get(p, p))


func _romaji(places: PackedStringArray, i: int) -> String:
	if places.is_empty():
		return "Tokyo"
	var p: String = places[mini(i, places.size() - 1)]
	return String(RoadFurniture.ROMAJI.get(p, p))


func _find(z: float, free: Callable) -> float:
	for k in 12:
		var zz: float = z + ceilf(k / 2.0) * 20.0 * (1.0 if k % 2 == 0 else -1.0)
		if free.call(zz):
			return zz
	return -1.0


func _basis(z: float) -> Basis:
	return Basis(Vector3.UP, path.yaw_at(z))


func _at(z: float, lat: float, h: float) -> Vector3:
	return path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, h)


func _box(b: Basis, c: Vector3, size: Vector3, col: Color) -> void:
	Ribbon.box(_st, b, c, size, col)


## Blue plate on two posts on the left; `lines` = [text, y offset from the centre (m), letter height (m)].
func _plate(z: float, size: Vector2, col: Color, lines: Array, top: float = 4.4) -> Vector3:
	var b: Basis = _basis(z)
	var c: Vector3 = _at(z, LAT_LEFT, top - size.y * 0.5)
	for sx in [-0.55, 0.55]:
		_box(b, _at(z, LAT_LEFT + sx, (top - size.y) * 0.5) - b.z * 0.08, Vector3(0.12, top - size.y + 0.3, 0.12), POST)
	_box(b, c, Vector3(size.x + 0.12, size.y + 0.12, 0.08), Color(0.95, 0.95, 0.95))       # white border
	_box(b, c + b.z * 0.01, Vector3(size.x, size.y, 0.1), col)
	for ln in lines:
		_text(String(ln[0]), b, c + b.y * float(ln[1]) + b.z * 0.08, float(ln[2]))
	return c


## Route guide of the general road at the exit: 国道 shield + two towns with arrows.
func _guide(z: float, a: String, b: String, places: PackedStringArray) -> void:
	var c: Vector3 = _plate(z, Vector2(4.8, 3.0), BLUE, [], 5.2)
	var bs: Basis = _basis(z)
	_box(bs, c + bs.y * 0.95 + bs.z * 0.07, Vector3(1.3, 0.7, 0.02), Color(0.95, 0.95, 0.95))   # 国道 shield
	_text("国道1号", bs, c + bs.y * 0.95 + bs.z * 0.09, 0.32, Color(0.11, 0.31, 0.66))
	_text("← %s" % a, bs, c + bs.y * 0.2 - bs.x * 0.6 + bs.z * 0.08, 0.42)
	_text(_romaji(places, 3), bs, c + bs.y * -0.25 - bs.x * 0.6 + bs.z * 0.08, 0.2)
	_text("%s →" % b, bs, c + bs.y * -0.65 + bs.x * 0.7 + bs.z * 0.08, 0.42)
	_text(_romaji(places, 4), bs, c + bs.y * -1.1 + bs.x * 0.7 + bs.z * 0.08, 0.2)


func _text(t: String, b: Basis, pos: Vector3, letter_h: float, col: Color = Color(0.97, 0.97, 0.95)) -> void:
	var l := Label3D.new()
	l.text = t
	l.font = _font
	l.font_size = 64
	l.pixel_size = letter_h / 64.0 * 1.35
	l.outline_size = 0
	l.modulate = col * Color(_level, _level, _level)
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = 380.0
	l.transform = Transform3D(b, pos)
	add_child(l)


## Gantry of the other carriageway seen from behind: two posts outside its lanes, a truss beam, two grey plates.
func _opp_gantry(z: float) -> void:
	var b: Basis = _basis(z)
	var l0: float = OppositeLayout.ROAD_IN - 0.3
	var l1: float = OppositeLayout.ROAD_OUT + 0.9
	for lat in [l0, l1]:
		_box(b, _at(z, lat, 3.6), Vector3(0.35, 7.2, 0.35), POST)
	var mid: float = (l0 + l1) * 0.5
	_box(b, _at(z, mid, 7.0), Vector3(l1 - l0 + 0.4, 0.5, 0.5), POST)
	_box(b, _at(z, mid, 7.6), Vector3(l1 - l0 + 0.4, 0.12, 0.5), POST)
	for k in 2:
		var lat: float = OppositeLayout.LANE0 + 1.75 + float(k) * 3.5
		_box(b, _at(z, lat, 5.6) - b.z * 0.35, Vector3(3.2, 2.2, 0.08), Color(0.62, 0.64, 0.66))   # back of the plate
		_box(b, _at(z, lat, 5.6) - b.z * 0.42, Vector3(3.3, 2.3, 0.04), GREEN * 0.9)              # green edge visible
	counts["opp_gantry"] = int(counts.get("opp_gantry", 0)) + 1
