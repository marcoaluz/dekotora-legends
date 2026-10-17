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
	if not indoor:                                  # PROTOTIPO: noite profunda com estrelas e lua
		var sh := Shader.new()
		sh.code = """shader_type sky;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
	float y = EYEDIR.y;
	vec3 top = vec3(0.006, 0.009, 0.03);
	vec3 mid = vec3(0.03, 0.04, 0.10);
	vec3 glow = vec3(0.22, 0.09, 0.05);           // brilho laranja da cidade no horizonte
	vec3 c = mix(mid, top, smoothstep(0.0, 0.5, y));
	c += glow * exp(-max(y, 0.0) * 14.0);
	vec2 uv = vec2(atan(EYEDIR.x, EYEDIR.z), asin(clamp(y, -1.0, 1.0))) * 140.0;
	vec2 cell = floor(uv);
	float s = h(cell);
	float star = step(0.985, s) * smoothstep(0.08, 0.4, y) * (0.5 + 0.5 * h(cell + 7.0));
	c += vec3(star) * 2.5;
	vec3 md = normalize(vec3(-0.5, 0.35, -0.8));
	float m = smoothstep(0.9993, 0.9996, dot(EYEDIR, md));
	c += vec3(1.0, 0.96, 0.88) * m * 3.0 + vec3(0.25, 0.3, 0.5) * pow(max(dot(EYEDIR, md), 0.0), 120.0) * 0.6;
	if (y < 0.0) { c = vec3(0.01, 0.01, 0.02); }
	COLOR = c;
}"""
		var smat := ShaderMaterial.new()
		smat.shader = sh
		sky.sky_material = smat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8 if indoor else 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if indoor else Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#3a3552") if indoor else Color("#141a33")
	env.adjustment_enabled = true                  # um pouco menos saturado e mais contraste = tom mais realista
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.07 if indoor else 1.18
	env.fog_density = 0.0028
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.6 if indoor else 1.1
	env.glow_strength = 0.9
	env.glow_bloom = 0.03 if indoor else 0.08
	env.glow_hdr_threshold = 1.3 if indoor else 0.9
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
	moon.light_color = Color("#8ea6ff")          # PROTOTIPO: luar frio
	moon.light_energy = 0.6
	moon.rotation_degrees = Vector3(-26, 32, 0)
	moon.shadow_enabled = q >= 2
	if indoor:                                     # luz difusa vinda do teto (paineis de LED)
		moon.light_color = Color("#e6ecff")
		moon.light_energy = 0.55
		moon.rotation_degrees = Vector3(-72, 20, 0)
		moon.shadow_enabled = q >= 1
	moon.directional_shadow_max_distance = 90.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 2 cortes em vez de 4: metade das chamadas de sombra
	parent.add_child(moon)
