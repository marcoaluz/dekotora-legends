class_name ScenicShaders
extends RefCounted
## T-188: shaders of the new scenery (terrain, mid mountain ridges, slope forest cards). One material per kind of
## surface, cached per time of day; colours come from the terrain detail texture (blender/scripts/build_t188_textures.py)
## times uniforms, so the same 512 px texture serves grass, dirt, rock, sand, forest and city ground.

const DETAIL := "res://assets/textures/scenic/terrain_detail.png"
const CARDS := "res://assets/textures/scenic/tree_cards.png"

const NOISE := """
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Ground: 3 grass tones mixed by large noise, dirt on patches and steep ground, rock on cliffs, canopy where the
## builder painted forest (COLOR.g), sand (COLOR.r) on the beach, street asphalt (COLOR.b) in the city.
const TERRAIN := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.15, 0.19, 0.09);
uniform vec3 grass_b : source_color = vec3(0.25, 0.23, 0.13);
uniform vec3 grass_c : source_color = vec3(0.075, 0.13, 0.05);
uniform vec3 dirt : source_color = vec3(0.22, 0.17, 0.12);
uniform vec3 rock : source_color = vec3(0.27, 0.26, 0.25);
uniform vec3 sand : source_color = vec3(0.46, 0.4, 0.3);
uniform vec3 forest : source_color = vec3(0.05, 0.1, 0.05);
uniform vec3 urban : source_color = vec3(0.14, 0.14, 0.15);
uniform float tint = 1.0;
uniform float night_lift = 0.0;   // moonlit fill (the sky ambient is too dark at night)
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec4 d1 = texture(detail, wpos.xz * 0.21);
	vec4 d2 = texture(detail, wpos.xz * 0.027 + vec2(0.37, 0.11));
	vec4 d3 = texture(detail, wpos.xz * 0.011 + vec2(0.6, 0.2));
	float macro = vnoise(wpos.xz * 0.011) * 0.6 + vnoise(wpos.xz * 0.043 + 3.1) * 0.4;
	vec3 g = mix(grass_c, grass_a, smoothstep(0.28, 0.55, macro));
	g = mix(g, grass_b, smoothstep(0.62, 0.86, macro));
	g *= mix(0.5, 1.25, d1.r) * mix(0.72, 1.18, d2.r);
	float slope = 1.0 - wnrm.y;
	float dw = clamp(smoothstep(0.74, 0.88, vnoise(wpos.xz * 0.045 + 7.0) + (d2.g - 0.5) * 0.35) * 0.55 + smoothstep(0.2, 0.38, slope), 0.0, 1.0);
	vec3 c = mix(g, dirt * mix(0.68, 1.15, d1.g), dw);
	float fw = smoothstep(0.35, 0.65, COLOR.g + (d3.a - 0.55) * 0.7);
	c = mix(c, forest * mix(0.35, 1.3, d3.a) * mix(0.85, 1.1, d1.a), fw);
	float rw = smoothstep(0.45, 0.62, slope + (d2.b - 0.5) * 0.25);
	c = mix(c, rock * mix(0.55, 1.1, d1.b) * mix(0.8, 1.1, d2.b), rw);
	c = mix(c, sand * mix(0.82, 1.08, d1.g), COLOR.r);
	c = mix(c, urban * mix(0.8, 1.12, d1.g), COLOR.b);
	ALBEDO = c * tint;
	EMISSION = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.45) * night_lift * vec3(0.55, 0.68, 1.0);
	ROUGHNESS = mix(0.95, 0.8, COLOR.b);
	SPECULAR = 0.25;
}
""" % NOISE

## Mid-distance mountains: forest low, rock high, snow on the tops (COLOR: g forest, b rock, r snow), plus
## strata noise so the slopes never look flat. The engine fog adds the aerial perspective.
const RIDGE := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 forest : source_color = vec3(0.06, 0.11, 0.065);
uniform vec3 rock : source_color = vec3(0.26, 0.26, 0.28);
uniform vec3 snow : source_color = vec3(0.9, 0.93, 1.0);
uniform float tint = 1.0;
uniform float night_lift = 0.0;   // moonlit fill (the sky ambient is too dark at night)
uniform float snow_glow = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec4 d = texture(detail, wpos.xz * 0.004 + vec2(0.3, 0.7));
	float n = vnoise(wpos.xz * 0.02) * 0.6 + vnoise(wpos.xz * 0.07) * 0.4;
	float strata = 0.85 + 0.15 * sin(wpos.y * 0.35 + n * 6.0);
	vec3 c = forest * mix(0.45, 1.25, d.a);
	float slope = 1.0 - wnrm.y;
	float rw = clamp(COLOR.b + smoothstep(0.45, 0.65, slope) + (n - 0.5) * 0.5, 0.0, 1.0);
	c = mix(c, rock * strata * mix(0.6, 1.1, d.b), rw);
	float sw = smoothstep(0.4, 0.6, COLOR.r + (n - 0.5) * 0.4) * smoothstep(0.75, 0.4, slope);
	c = mix(c, snow, sw);
	ALBEDO = c * tint;
	EMISSION = snow * sw * snow_glow + mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.45) * night_lift * vec3(0.55, 0.68, 1.0);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
""" % NOISE

## Forest cards (two crossed quads, conifer or broadleaf half of tree_cards.png by INSTANCE_CUSTOM.x), cut by alpha.
const CARD := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D cards : source_color, filter_linear_mipmap, repeat_disable;
uniform float tint = 1.0;
uniform float night_lift = 0.0;   // moonlit fill (the sky ambient is too dark at night)
varying float half_sel;
varying float shade;
void vertex() {
	half_sel = INSTANCE_CUSTOM.x;
	shade = INSTANCE_CUSTOM.y;
	UV = vec2(UV.x * 0.5 + half_sel * 0.5, UV.y);
}
void fragment() {
	vec4 c = texture(cards, UV);
	ALBEDO = c.rgb * tint * shade;
	EMISSION = c.rgb * shade * night_lift * vec3(0.55, 0.68, 1.0);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.5);
}
"""

static var _cache: Dictionary = {}


static func terrain(tod: TimeOfDay) -> ShaderMaterial:
	return _mat("terrain", TERRAIN, tod)


static func ridge(tod: TimeOfDay, kind: StringName) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("ridge@" + String(kind), RIDGE, tod)
	var day: float = tod.day_amount if tod != null else 0.0
	m.set_shader_parameter("snow_glow", 0.25 * (1.0 - day))
	if kind == &"coast":
		m.set_shader_parameter("forest", Color(0.07, 0.13, 0.06))
	return m


static func cards(tod: TimeOfDay) -> ShaderMaterial:
	var m: ShaderMaterial = _mat("cards", CARD, tod)
	m.set_shader_parameter("cards", load(CARDS) as Texture2D)
	return m


static func _mat(key: String, code: String, tod: TimeOfDay) -> ShaderMaterial:
	var day: float = tod.day_amount if tod != null else 0.0
	var k: String = "%s@%.2f" % [key, day]
	if _cache.has(k):
		return _cache[k]
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	if ResourceLoader.exists(DETAIL):
		m.set_shader_parameter("detail", load(DETAIL) as Texture2D)
	m.set_shader_parameter("tint", lerpf(0.9, 1.0, day))
	m.set_shader_parameter("night_lift", 2.2 * (1.0 - day))
	_cache[k] = m
	return m
