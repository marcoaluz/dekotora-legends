class_name CloudShadows
extends Node3D
## T-189 (vida): shadows of clouds drifting over the ground, the road and the trucks (by day). Each shadow is a big
## Decal (box projected from above) with a soft noise blob; a few of them drift with the wind and are sent ahead
## again when they fall behind. Decals exist only in Forward+ (PC): on the phone (Compatibility) this node is never
## created. Only visual.

const COUNT: int = 9
const SIZE_MIN: float = 140.0
const SIZE_MAX: float = 260.0
const WIND := Vector3(4.5, 0.0, 2.8)          # m/s, same direction as the tree sway (LifeWind wind_dir)

var path: TrackPath
var _decals: Array[Decal] = []
var _rng := RandomNumberGenerator.new()


static func available(tod: TimeOfDay) -> bool:
	return UltraLook.available() and tod.day_amount >= 0.5 and tod.clouds > 0.2


func setup(path_: TrackPath, route_id: String, tod: TimeOfDay) -> void:
	path = path_
	_rng.seed = 1892 + route_id.hash()
	var tex: ImageTexture = blob_texture(1892 + route_id.hash())
	for i in COUNT:
		var d := Decal.new()
		var s: float = _rng.randf_range(SIZE_MIN, SIZE_MAX)
		d.size = Vector3(s, 160.0, s * _rng.randf_range(0.6, 1.0))
		d.texture_albedo = tex
		d.modulate = Color(0.0, 0.0, 0.03, 0.4 * clampf(tod.clouds, 0.0, 1.0))
		d.albedo_mix = 1.0
		d.upper_fade = 0.0
		d.lower_fade = 0.0
		d.distance_fade_enabled = true
		d.distance_fade_begin = 900.0
		d.distance_fade_length = 300.0
		d.rotation.y = _rng.randf_range(0.0, TAU)
		d.cull_mask = 0xFFFFF
		add_child(d)
		_decals.append(d)
		d.set_meta("placed", false)


## Soft cloud blob: fbm noise inside a round falloff (alpha only; the decal colour is black).
static func blob_texture(seed_: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.045
	n.fractal_octaves = 4
	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u: float = (float(x) / size - 0.5) * 2.0
			var v: float = (float(y) / size - 0.5) * 2.0
			var fall: float = clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0)
			var a: float = smoothstep(0.32, 0.75, (n.get_noise_2d(x, y) * 0.5 + 0.5) * 0.7 + fall * 0.65) * smoothstep(0.0, 0.35, fall)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _place(d: Decal, player_z: float, first: bool) -> void:
	var z: float = player_z + (_rng.randf_range(-60.0, 650.0) if first else _rng.randf_range(450.0, 800.0))
	z = clampf(z, 0.0, path.track.length_m)
	var lat: float = _rng.randf_range(-160.0, 160.0)
	d.global_position = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, 20.0)
	d.set_meta("placed", true)


func update(dt: float, player_z: float) -> void:
	if path == null:
		return
	var here: Vector3 = path.center_at(player_z)
	var fwd: Vector3 = path.forward_at(player_z)
	for d in _decals:
		if not bool(d.get_meta("placed")):
			_place(d, player_z, true)
		d.global_position += WIND * dt
		var rel: Vector3 = d.global_position - here
		if rel.dot(fwd) < -220.0 or rel.length() > 1300.0:
			_place(d, player_z, false)
