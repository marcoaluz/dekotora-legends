class_name WorldEnv
extends RefCounted
## Ambiente noturno do mundo 3D: ceu, neblina, brilho (glow), luar. Tudo criado por codigo para
## ficar versionado e facil de ajustar num lugar so.


static func create(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#050514")
	sky_mat.sky_horizon_color = Color("#2b2757")
	sky_mat.ground_horizon_color = Color("#1e1b3d")
	sky_mat.ground_bottom_color = Color("#0b0a14")
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#241f4d")
	env.fog_density = 0.0028
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9db2ff")
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-48, 28, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	parent.add_child(moon)
