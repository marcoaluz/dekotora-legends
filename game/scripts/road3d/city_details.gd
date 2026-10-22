class_name CityDetails
extends RefCounted
## T-199: small geometry that breaks the "box" silhouette of the CityBlocks buildings and coast houses, all unit boxes
## in MultiMeshes per 200 m chunk (one draw call per chunk and layer, material CityLook.props):
## - FAR layer (every building, seen up to FAR_M): cornice at the top, darker plinth band, antennas/masts;
## - NEAR layer (front rows, up to NEAR_M): outdoor AC units on the facade, balconies with rails, fire escapes with
##   landings and stairs, shop awnings (marquises), vertical shop signboards; houses: porch roof, AC unit, vent pipe.
## Own RNG (seeded from the city seed): the lots, buildings and neon of CityBlocks stay exactly the same.

const CHUNK_M: float = 200.0
const NEAR_M: float = 360.0
const FAR_M: float = 1100.0
const FLOOR_M: float = 3.5
const IRON := Color("#3a3e45")
const AWNINGS: Array[Color] = [Color("#b8322c"), Color("#2c5fa8"), Color("#2f7d4a"), Color("#d8d2c4"), Color("#c87a2a"), Color("#6b2a5c")]
const SIGNS: Array[Color] = [Color("#f2efe6"), Color("#f4d23c"), Color("#d8352f"), Color("#1f4e9c"), Color("#f08a24")]

var rng := RandomNumberGenerator.new()
var near_count: int = 0
var far_count: int = 0
var _near: Dictionary = {}           # chunk index -> Array [Transform3D, Color]
var _far: Dictionary = {}


func _init(seed_: int) -> void:
	rng.seed = seed_ * 7 + 199


## A flat-roof building of w (across, toward `to_road`) x d (along `fwd`) x h metres standing on `base`.
## `top` = height of the roof that carries the masts; `front` = first row (more facade detail).
func building(base: Vector3, by: Basis, to_road: Vector3, fwd: Vector3, w: float, d: float, h: float, top: float,
		wall: Color, row: int, shop: bool, front: bool, z: float) -> void:
	var dark: Color = _vary(wall.darkened(0.3))
	_add(_far, z, by, Vector3(w + 0.5, 0.45, d + 0.5), base + Vector3.UP * (h - 0.22), dark)            # cornice
	_add(_far, z, by, Vector3(w + 0.16, 0.5, d + 0.16), base + Vector3.UP * 0.25, _vary(wall.darkened(0.45)))   # plinth
	if top > 24.0 and rng.randf() < 0.45:                                                                 # masts
		for _k in rng.randi_range(1, 2):
			var mh: float = rng.randf_range(4.0, 9.0)
			var p: Vector3 = base + by * Vector3(rng.randf_range(-0.3, 0.3) * w, top + mh * 0.5, rng.randf_range(-0.3, 0.3) * d)
			_add(_far, z, by, Vector3(0.14, mh, 0.14), p, IRON)
			_add(_far, z, by, Vector3(1.4, 0.08, 0.08), p + Vector3.UP * mh * 0.3, IRON)
	if row > 1 or (row == 1 and rng.randf() < 0.5):
		return
	var floors: int = int(h / FLOOR_M)
	var face: Vector3 = base + to_road * (w * 0.5)
	for _k in (rng.randi_range(2, 7) if floors > 1 else 0):                                                 # AC units
		var f: int = rng.randi_range(1, mini(floors - 1, 12))
		var at: Vector3 = face + to_road * 0.25 + fwd * rng.randf_range(-0.42, 0.42) * d + Vector3.UP * (f * FLOOR_M + 0.45)
		_add(_near, z, by, Vector3(0.45, 0.6, 0.85), at, _vary(Color("#c9c9c2")))
	if not shop and floors >= 3 and rng.randf() < 0.35:                                                  # balconies
		var bw: float = d * rng.randf_range(0.55, 0.8)
		var off: Vector3 = fwd * rng.randf_range(-0.1, 0.1) * d
		var rail: Color = _vary(Color("#e2e0d8") if rng.randf() < 0.6 else IRON)
		for f in range(1, mini(floors, 14)):
			var y: float = f * FLOOR_M
			_add(_near, z, by, Vector3(1.1, 0.14, bw), face + off + to_road * 0.55 + Vector3.UP * y, dark)
			_add(_near, z, by, Vector3(0.07, 1.0, bw), face + off + to_road * 1.07 + Vector3.UP * (y + 0.55), rail)
	elif floors >= 4 and floors <= 14 and rng.randf() < 0.3:
		_fire_escape(base, by, to_road, fwd, w, d, floors, z)
	if shop or front:                                                                                     # awning
		var aw: float = d * rng.randf_range(0.6, 0.9)
		_add(_near, z, by, Vector3(1.6, 0.22, aw), face + to_road * 0.8 + Vector3.UP * 3.65, _vary(AWNINGS[rng.randi() % AWNINGS.size()]))
	if front and floors >= 3 and rng.randf() < 0.55:                                                      # vertical signboard
		var sh: float = minf(rng.randf_range(4.0, 9.0), floors * FLOOR_M - 4.0)
		var at2: Vector3 = face + to_road * 0.7 + fwd * (rng.randf_range(-0.4, 0.4) * d) + Vector3.UP * (4.5 + sh * 0.5)
		_add(_near, z, by, Vector3(1.1, sh, 0.22), at2, _vary(SIGNS[rng.randi() % SIGNS.size()]))
		_add(_near, z, by, Vector3(1.2, 0.12, 0.3), at2 + Vector3.UP * (sh * 0.5 + 0.06), IRON)


