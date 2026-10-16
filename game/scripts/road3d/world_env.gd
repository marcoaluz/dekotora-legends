class_name WorldEnv
extends RefCounted
## Ambiente noturno do mundo 3D: ceu, neblina, brilho (glow), luar. Tudo criado por codigo para
## ficar versionado e facil de ajustar num lugar so.


static func create(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#141440")
	sky_mat.sky_horizon_color = Color("#6a58b8")
	sky_mat.ground_horizon_color = Color("#8a78d8")
	sky_mat.ground_bottom_color = Color("#2a2260")
	sky_mat.sky_curve = 0.18
	sky_mat.sky_energy_multiplier = 1.3
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#241f4d")
	env.fog_density = 0.0028
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9db2ff")
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-48, 28, 0)
	moon.shadow_enabled = q >= 2
	moon.directional_shadow_max_distance = 90.0
	parent.add_child(moon)
