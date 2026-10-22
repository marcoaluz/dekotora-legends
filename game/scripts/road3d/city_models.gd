class_name CityModels
extends RefCounted
## T-193: textured buildings of docs/Modelos/Cidade (blender/scripts/build_t193_city.py) in the city blocks
## (CityBlocks): some lots get one of these instead of a box. All share one atlas/material, so the buildings of a
## CHUNK_M stretch are merged into one mesh (MeshBatch: one draw call per chunk) seen up to LOD_M; farther away the
## chunk shows plain boxes of the same size with the T-188 facade shader (one MultiMesh per chunk). Visual only.
## Own random generator: the T-188 layout of the blocks (streets, lots, boxes) stays exactly the same.

const DIR := "res://assets/scenery/city/"
const ATLAS := "res://assets/textures/city/bldg_atlas.png"
const CHUNK_M: float = 250.0
const LOD_M: float = 420.0
## model: [first row where it may stand (0 = facing the road), colour of the far box (average of its texture), style]
const SPEC := {
	"bldg_small": [0, Color("#8f6c58"), 3], "bldg_med01": [0, Color("#9b6047"), 3], "bldg_med02": [0, Color("#b9b6b0"), 6],
	"bldg_big01": [1, Color("#9a6a4e"), 2], "bldg_bigwide01": [1, Color("#c9d2da"), 5], "bldg_bigwide02": [1, Color("#a4693f"), 2],
	"bldg_sky01": [2, Color("#7f98b0"), 5], "bldg_sky02": [2, Color("#c8c6c0"), 4]}
