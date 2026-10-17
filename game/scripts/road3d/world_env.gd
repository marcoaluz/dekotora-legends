class_name WorldEnv
extends RefCounted
## Ambiente do mundo 3D: ceu por shader, neblina, brilho (glow) e luz principal (sol ou lua), tudo vindo
## de um preset TimeOfDay (data/time/). O galpao da garagem (`indoor`) tem ambiente proprio.
## Ceu: gradiente + brilho no horizonte (cidade a noite, por do sol a tarde) + disco do sol/lua na direcao
## da luz principal + estrelas + duas camadas de nuvens que andam devagar. Estrelas e nuvens ficam fora do
## mapa de reflexo (AT_CUBEMAP_PASS) e o mapa e pequeno: o ceu animado nao pesa no celular.

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 ground_color : source_color;
uniform vec3 glow_color : source_color;
uniform float glow_falloff = 14.0;
uniform vec3 disk_color : source_color;
uniform float disk_energy = 3.0;
uniform float disk_cos = 0.9997;
uniform float halo = 0.4;
uniform float stars = 0.0;
uniform float clouds = 0.0;
uniform vec3 cloud_color : source_color;
uniform float fuji = 0.0;                       // silhueta do Monte Fuji no horizonte (cenario montanha)
uniform float fuji_az = 2.8;
uniform vec3 fuji_color : source_color;
uniform float snow = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vn(p); p *= 2.03; a *= 0.5; }
	return s;
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(0.0, 0.55, y));
	c += glow_color * exp(-max(y, 0.0) * glow_falloff) * 0.6;
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		c += disk_color * smoothstep(disk_cos - 0.0004, disk_cos, d) * disk_energy;
		c += disk_color * pow(max(d, 0.0), 90.0) * halo;
	}
	if (!AT_CUBEMAP_PASS) {
		if (stars > 0.0) {
			vec2 uv = vec2(atan(EYEDIR.x, EYEDIR.z), asin(clamp(y, -1.0, 1.0))) * 140.0;
			vec2 cell = floor(uv);
			float st = step(0.985, h(cell)) * smoothstep(0.08, 0.4, y) * (0.5 + 0.5 * h(cell + 7.0));
			c += vec3(st) * 2.5 * stars;
		}
		if (clouds > 0.0 && y > 0.0) {
			vec2 p = EYEDIR.xz / (y + 0.08);
			float c1 = smoothstep(0.52, 0.8, fbm(p * 0.9 + vec2(TIME * 0.004, 0.0)));
			float c2 = smoothstep(0.58, 0.85, fbm(p * 2.6 + vec2(17.0 + TIME * 0.011, 3.0)));
			float cl = max(c1, c2 * 0.7) * clouds * smoothstep(0.0, 0.12, y);
			c = mix(c, cloud_color * (0.75 + 0.25 * c1), cl);
		}
	}
	if (fuji > 0.0 && y > -0.01) {
		float az = atan(EYEDIR.x, EYEDIR.z);
		float da = abs(mod(az - fuji_az + 3.14159, 6.28318) - 3.14159);
		float prof = min(0.13 * pow(max(1.0 - da / 0.42, 0.0), 1.9), 0.118);
		if (y < prof) {
			float cap = step(prof * 0.66 + 0.006 * sin(az * 90.0), y);
			vec3 mc = mix(fuji_color, horizon_color, 0.35);
			c = mix(mc, vec3(0.92, 0.94, 1.0) * mix(0.35, 1.0, snow), cap);
		}
	}
	if (y < 0.0) {
		c = mix(horizon_color * 0.5, ground_color, smoothstep(0.0, -0.08, y));
	}
	COLOR = c;
}
"""


## `indoor` = galpao da garagem: fundo escuro, sem neblina, luz de teto. Fora dele, usa o preset `tod`
## (sem preset = noite). `fuji` = silhueta do Monte Fuji no horizonte.
static func create(parent: Node3D, indoor: bool = false, tod: TimeOfDay = null, fuji: bool = false) -> void:
	if indoor:
		_create_indoor(parent)
		return
	if tod == null:
		tod = TimeOfDay.by_id(&"night")
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	var smat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	smat.shader = sh
	smat.set_shader_parameter("top_color", tod.sky_top)
	smat.set_shader_parameter("horizon_color", tod.sky_horizon)
	smat.set_shader_parameter("ground_color", tod.sky_ground)
	smat.set_shader_parameter("glow_color", tod.horizon_glow)
	smat.set_shader_parameter("glow_falloff", tod.glow_falloff)
	smat.set_shader_parameter("disk_color", tod.disk_color)
	smat.set_shader_parameter("disk_energy", tod.disk_energy)
	smat.set_shader_parameter("disk_cos", cos(deg_to_rad(tod.disk_size_deg * 0.5)))
	smat.set_shader_parameter("halo", tod.halo)
	smat.set_shader_parameter("stars", tod.stars)
	smat.set_shader_parameter("clouds", tod.clouds if q >= 1 else tod.clouds * 0.6)
	smat.set_shader_parameter("cloud_color", tod.cloud_color)
	smat.set_shader_parameter("fuji", 1.0 if fuji else 0.0)
	smat.set_shader_parameter("fuji_color", Color("#1c2340").lerp(Color("#4a5a7a"), tod.day_amount))   # azul de distancia
	smat.set_shader_parameter("snow", 0.4 + 0.6 * tod.day_amount)
	var sky := Sky.new()
	sky.sky_material = smat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = tod.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = tod.exposure
	env.fog_enabled = true
	env.fog_light_color = tod.fog_color
	env.fog_density = tod.fog_density
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = tod.saturation
	env.adjustment_contrast = tod.contrast
	env.glow_enabled = q >= 1
	env.glow_intensity = tod.glow_intensity
	env.glow_strength = 0.9
	env.glow_bloom = tod.glow_bloom
	env.glow_hdr_threshold = tod.glow_threshold
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = tod.light_color
	sun.light_energy = tod.light_energy
	sun.rotation_degrees = tod.light_rotation
	sun.shadow_enabled = q >= 2                  # sombra so no modo alto (no medio custava +50% de chamadas de dia)
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 2 cortes em vez de 4: metade das chamadas de sombra
	parent.add_child(sun)


static func _create_indoor(parent: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()          # so para reflexos no cromo
	sky_mat.sky_top_color = Color("#101a3a")
	sky_mat.sky_horizon_color = Color("#b8706a")
	sky_mat.ground_horizon_color = Color("#8a6a78")
	sky_mat.ground_bottom_color = Color("#1c1c2c")
	sky_mat.sky_curve = 0.18
	sky_mat.sky_energy_multiplier = 1.3
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#07080d")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.07
	var q: int = int(Engine.get_main_loop().root.get_node("Settings").quality)
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var top := DirectionalLight3D.new()                 # luz difusa vinda do teto (paineis de LED)
	top.light_color = Color("#e6ecff")
	top.light_energy = 0.55
	top.rotation_degrees = Vector3(-72, 20, 0)
	top.shadow_enabled = q >= 1
	top.directional_shadow_max_distance = 90.0
	top.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(top)
