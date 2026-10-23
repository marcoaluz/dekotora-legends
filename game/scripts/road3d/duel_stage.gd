class_name DuelStage
extends Node3D
## Set of the duel opening (T-156, redone in T-204): a black studio far below the race world (nothing of the road is
## in view) with purple ground fog (DuelFog), a glossy black floor, a key light, two violet rim lights, the light of
## the strike, and the two guardians of our own art behind the trucks inside their flame auras: RAIJIN (thunder,
## ring of drums) behind the player on the left and FUJIN (wind, wind bag) behind the rival on the right.
## The camera gets the studio Environment (black background, glow) while the opening runs; DuelIntro gives the
## race's own one back at the end. Cost: ~8 draw calls + the trucks; 4 lights.

const ORIGIN := Vector3(0.0, -400.0, 0.0)
const GOD_TEX: Array[String] = ["res://assets/textures/duel/raijin.png", "res://assets/textures/duel/fujin.png"]
const AURA_TEX := "res://assets/textures/duel/aura.png"
const AURA_TINT: Array[Color] = [Color(1.0, 0.72, 0.28), Color(0.3, 0.9, 1.0)]   # thunder gold / wind cyan
const GOD_X: float = 9.0                 # guardians stand behind and outside the trucks
const GOD_Z: float = -17.0
const GOD_H: float = 13.0                # m (the art is 1024x1280)
const GOD_BASE_Y: float = 1.0            # bottom of the cloud when fully risen (hidden by the trucks)

var quality: int = 1
var fog: DuelFog
var _gods: Array[MeshInstance3D] = []
var _auras: Array[MeshInstance3D] = []
var _strike: OmniLight3D
var _env: Environment


func build(q: int) -> void:
	position = ORIGIN
	quality = q
	_floor()
	_lights()
	fog = DuelFog.new()
	add_child(fog)
	fog.build(UltraLook.active(q))
	for n in 2:
		_guardian(n)


## Environment for the studio camera: black background, violet ambience, glow; Ultra adds volumetric fog and
## reflections on the floor.
func environment() -> Environment:
	if _env != null:
		return _env
	# Black studio "sky" with a faint violet band at the horizon. It is the background AND the reflection of the
	# chrome (the Compatibility renderer draws the sky even with a colour background, so the sky is the background).
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#010002")
	sky_mat.sky_horizon_color = Color("#2c1450")
	sky_mat.sky_curve = 0.06
	sky_mat.ground_horizon_color = Color("#1c0c32")
	sky_mat.ground_bottom_color = Color("#010002")
	sky_mat.ground_curve = 0.04
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3c2a5c")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("#120820")
	env.fog_density = 0.016
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	env.glow_enabled = quality >= 1
	env.glow_intensity = 0.7
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(4, 0.4)
	if UltraLook.active(quality):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_albedo = Color(0.6, 0.45, 1.0)
		env.volumetric_fog_length = 70.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_sky_affect = 0.0
		env.ssr_enabled = true
	_env = env
	return env


## Every frame of the opening: guardians rising behind the trucks, auras turning and pulsing, fog drifting, the
## light of the strike.
func update(t: float, reduced: bool) -> void:
	var vis: float = DuelPlan.guard_in(t)
	for n in 2:
		var side: float = -1.0 if n == 0 else 1.0
		var rise: float = 1.0 - pow(1.0 - vis, 2.0)
		var y: float = lerpf(GOD_BASE_Y - 3.0, GOD_BASE_Y, rise) + 0.12 * sin(t * 2.2 + float(n) * 1.7) * vis
		_gods[n].visible = vis > 0.0
		_gods[n].position = Vector3(side * GOD_X, y + GOD_H * 0.5, GOD_Z)
		(_gods[n].material_override as StandardMaterial3D).albedo_color = Color(1.06, 1.06, 1.06, vis)
		_auras[n].visible = vis > 0.0
		_auras[n].position = Vector3(side * GOD_X, y + GOD_H * 0.6, GOD_Z - 0.4)
		var pulse: float = 1.0 + 0.05 * sin(t * 6.0 + float(n))
		_auras[n].basis = Basis(Vector3.BACK, t * 0.35 * side).scaled(Vector3.ONE * lerpf(0.6, 1.0, rise) * pulse)
		var tint: Color = AURA_TINT[n]
		(_auras[n].material_override as StandardMaterial3D).albedo_color = Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6, 0.85 * vis)
	fog.update(t)
	var bs: Vector2 = DuelPlan.bolt_state(t, reduced)
	_strike.visible = bs.y > 0.0
	_strike.light_energy = (4.0 if reduced else 14.0) * bs.y * bs.x


# ---------------------------------------------------------------- pieces

func _floor() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240.0, 240.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#0a0710")
	m.roughness = 0.22
	m.metallic_specular = 0.6
	pm.material = m
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Floor"
	add_child(mi)


func _lights() -> void:
	var key := SpotLight3D.new()                                  # above and in front of the trucks
	key.light_color = Color("#f2eaff")
	key.light_energy = 5.0
	key.spot_range = 45.0
	key.spot_angle = 38.0
	key.spot_angle_attenuation = 1.4
	key.shadow_enabled = quality >= 2
	key.transform = Transform3D(Basis.looking_at(Vector3(0.0, 1.0, -3.0) - Vector3(0.0, 12.0, 13.0), Vector3.UP), Vector3(0.0, 12.0, 13.0))
	add_child(key)
	for s in [-1.0, 1.0]:                                         # violet rim lights behind the trucks
		var rim := OmniLight3D.new()
		rim.light_color = Color("#a24cff")
		rim.light_energy = 4.0
		rim.omni_range = 20.0
		rim.position = Vector3(s * 7.0, 5.0, -13.0)
		add_child(rim)
	_strike = OmniLight3D.new()                                   # the lightning hitting the floor between them
	_strike.light_color = Color(0.82, 0.78, 1.0)
	_strike.omni_range = 30.0
	_strike.position = Vector3(0.0, 6.0, -2.0)
	_strike.visible = false
	add_child(_strike)


func _guardian(n: int) -> void:
	var god := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(GOD_H * 1024.0 / 1280.0, GOD_H)
	god.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.albedo_texture = load(GOD_TEX[n]) as Texture2D
	m.disable_fog = true
	god.material_override = m
	god.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	god.visible = false
	god.name = "Raijin" if n == 0 else "Fujin"
	var aura := MeshInstance3D.new()
	var aq := QuadMesh.new()
	aq.size = Vector2(GOD_H * 1.12, GOD_H * 1.12)
	aura.mesh = aq
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	am.albedo_texture = load(AURA_TEX) as Texture2D
	am.disable_fog = true
	aura.material_override = am
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	aura.name = "Aura" + god.name
	add_child(aura)
	add_child(god)
	_auras.append(aura)
	_gods.append(god)