const CHANCE: Array[float] = [0.3, 0.4, 0.45]      # per row 0 / 1 / 2+ (halved on the phone: quality <= 1)

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float night = 0.0;
uniform float energy = 2.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.85;
	// the dark glass of the baked texture lights up at night, window by window (about half of them)
	float dark = 1.0 - smoothstep(0.05, 0.16, max(c.r, max(c.g, c.b)));
	vec3 cell = floor(vec3(wpos.x * 0.33, wpos.y / 3.5, wpos.z * 0.33));
	float r = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	EMISSION = vec3(1.0, 0.86, 0.62) * dark * step(0.5, r) * night * energy * 0.7;
}
"""

var placed: int = 0
var tris: int = 0
var _rng := RandomNumberGenerator.new()
var _quality: int = 2
var _meshes: Dictionary = {}       # model -> ArrayMesh with our material
var _sizes: Dictionary = {}        # model -> Vector3 (x across, y height, z along)
var _near: Dictionary = {}         # chunk -> MeshBatch-like list [[mesh, xf]]
var _far: Dictionary = {}          # chunk -> [[Transform3D of the unit box, Color]]


static func enabled() -> bool:
	return not "--no-city-models" in OS.get_cmdline_user_args() and ResourceLoader.exists(ATLAS)


## Textured building material (also the far skyline): photo/baked texture, dark glass lit at night.
static func material(tex: String, tod: TimeOfDay) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("atlas", load(tex) as Texture2D)
	var day: float = tod.day_amount if tod != null else 1.0
	mat.set_shader_parameter("night", 1.0 - day)
	mat.set_shader_parameter("energy", tod.window_energy if tod != null else 2.0)
	return mat


## T-193: "The City" block of towers (docs/Modelos/Cidade/city.fbx) far away on the city route: 3 copies at
## SKYLINE_LAT from the road, alternating sides, sunk a little into the ground. 1 draw call each, no LOD (10 mil tri).
const SKYLINE := "res://assets/scenery/city/city_skyline.glb"
const SKYLINE_TEX := "res://assets/textures/city/skyline_facades.png"
const SKYLINE_AT: Array[float] = [0.22, 0.52, 0.82]
const SKYLINE_LAT: float = 820.0
const SKYLINE_SCALE: float = 0.7


static func add_skyline(parent: Node3D, path: TrackPath, tod: TimeOfDay, keep_out: Array) -> int:
	if not enabled() or not ResourceLoader.exists(SKYLINE) or not ResourceLoader.exists(SKYLINE_TEX):
		return 0
	var src: ArrayMesh = GlbMesh.merged(SKYLINE)
	var mesh := ArrayMesh.new()
	mesh.resource_name = SKYLINE
	var mat: ShaderMaterial = material(SKYLINE_TEX, tod)
	for s in src.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		mesh.surface_set_material(s, mat)
	var n: int = 0
	var length: float = path.track.length_m
	for i in SKYLINE_AT.size():
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var zz: float = length * SKYLINE_AT[i]
		var c: Vector3 = path.world_point(zz, side * SKYLINE_LAT / Track.ROAD_HALF_WIDTH_M)
		if OverpassLayout.blocked(keep_out, c, 320.0):
			continue
		c.y = path.center_at(zz).y - RoadMesh.deck_height(&"city") - 6.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Vector3.UP, path.yaw_at(zz) + float(i) * 1.3) * Basis.from_scale(Vector3.ONE * SKYLINE_SCALE), c)
		parent.add_child(mi)
		n += 1
	return n


func _init(tod: TimeOfDay, seed_: int, quality: int) -> void:
	_rng.seed = seed_ + 193
	_quality = quality
	var mat: ShaderMaterial = material(ATLAS, tod)
	for m in SPEC:
		var p: String = DIR + m + ".glb"
		if not ResourceLoader.exists(p):
			continue
		var src: ArrayMesh = GlbMesh.merged(p)
		var out := ArrayMesh.new()
		out.resource_name = p                       # T-181: the explorer camera shows the file
		for s in src.get_surface_count():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
			out.surface_set_material(out.get_surface_count() - 1, mat)
		_meshes[m] = out
		_sizes[m] = out.get_aabb().size


func model_count() -> int:
	return _meshes.size()


## Tries to put a model on a lot of w (across) x d (along) metres centred at `base` (ground), `by` = basis of the
## lot (x across the road, z along). Returns the size actually used (x, height, z) or Vector3.ZERO (keep the box).
func try_place(base: Vector3, by: Basis, w: float, d: float, row: int, max_h: float, z: float) -> Vector3:
	var chance: float = CHANCE[mini(row, 2)] * (0.5 if _quality <= 1 else 1.0)
	if _meshes.is_empty() or _rng.randf() > chance:
		return Vector3.ZERO
	var fits: Array = []
	for m in _meshes:
		if row < int(SPEC[m][0]):
			continue
		var sz: Vector3 = _sizes[m]
		for turn in [0, 1]:
			var sx: float = sz.x if turn == 0 else sz.z
			var sz_: float = sz.z if turn == 0 else sz.x
			var s: float = minf(minf(w / sx, d / sz_), 1.15)
			if s >= 0.75 and sz.y * s <= max_h:
				fits.append([m, turn, s])
	if fits.is_empty():
		return Vector3.ZERO
	var f: Array = fits[_rng.randi() % fits.size()]
	var m: String = f[0]
	var s: float = f[2]
	var turn: float = float(f[1]) * PI * 0.5 + (PI if _rng.randf() < 0.5 else 0.0)
	var xf := Transform3D(by * Basis(Vector3.UP, turn) * Basis.from_scale(Vector3.ONE * s), base)
	var ci: int = int(floor(z / CHUNK_M))
	if not _near.has(ci):
		_near[ci] = []
		_far[ci] = []
	_near[ci].append([_meshes[m], xf])
	var sz: Vector3 = _sizes[m] * s
	var used := Vector3(sz.x, sz.y, sz.z) if int(f[1]) == 0 else Vector3(sz.z, sz.y, sz.x)
	var col: Color = SPEC[m][1]
	col.a = (float(SPEC[m][2]) + 0.5) / 16.0
	_far[ci].append([Transform3D(by * Basis.from_scale(used), base + Vector3.UP * used.y * 0.5), col])
	placed += 1
	return used


## One mesh per chunk (near, until LOD_M) + one MultiMesh of boxes per chunk (from LOD_M on).
func commit(parent: Node3D, tod: TimeOfDay) -> void:
	if _near.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var far_mat: Material = CityLook.facade(tod)
	for ci in _near:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat: Material = null
		for it in _near[ci]:
			var mesh: ArrayMesh = it[0]
			for s in mesh.get_surface_count():
				st.append_from(mesh, s, it[1])
				mat = mesh.surface_get_material(s)
		var am := ArrayMesh.new()
		var arrays: Array = st.commit_to_arrays()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(0, mat)
		tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null \
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = LOD_M
		mi.set_meta("pieces", _near[ci])            # T-181: FreecamPicker
		parent.add_child(mi)
		var items: Array = _far[ci]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var fm := MultiMeshInstance3D.new()
		fm.multimesh = mm
		fm.material_override = far_mat
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.visibility_range_begin = LOD_M
		parent.add_child(fm)
