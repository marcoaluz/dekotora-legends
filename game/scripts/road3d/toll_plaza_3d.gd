class_name TollPlaza3D
extends Node3D
## T-207: the toll plaza of the route drawn in 3D from the SAME TollPlaza the simulation uses (island = physics):
## structure (TollParts), paint (TollPaint), the 2 gate bars (open when a vehicle comes in their passage, only visual),
## light pools under the canopy and ONE real light that follows the player under it at night. Only presentation.
## Cost: 4 materials in 4 nodes (atlas, concrete, glow, paint) + 2 bars + pools at night = ~7 draw calls when in view,
## ~6 k triangles; the light is on only while the player is under the canopy (dusk/night).

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float energy = 1.0;
void fragment() {
	float blink = COLOR.a < 0.5 ? (0.12 + 0.88 * step(0.5, fract(TIME * 0.85))) : 1.0;
	ALBEDO = texture(atlas, UV).rgb * COLOR.rgb * energy * blink;
}
"""
const RANGE_M: float = 900.0
const BAR_LEN: float = 3.1
const BAR_OPEN: float = deg_to_rad(84.0)
const BAR_SPEED: float = 2.6                # rad/s
const BAR_LOOK_M: float = 48.0              # a vehicle this far before the bar opens it
const LIGHT_SPAN_M: float = 16.0            # the real light follows the player this far before/after the booth

var plaza: TollPlaza
var path: TrackPath
var lit: bool = false
var tris: int = 0
var _bars: Array = []                       # [Node3D pivot, side (-1 left passage, +1 right), angle]
var _omni: OmniLight3D
var _atlas: Texture2D


static func enabled(track: Track) -> bool:
	return track != null and track.toll != null and not "--old-toll" in OS.get_cmdline_user_args()


func build(path_: TrackPath, tod: TimeOfDay, quality: int) -> void:
	path = path_
	plaza = path.track.toll
	name = "TollPlaza3D"
	lit = tod.lamps_on
	_atlas = load(TollAtlas.ATLAS) as Texture2D
	var g := TollGeo.new(path, plaza)
	TollPaint.build(g)
	TollParts.build(g, lit)
	g.commit(self, _materials(tod), RANGE_M)
	tris = g.tris
	_build_bars(g)
	if lit:
		_build_pools(g, tod)
		if quality >= 1:
			_omni = OmniLight3D.new()
			_omni.light_color = Color(0.86, 0.92, 1.0)
			_omni.omni_range = 13.0
			_omni.omni_attenuation = 1.2
			_omni.light_energy = 0.0
			_omni.shadow_enabled = false
			_omni.visible = false
			add_child(_omni)
	print("TOLL_T207 z=%.0f ilha=%.0f..%.0f triangulos=%d luz=%s noite=%s" % [plaza.z, plaza.nose_z(), plaza.tail_z(), tris,
		str(_omni != null), str(lit)])


func _materials(tod: TimeOfDay) -> Dictionary:
	var atlas := StandardMaterial3D.new()
	atlas.albedo_texture = _atlas
	atlas.vertex_color_use_as_albedo = true
	atlas.roughness = 0.62
	atlas.metallic_specular = 0.35
	atlas.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var conc := StandardMaterial3D.new()
	conc.albedo_texture = load(RoadMesh.TEX_DIR + "concrete_streaks.png") as Texture2D
	conc.albedo_color = Color(0.93, 0.93, 0.9)
	conc.vertex_color_use_as_albedo = true
	conc.roughness = 0.88
	conc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var band := StandardMaterial3D.new()          # coloured pavement (ETC purple, 一般 green) and its letters
	band.albedo_texture = _atlas
	band.vertex_color_use_as_albedo = true
	band.roughness = 0.6
	band.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var paint := StandardMaterial3D.new()         # white lines and zebra: glow at night like the road lines (RoadMesh "line")
	paint.albedo_color = Color("#f2efe6")
	paint.roughness = 0.5
	if tod.line_emission > 0.0:                   # (an emission TEXTURE is ignored by the Compatibility renderer: the
		paint.emission_enabled = true             #  coloured bands went white at night, so they have their own material)
		paint.emission = Color("#f2efe6")
		paint.emission_energy_multiplier = tod.line_emission
	var sh := Shader.new()
	sh.code = GLOW_SHADER
	var glow := ShaderMaterial.new()
	glow.shader = sh
	glow.set_shader_parameter("atlas", _atlas)
	glow.set_shader_parameter("energy", 2.3 if lit else 1.25)
	return {"atlas": atlas, "concrete": conc, "paint": paint, "band": band, "glow": glow}


# ---------------------------------------------------------------- gate bars
func _build_bars(g: TollGeo) -> void:
	var stripes: Rect2 = TollAtlas.uv("stripes")
	var post := TollGeo.new(path, plaza)
	for s in [-1.0, 1.0]:
		var px: float = 1.45 if s > 0.0 else -(TollPlaza.OUTER_FACE_M + 0.35)   # post on the island LEFT of the passage
		var z: float = plaza.z + TollParts.BAR_DZ
		post.box("atlas", false, z - 0.16, z + 0.16, px - 0.16, px + 0.16, TollParts.ISLAND_TOP, 1.2,
			{"front": stripes, "back": stripes, "left": stripes, "right": stripes, "top": TollAtlas.uv("dark")})
		var pivot := Node3D.new()
		pivot.position = g.rp(z, px + 0.16, 1.0)
		pivot.basis = Basis(Vector3.UP, path.yaw_at(z))
		add_child(pivot)
		var arm := TollGeo.new(path, plaza)                          # arm along local +X (to the right of the road)
		arm.o = Vector3.ZERO
		arm.fwd = Vector3(0, 0, -1)
		arm.right = Vector3(1, 0, 0)
		arm.box("atlas", true, -0.05, 0.05, 0.0, BAR_LEN, -0.06, 0.06, {"front": stripes, "back": stripes, "top": stripes,
			"bottom": stripes})
		arm.commit(pivot, {"atlas": _mat_of("atlas")}, RANGE_M)
		_bars.append([pivot, s, 0.0])
	post.commit(self, {"atlas": _mat_of("atlas")}, RANGE_M)


func _mat_of(key: String) -> Material:
	var mi: MeshInstance3D = get_node_or_null("Toll_" + key) as MeshInstance3D
	return mi.mesh.surface_get_material(0) if mi != null else StandardMaterial3D.new()


## Light pools on the asphalt under the canopy (additive, cool LED white), like the sodium pools of the lamp posts.
func _build_pools(g: TollGeo, tod: TimeOfDay) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.88, 0.94, 1.0, 1.0))
	grad.set_color(1, Color(0.8, 0.9, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, clampf(tod.pool_energy * 0.85, 0.0, 1.0))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var pools := TollGeo.new(path, plaza)
	var full := Rect2(0, 0, 1, 1)
	for x in [-TollPaint.PASS_X, TollPaint.PASS_X]:
		pools.road_quad("pool", plaza.z - 13.0, plaza.z + 13.0, x - 3.4, x + 3.4, x - 3.4, x + 3.4, 0.05, full)
	for x in [-TollPlaza.OUTER_FACE_M - 1.0, 0.0, TollPlaza.OUTER_FACE_M + 1.0]:
		pools.road_quad("pool", plaza.z - 9.0, plaza.z + 9.0, x - 1.6, x + 1.6, x - 1.6, x + 1.6, TollParts.ISLAND_TOP + 0.04, full)
	pools.commit(self, {"pool": m}, RANGE_M)


## Every frame (offline and online): gate bars open for the vehicles coming in their passage; the real light goes
## with the player under the canopy. Reads the simulation only.
func update(sim: RaceSim, player_z: float, player_x: float, dt: float) -> void:
	for b in _bars:
		var want: bool = _vehicle_coming(sim, float(b[1]))
		var a: float = move_toward(float(b[2]), BAR_OPEN if want else 0.0, BAR_SPEED * dt)
		if a != float(b[2]):
			b[2] = a
			var piv: Node3D = b[0]
			piv.basis = Basis(Vector3.UP, path.yaw_at(plaza.z + TollParts.BAR_DZ)) * Basis(Vector3.BACK, a)
	if _omni != null:
		var d: float = absf(player_z - plaza.z)
		var f: float = clampf(1.0 - (d - 6.0) / (LIGHT_SPAN_M - 6.0), 0.0, 1.0)
		_omni.visible = f > 0.01
		if _omni.visible:
			var lane_x: float = (-TollPaint.PASS_X if player_x < 0.0 else TollPaint.PASS_X) / Track.ROAD_HALF_WIDTH_M
			_omni.global_position = path.world_point(clampf(player_z, plaza.z - TollParts.CANOPY_DZ + 1.0,
				plaza.z + TollParts.CANOPY_DZ - 1.0), lane_x, TollParts.CANOPY_H0 - 0.6)
			_omni.light_energy = 1.7 * f


func _vehicle_coming(sim: RaceSim, side: float) -> bool:
	var bz: float = plaza.z + TollParts.BAR_DZ
	if sim == null:
		return false
	for t in sim.trucks:
		if t.x * side > 0.15 and t.z + t.length > bz - BAR_LOOK_M and t.z < bz + 1.5:
			return true
	if sim.traffic != null:
		for c in sim.traffic.cars:
			if c.x * side > 0.15 and c.z + c.length > bz - BAR_LOOK_M * 0.6 and c.z < bz + 1.0:
				return true
	return false
