class_name UltraLook
extends RefCounted
## T-189: quality "Ultra" (Settings.quality = 3), PC only. It needs the Forward+ renderer (the PC default since T-189);
## the phone runs Compatibility (`rendering_method.mobile`), where `available()` is false: quality is clamped to Alta
## and nothing here runs, so the phone keeps the exact look and cost it had before.
## Ultra turns on: SDFGI (bounced light), SSAO + SSIL, SSR (wet asphalt reflecting neon), soft 4-split sun shadows on
## a big atlas, FSR2 at native resolution (temporal anti-aliasing), stronger glow, volumetric fog (god rays at
## dawn/dusk, halos around the lamps at night), depth of field during the duel intro and a LUT per time of day.

const ULTRA: int = 3
## Volumetric fog per time of day: density (1/m), albedo, anisotropy (how much light goes forward = god rays).
const VFOG: Dictionary = {
	"dawn": [0.0075, Color(1.0, 0.86, 0.68), 0.72],
	"day": [0.0010, Color(0.92, 0.95, 1.0), 0.55],
	"dusk": [0.0060, Color(1.0, 0.80, 0.70), 0.70],
	"night": [0.0040, Color(0.50, 0.52, 0.60), 0.35],
}


static func renderer() -> String:
	return RenderingServer.get_current_rendering_method()


## Ultra can run here (Forward+). False on the phone (Compatibility) and on PCs that fell back to OpenGL.
static func available() -> bool:
	return renderer() == "forward_plus"


static func max_quality() -> int:
	return ULTRA if available() else 2


static func clamp_quality(q: int) -> int:
	return clampi(q, 0, max_quality())


static func active(q: int) -> bool:
	return q >= ULTRA and available()


## Wet road (lower roughness = sharper reflections) on a COPY of the preset: Ultra at night/dusk (SSR reflects the
## neon) and anything with rain on. Without Ultra and without rain it returns `tod` untouched.
static func tune_tod(tod: TimeOfDay, q: int, rain: bool) -> TimeOfDay:
	if tod == null or not (active(q) or rain):
		return tod
	var t: TimeOfDay = tod.duplicate() as TimeOfDay
	if active(q) and t.headlights:
		t.road_roughness = minf(t.road_roughness, 0.34)
	if rain:
		t.road_roughness = minf(t.road_roughness, 0.18 if active(q) else 0.3)
		t.fog_density *= 1.7
		t.clouds = maxf(t.clouds, 0.9)
		t.saturation *= 0.93
		t.light_energy *= 0.72                          # overcast
		t.cloud_color = t.cloud_color.darkened(0.25)
	return t


## Environment of the race (called by WorldEnv after the normal setup). Nothing below Ultra.
static func apply_env(env: Environment, tod: TimeOfDay, q: int) -> void:
	if not active(q):
		return
	var id: String = String(tod.id)
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.3
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.5                       # bigger cells: the camera moves fast along a long road
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_50_PERCENT    # the world is flat and long
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.45
	env.sdfgi_energy = lerpf(0.55, 0.9, tod.day_amount)   # night: the moon bounce must not light the hills blue
	env.sdfgi_read_sky_light = true
	var vf: Array = VFOG.get(id, VFOG["day"])
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(vf[0])
	env.volumetric_fog_albedo = vf[1]
	env.volumetric_fog_anisotropy = float(vf[2])
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.4
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.glow_intensity = tod.glow_intensity * 1.25      # stronger bloom on the truck lights and the neon
	env.glow_bloom = tod.glow_bloom + 0.03
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 1.0)
	env.set_glow_level(6, 0.5)
	env.adjustment_color_correction = ColorGrade.lut(id)


## Sun / moon: soft cascaded shadows on a big atlas, light shafts in the volumetric fog.
static func apply_sun(sun: DirectionalLight3D, tod: TimeOfDay, q: int) -> void:
	if not available():
		return
	if not active(q):                                   # back to the project defaults (Alta/Media after an Ultra race)
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		return
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.7                    # soft penumbra (the sun is not a point)
	sun.shadow_blur = 1.2
	sun.light_volumetric_fog_energy = 1.6 if tod.day_amount > 0.2 else 0.7


## Resolution and anti-aliasing of the 3D view (all qualities: Ultra and the old table for 0..2).
static func apply_viewport(vp: Viewport, q: int) -> void:
	var qq: int = clamp_quality(q)
	vp.scaling_3d_scale = [0.6, 0.8, 1.0, 1.0][qq]      # fewer pixels on the phone
	if active(qq):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2   # FSR2 at native resolution = temporal AA
		vp.msaa_3d = Viewport.MSAA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = Viewport.MSAA_2X if qq >= 2 else Viewport.MSAA_DISABLED


## Light depth of field for the duel intro (null below Ultra): the trucks stay sharp, the background softens.
static func intro_attributes(q: int) -> CameraAttributesPractical:
	if not active(q):
		return null
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 45.0
	a.dof_blur_far_transition = 60.0
	a.dof_blur_amount = 0.07
	return a