## Fire escape on one side face (normal +-fwd): landing + rail per floor and a sloped flight between them.
func _fire_escape(base: Vector3, by: Basis, to_road: Vector3, fwd: Vector3, w: float, d: float, floors: int, z: float) -> void:
	var s: float = 1.0 if rng.randf() < 0.5 else -1.0
	var wall: Vector3 = base + fwd * s * (d * 0.5) + to_road * (w * rng.randf_range(-0.15, 0.25))
	var slope := Basis(by.z.normalized(), atan2(FLOOR_M, 2.4) * (1.0 if to_road.dot(by.x) > 0.0 else -1.0))
	for f in range(1, floors):
		var y: float = f * FLOOR_M
		_add(_near, z, by, Vector3(2.6, 0.1, 1.2), wall + fwd * s * 0.6 + Vector3.UP * y, IRON)                 # landing
		_add(_near, z, by, Vector3(2.6, 0.9, 0.05), wall + fwd * s * 1.18 + Vector3.UP * (y + 0.45), IRON)      # rail
		var mid: Vector3 = wall + fwd * s * 0.6 + Vector3.UP * (y - FLOOR_M * 0.5)
		_xf(_near, z, Transform3D(slope * by * Basis.from_scale(Vector3(4.2, 0.08, 0.7)), mid), IRON)          # flight


## Coast house: porch roof over the door (toward the road), AC unit on a side, vent pipe or chimney on the roof.
func house(base: Vector3, by: Basis, w: float, d: float, h: float, flat: bool, z: float, toward: float) -> void:
	var right: Vector3 = by.x.normalized() * toward
	var fwd: Vector3 = by.z.normalized()
	var face: Vector3 = base + right * (w * 0.5)
	_add(_far, z, by, Vector3(w + 0.12, 0.6, d + 0.12), base + Vector3.UP * 0.3, Color("#57544d"))           # plinth band
	_add(_near, z, by, Vector3(1.3, 0.12, rng.randf_range(2.0, 3.2)), face + right * 0.65 + Vector3.UP * 2.5 + fwd * rng.randf_range(-0.3, 0.3) * d, _vary(Color("#4a4d57")))
	_add(_near, z, by, Vector3(0.45, 0.6, 0.8), face + right * 0.25 + fwd * (d * 0.3) + Vector3.UP * 0.6, Color("#cfcfc8"))
	if flat:
		_add(_near, z, by, Vector3(1.0, 0.1, d * 0.6), face + right * 0.5 + Vector3.UP * (FLOOR_M + 0.05), Color("#6b6a66"))
		_add(_near, z, by, Vector3(0.06, 0.9, d * 0.6), face + right * 0.98 + Vector3.UP * (FLOOR_M + 0.5), Color("#e0ded6"))
	elif rng.randf() < 0.6:
		_add(_far, z, by, Vector3(0.5, 1.6, 0.5), base + by * Vector3(rng.randf_range(-0.25, 0.25) * w, h + 1.6, rng.randf_range(-0.2, 0.2) * d), Color("#5d5550"))


func _vary(c: Color) -> Color:
	var k: float = rng.randf_range(0.86, 1.1)
	return Color(c.r * k, c.g * k, c.b * k)


func _add(layer: Dictionary, z: float, by: Basis, size: Vector3, at: Vector3, col: Color) -> void:
	_xf(layer, z, Transform3D(by * Basis.from_scale(size), at), col)


func _xf(layer: Dictionary, z: float, xf: Transform3D, col: Color) -> void:
	var ci: int = int(z / CHUNK_M)
	if not layer.has(ci):
		layer[ci] = []
	layer[ci].append([xf, col])
	if layer == _near:
		near_count += 1
	else:
		far_count += 1


## One MultiMesh per chunk and layer under `parent` (visibility range by layer).
func commit(parent: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat: Material = CityLook.props()
	for pair in [[_near, NEAR_M], [_far, FAR_M]]:
		var layer: Dictionary = pair[0]
		for ci in layer:
			var items: Array = layer[ci]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = box
			mm.instance_count = items.size()
			for i in items.size():
				mm.set_instance_transform(i, items[i][0])
				mm.set_instance_color(i, items[i][1])
			var mi := MultiMeshInstance3D.new()
			mi.name = "CityDetails"
			mi.multimesh = mm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = float(pair[1])
			mi.visibility_range_end_margin = 30.0
			parent.add_child(mi)
