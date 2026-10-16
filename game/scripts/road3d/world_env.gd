class_name WorldEnv
extends RefCounted
## Ambiente noturno do mundo 3D: ceu, neblina, brilho (glow), luar. Tudo criado por codigo para
## ficar versionado e facil de ajustar num lugar so.


## `indoor` = galpao da garagem: fundo escuro, sem neblina, luz de teto; o ceu continua so para reflexos.
static func create(parent: Node3D, indoor: bool = false) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#101a3a")           # hora azul: ceu azul-petroleo, horizonte rosado
	sky_mat.sky_horizon_color = Color("#b8706a")
	sky_mat.ground_horizon_color = Color("#8a6a78")
	sky_mat.ground_bottom_color = Color("#1c1c2c")
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
	env.fog_light_color = Color("#3a3552")
	env.adjustment_enabled = true                  # um pouco menos saturado e mais contraste = tom mais realista
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.07
	env.fog_density = 0.0028
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	if indoor:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#07080d")
		env.fog_enabled = false
		env.ambient_light_energy = 0.45
		env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#ffcfa8")          # sol baixo do fim de tarde
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-26, 32, 0)
	moon.shadow_enabled = q >= 2
	if indoor:                                     # luz difusa vinda do teto (paineis de LED)
		moon.light_color = Color("#e6ecff")
		moon.light_energy = 0.55
		moon.rotation_degrees = Vector3(-72, 20, 0)
		moon.shadow_enabled = q >= 1
	moon.directional_shadow_max_distance = 90.0
	parent.add_child(moon)
